part of '../voice_assistant_controller.dart';

/// Batches Gemini function-call responses and flushes them.
extension VoiceAssistantFunctionBatching on VoiceAssistantController {
  void _respondToFunction(String callId, String name, Map<String, dynamic> result, {Map<String, dynamic>? params}) {
    _pendingResponses.add({'id': callId, 'name': name, 'result': result, 'params': params ?? {}});
  }

  Future<dynamic> _findSubjectByName(String name, {bool retry = false}) async {
    final lower = name.toLowerCase().trim();

    if (_subjectCreationCompleters.containsKey(lower)) {
      debugPrint('[Gemini] 🔗 Awaiting in-flight subject creation for "$name"');
      return await _subjectCreationCompleters[lower]!.future;
    }

    return _querySubjectByName(lower, retry: retry);
  }

  Future<dynamic> _querySubjectByName(String lower, {bool retry = false}) async {
    final subjects = await _subjectRepo.getAll();
    for (final s in subjects) {
      if (s.name.toLowerCase() == lower) return s;
    }
    for (final s in subjects) {
      if (s.name.toLowerCase().contains(lower) || lower.contains(s.name.toLowerCase())) return s;
    }
    if (retry) {
      for (int i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 1500));
        final retrySubjects = await _subjectRepo.getAll();
        for (final s in retrySubjects) {
          if (s.name.toLowerCase() == lower) return s;
        }
        for (final s in retrySubjects) {
          if (s.name.toLowerCase().contains(lower) || lower.contains(s.name.toLowerCase())) return s;
        }
      }
    }
    return null;
  }

  Future<dynamic> _findOrCreateSubjectByName(String rawName, {String? color}) async {
    final name = _sanitizeName(rawName);
    final lower = name.toLowerCase();

    if (_subjectCreationCompleters.containsKey(lower)) {
      debugPrint('[Gemini] 🔗 Awaiting in-flight subject creation for "$name"');
      final existing = await _subjectCreationCompleters[lower]!.future;
      if (existing != null) return existing;
    }

    final found = await _querySubjectByName(lower);
    if (found != null) return found;

    if (_subjectCreationCompleters.containsKey(lower)) {
      final existing = await _subjectCreationCompleters[lower]!.future;
      if (existing != null) return existing;
      return await _querySubjectByName(lower);
    }

    final completer = Completer<dynamic>();
    _subjectCreationCompleters[lower] = completer;
    try {
      final subject = await _subjectRepo.create(name: name, imageUrl: null, colorHex: color ?? '#87CEEB');
      _subjectRepo.refresh();
      _summaryCache = null;
      completer.complete(subject);
      debugPrint('[Gemini] 🆕 Auto-created missing subject "$name" (model skipped addSubject)');

      ImageSearchService.searchSubjectImage(name).then((imageUrl) async {
        if (imageUrl != null) {
          try {
            await _subjectRepo.update(subject.id, {'image_url': imageUrl});
            _subjectRepo.refresh();
          } catch (e) {
            debugPrint('[Gemini] ⚠️ Failed to attach image for "$name": $e');
          }
        }
      }).catchError((e) {
        debugPrint('[Gemini] ⚠️ Image search failed for "$name": $e');
      });

      return subject;
    } catch (e) {
      completer.complete(null);
      rethrow;
    } finally {
      _subjectCreationCompleters.remove(lower);
    }
  }

  Future<void> _handleFunctionCall(String callId, String name, Map<String, dynamic> args) async {
    final gen = _generation;

    _enterLoading('function-call:$name');

    if (_pendingCallIds.length >= VoiceAssistantController._maxPendingCalls) {
      debugPrint('[Gemini] 🚫 Batch too large (${_pendingCallIds.length} pending) — refusing call $name');
      _respondToFunction(callId, name, {
        'success': false,
        'error': 'Batch size limit reached ($VoiceAssistantController._maxPendingCalls). Split this into smaller requests.',
      }, params: args);
      return;
    }

    if (_processedCallIds.contains(callId)) {
      debugPrint('[Gemini] ⏭️ Duplicate call ID — answering anyway so Gemini does not hang: $name id=$callId');
      // MUST respond — skipping without a tool result leaves the model on Thinking forever.
      _respondToFunction(callId, name, {
        'success': true,
        'skipped': true,
        'note': 'Duplicate call id ignored. Treat this operation as already completed. Continue — do not retry the same call.',
      }, params: args);
      return;
    }

    final sortedArgs = SplayTreeMap<String, dynamic>.from(args);
    final argsHash = '$name:${jsonEncode(sortedArgs)}';
    if (_recentCalls.contains(argsHash)) {
      debugPrint('[Gemini] ⏭️ Duplicate args — answering with already-done result: $name hash=$argsHash');
      _respondToFunction(callId, name, {
        'success': true,
        'skipped': true,
        'note': 'Identical call already succeeded. Do not repeat it. Continue with the next step (e.g. if user asked to create a new routine after delete, call getAllData fresh then registerDailyRoutine).',
      }, params: args);
      return;
    }
    _processedCallIds.add(callId);

    if (_processedCallIds.length > 50) {
      _processedCallIds.remove(_processedCallIds.first);
    }
    if (_recentCalls.length > 50) {
      _recentCalls.remove(_recentCalls.first);
    }

    _pendingCallIds.add(callId);

    if (name == 'addSubject') {
      final subjectName = (args['name'] as String?)?.trim().toLowerCase() ?? '';
      if (subjectName.isNotEmpty && !_subjectCreationCompleters.containsKey(subjectName)) {
        _subjectCreationCompleters[subjectName] = Completer<dynamic>();
      }
    }

    debugPrint('[Gemini] Handling function call: $name id=$callId (${_pendingCallIds.length} pending)');
    isProcessing.value = true;

    if (!_mutedByFunctionCall) {
      _mutedByFunctionCall = !_service.isMuted;
    }
    _setMicMuted(true, reason: 'function call in flight');

    if (_pendingCallIds.length == 1) {
      _clearThinking();
      _batchInProgress = true;
      _batchTotal = 1;
      _batchCompleted = 0;
      _batchProgressMessage = ChatMessage(role: ChatRole.system, text: _batchProgressText());
      messages.add(_batchProgressMessage!);
    } else {
      _batchTotal++;
    }
    _updateBatchProgress();

    try {
      // Register new tools in tool_dispatch.dart (see header there).
      await _dispatchVoiceTool(callId, name, args);
    } catch (e) {
      debugPrint('[Gemini] Function call error: $e');
      Get.snackbar('Tool Failed', '$name: $e', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4));
      _respondToFunction(callId, name, {'success': false, 'error': e.toString()}, params: args);
    } finally {
      if (gen != _generation) return;

      _pendingCallIds.remove(callId);

      final respIdx = _pendingResponses.indexWhere((r) => r['id'] == callId);
      if (respIdx != -1 && _pendingResponses[respIdx]['result']['success'] == true) {
        _recentCalls.add(argsHash);
        debugPrint('[Gemini] ✅ Cached SUCCESS for dedup: $name hash=$argsHash');
      } else {
        debugPrint('[Gemini] ⚠️ NOT caching FAILED call — retry allowed: $name hash=$argsHash');
      }

      _batchCompleted++;
      _updateBatchProgress();
      debugPrint('[Gemini] Done: $name (${_pendingCallIds.length} pending, $_batchCompleted/$_batchTotal done)');

      if (_pendingCallIds.isEmpty) {
        _flushBatch(gen);
      } else {
        _pendingCallsSafetyTimer?.cancel();
        _pendingCallsSafetyTimer = Timer(const Duration(seconds: 30), () {
          if (gen != _generation) return;
          debugPrint('[Gemini] ⏰ Safety timeout: ${_pendingCallIds.length} calls stuck — forcing flush');
          _pendingCallIds.clear();
          _flushBatch(gen, forcedByTimeout: true);
        });
      }
    }
  }

  void _flushBatch(int gen, {bool forcedByTimeout = false}) {
    if (gen != _generation) return;
    _pendingCallsSafetyTimer?.cancel();
    final okCount = _pendingResponses
        .where((r) => (r['result'] as Map<String, dynamic>?)?['success'] == true)
        .length;
    final failCount = _pendingResponses.length - okCount;
    debugPrint('[Gemini] 📦 Flushing batch — ${_pendingResponses.length} responses ($okCount ok, $failCount fail)'
        '${forcedByTimeout ? " [forced by timeout]" : ""}');

    final retryCountForService = _batchRetryCount;
    _batchRetryCount++;

    _batchInProgress = false;
    _batchJustCompleted = true;
    _batchCompletedCount = _batchCompleted;

    _subjectCreationCompleters.clear();

    final wireResponses = _pendingResponses
        .map((r) => {'id': r['id'], 'name': r['name'], 'result': r['result']})
        .toList();

    try {
      _service.sendBatchedFunctionResponses(wireResponses, retryCount: retryCountForService);
    } catch (e) {
      debugPrint('[Gemini] ⚠️ Failed to send batched responses: $e');
    }
    _pendingResponses.clear();

    if (forcedByTimeout) {
      _unmuteAfterFunctionCall();
      _finishBatchUi();
      return;
    }

    _batchTotal = 0;
    _batchCompleted = 0;
    _batchFlushTimer?.cancel();
    // Safety: if Gemini doesn't respond within 8s, force unmute and finish
    _batchFlushTimer = Timer(const Duration(seconds: 8), () {
      if (gen != _generation) return;
      if (_batchJustCompleted) {
        debugPrint('[Gemini] ⚠️ Batch safety timeout — forcing unmute');
        _finishBatchUi();
        _unmuteAfterFunctionCall();
      }
    });
  }

  void _finishBatchUi() {
    _batchJustCompleted = false;
    if (_batchProgressMessage != null) {
      messages.remove(_batchProgressMessage);
      _batchProgressMessage = null;
    }
    _clearThinking();
    isProcessing.value = false;
    _exitLoading('batch-ui-finish');
    _triggerUiUpdate();
  }

  String _batchProgressText() {
    final retryInfo = _batchRetryCount > 0 ? ' (retry #$_batchRetryCount)' : '';
    if (_batchCompleted < _batchTotal) {
      return '⚙️ Executing tasks$retryInfo... (Running task ${_batchCompleted + 1}/$_batchTotal)';
    }
    return '✅ $_batchTotal/$_batchTotal$retryInfo — finishing up...';
  }

  void _updateBatchProgress() {
    if (_batchProgressMessage != null) {
      _batchProgressMessage!.text = _batchProgressText();
      _triggerUiUpdate();
    }
  }

  Future<dynamic> _findTopicByName(String subjectId, String topicName) async {
    final topics = await _topicRepo.getBySubject(subjectId);
    final lower = topicName.toLowerCase().trim();
    for (final t in topics) {
      if (t.name.toLowerCase() == lower) return t;
    }
    for (final t in topics) {
      if (t.name.toLowerCase().contains(lower) || lower.contains(t.name.toLowerCase())) return t;
    }
    return null;
  }
}

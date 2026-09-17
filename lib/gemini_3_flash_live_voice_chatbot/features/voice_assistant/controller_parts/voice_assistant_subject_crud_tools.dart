part of '../voice_assistant_controller.dart';

extension VoiceAssistantSubjectCrudTools on VoiceAssistantController {
  Future<void> _addSubjectsBulk(String callId, Map<String, dynamic> args) async {
    final rawList = args['subjects'];
    final items = (rawList is List ? rawList : const [])
        .whereType<Map>()
        .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
        .toList();

    if (items.isEmpty) {
      _respondToFunction(callId, 'addSubjectsBulk', {
        'success': false,
        'error': 'subjects array is required and cannot be empty',
      }, params: args);
      return;
    }

    _batchTotal = items.length;
    _batchCompleted = 0;
    _updateBatchProgress();

    // Load existing subjects ONCE — avoid N sequential getAll() calls.
    Map<String, dynamic> existingByName = {};
    try {
      final all = await _subjectRepo.getAll();
      for (final s in all) {
        existingByName[s.name.toLowerCase()] = s;
      }
    } catch (e) {
      debugPrint('[Gemini] ⚠️ preload subjects failed: $e');
    }

    final results = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i += VoiceAssistantController._bulkChunkSize) {
      final chunk = items.skip(i).take(VoiceAssistantController._bulkChunkSize).toList();

      for (var j = 0; j < chunk.length; j += VoiceAssistantController._bulkConcurrency) {
        final slice = chunk.skip(j).take(VoiceAssistantController._bulkConcurrency);
        final sliceResults = await Future.wait(
          slice.map((item) => _processOneBulkSubject(item, existingByName)),
        );
        results.addAll(sliceResults);
        _batchCompleted = results.length;
        _updateBatchProgress();
      }
    }

    _subjectCreationCompleters.clear();
    try {
      _subjectRepo.refresh();
      _topicRepo.refresh();
    } catch (_) {}

    final succeeded = results.where((r) => r['success'] == true).toList();
    final failed = results.where((r) => r['success'] != true).toList();

    final reportedFailures = failed.length > VoiceAssistantController._maxReportedFailures
        ? [
      ...failed.take(VoiceAssistantController._maxReportedFailures),
      {
        'note': '+${failed.length - VoiceAssistantController._maxReportedFailures} more failures — ask the user if they want full details',
      },
    ]
        : failed;

    debugPrint('[Gemini] 📦 addSubjectsBulk done — ${succeeded.length}/${items.length} succeeded');

    _respondToFunction(callId, 'addSubjectsBulk', {
      'success': failed.isEmpty,
      'total': items.length,
      'succeeded': succeeded.length,
      'failed_items': reportedFailures,
    }, params: args);
  }

  Future<Map<String, dynamic>> _processOneBulkSubject(
    Map<String, dynamic> item,
    Map<String, dynamic> existingByName,
  ) async {
    final name = _sanitizeName((item['name'] as String?)?.trim() ?? '');
    if (name.isEmpty) {
      return {'name': '(unnamed)', 'success': false, 'error': 'Subject name cannot be empty'};
    }
    final rawTopics = item['topics'];
    final topicNames = (rawTopics is List ? rawTopics : const [])
        .map((e) => _sanitizeName(e.toString()))
        .where((s) => s.isNotEmpty)
        .toList();
    final color = item['color'] as String?;
    final lower = name.toLowerCase();

    if (_subjectCreationCompleters.containsKey(lower)) {
      debugPrint('[Gemini] 🔗 Awaiting in-flight subject creation for "$name"');
      final existing = await _subjectCreationCompleters[lower]!.future;
      if (existing == null) {
        return {'name': name, 'success': false, 'error': 'Concurrent creation of this subject failed'};
      }
      return _addTopicsToSubject(existing, name, topicNames);
    }

    // Reuse preloaded map first — no extra network call.
    final cached = existingByName[lower];
    if (cached != null) {
      return _addTopicsToSubject(cached, name, topicNames);
    }

    final completer = Completer<dynamic>();
    _subjectCreationCompleters[lower] = completer;
    try {
      final subject = await _subjectRepo.create(
        name: name,
        imageUrl: null,
        colorHex: color ?? '#87CEEB',
      );
      existingByName[lower] = subject;
      _summaryCache = null;
      completer.complete(subject);

      // Fire-and-forget image attach so bulk add stays fast.
      unawaited(ImageSearchService.searchSubjectImage(name).then((imageUrl) async {
        if (imageUrl != null) {
          try {
            await _subjectRepo.update(subject.id, {'image_url': imageUrl});
          } catch (e) {
            debugPrint('[Gemini] ⚠️ Failed to attach image for "$name": $e');
          }
        }
      }).catchError((e) {
        debugPrint('[Gemini] ⚠️ Image search failed for "$name": $e');
      }));

      final topicResult = await _addTopicsToSubject(subject, name, topicNames);
      // One refresh after the slice, not after every subject.
      return topicResult;
    } catch (e) {
      if (!completer.isCompleted) completer.complete(null);
      return {'name': name, 'success': false, 'error': e.toString()};
    } finally {
      _subjectCreationCompleters.remove(lower);
    }
  }

  Future<Map<String, dynamic>> _addTopicsToSubject(
      dynamic subject, String name, List<String> topicNames) async {
    if (topicNames.isEmpty) {
      return {'name': name, 'success': true, 'topics_added': 0};
    }
    try {
      final existingTopics = await _topicRepo.getBySubject(subject.id);
      final existingLower = existingTopics.map((t) => t.name.toLowerCase()).toSet();

      int added = 0;
      int skippedDuplicates = 0;
      final failedTopics = <String>[];
      for (final trimmed in topicNames) {
        if (existingLower.contains(trimmed.toLowerCase())) {
          skippedDuplicates++;
          continue;
        }
        try {
          // Only create the topic. Revision schedules start after first-read
          // completion — not here. This also keeps bulk add fast.
          await _topicRepo.create(subjectId: subject.id, name: trimmed);
          existingLower.add(trimmed.toLowerCase());
          added++;
        } catch (e) {
          debugPrint('[Gemini] ⚠️ Failed to add topic "$trimmed" under "$name": $e');
          failedTopics.add(trimmed);
        }
      }
      _topicRepo.refresh();
      _summaryCache = null;

      return {
        'name': name,
        'success': true,
        'topics_added': added,
        if (skippedDuplicates > 0) 'topics_skipped_existing': skippedDuplicates,
        if (failedTopics.isNotEmpty) 'topics_failed': failedTopics,
      };
    } catch (e) {
      return {'name': name, 'success': false, 'error': 'Subject ok but topics failed: $e'};
    }
  }

  Future<void> _addSubject(String callId, Map<String, dynamic> args) async {
    final name = _sanitizeName((args['name'] as String?)?.trim() ?? '');
    if (name.isEmpty) {
      _respondToFunction(callId, 'addSubject', {'success': false, 'error': 'Subject name cannot be empty'}, params: args);
      return;
    }
    final lower = name.toLowerCase();
    final color = args['color'] as String?;
    final completer = _subjectCreationCompleters[lower];

    try {
      final subject = await _subjectRepo.create(name: name, imageUrl: null, colorHex: color ?? '#87CEEB');
      _subjectRepo.refresh();
      _summaryCache = null;
      completer?.complete(subject);

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

      _respondToFunction(callId, 'addSubject', {
        'success': true,
        'message': 'Subject "$name" added successfully',
      }, params: args);
    } catch (e) {
      if (completer != null && !completer.isCompleted) completer.complete(null);
      _respondToFunction(callId, 'addSubject', {'success': false, 'error': e.toString()}, params: args);
    } finally {
      _subjectCreationCompleters.remove(lower);
    }
  }

  Future<void> _addTopic(String callId, Map<String, dynamic> args) async {
    final name = _sanitizeName((args['name'] as String?)?.trim() ?? '');
    if (name.isEmpty) {
      _respondToFunction(callId, 'addTopic', {'success': false, 'error': 'Topic name cannot be empty'}, params: args);
      return;
    }
    var subjectName = args['subjectName'] as String?;

    if ((subjectName == null || subjectName.trim().isEmpty) && currentSubjectName != null) {
      subjectName = currentSubjectName;
      debugPrint('[Gemini] Using context subject: $subjectName');
    }

    if (subjectName == null || subjectName.trim().isEmpty) {
      _respondToFunction(callId, 'addTopic', {
        'success': false,
        'error': 'No subject specified. Please tell me which subject to add the topic to.',
      }, params: args);
      return;
    }

    try {
      var subject = await _findSubjectByName(subjectName, retry: true);
      subject ??= await _findOrCreateSubjectByName(subjectName);

      await _topicRepo.create(subjectId: subject.id, name: name);
      // Schedules are created only after first-read completion.
      _subjectRepo.refresh();
      _topicRepo.refresh();
      _summaryCache = null;

      _respondToFunction(callId, 'addTopic', {
        'success': true,
        'message': 'Topic "$name" added to "${subject.name}" in first read. Revision dates are set only after you mark the first read complete.',
      }, params: args);
    } catch (e) {
      Get.snackbar('addTopic Failed', '$e', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4));
      _respondToFunction(callId, 'addTopic', {'success': false, 'error': e.toString()}, params: args);
    }
  }

  Future<void> _addMultipleTopics(String callId, Map<String, dynamic> args) async {
    final subjectName = args['subjectName'] as String?;
    if (subjectName == null || subjectName.trim().isEmpty) {
      _respondToFunction(callId, 'addMultipleTopics', {'success': false, 'error': 'Subject name is required'}, params: args);
      return;
    }
    final rawTopics = args['topics'];
    if (rawTopics is! List || rawTopics.isEmpty) {
      _respondToFunction(callId, 'addMultipleTopics', {'success': false, 'error': 'At least one topic name is required'}, params: args);
      return;
    }
    final topicNames = rawTopics
        .map((e) => _sanitizeName(e.toString()))
        .where((s) => s.isNotEmpty)
        .toList();

    try {
      var subject = await _findSubjectByName(subjectName, retry: true);
      subject ??= await _findOrCreateSubjectByName(subjectName);

      final existingTopics = await _topicRepo.getBySubject(subject.id);
      final existingLower = existingTopics.map((t) => t.name.toLowerCase()).toSet();

      int added = 0;
      int skippedDuplicates = 0;
      final failedTopics = <String>[];
      for (final trimmed in topicNames) {
        if (existingLower.contains(trimmed.toLowerCase())) {
          skippedDuplicates++;
          continue;
        }
        try {
          await _topicRepo.create(subjectId: subject.id, name: trimmed);
          // Schedules are created only after first-read completion.
          existingLower.add(trimmed.toLowerCase());
          added++;
        } catch (e) {
          debugPrint('[Gemini] ⚠️ Failed to add topic "$trimmed": $e');
          failedTopics.add(trimmed);
        }
      }
      _subjectRepo.refresh();
      _topicRepo.refresh();
      _summaryCache = null;

      if (added == 0 && skippedDuplicates == 0) {
        _respondToFunction(callId, 'addMultipleTopics', {
          'success': false,
          'error': 'Failed to add any topics to "${subject.name}"',
        }, params: args);
      } else {
        final dupNote = skippedDuplicates > 0 ? ' ($skippedDuplicates already existed, skipped)' : '';
        final failNote = failedTopics.isNotEmpty ? ' (failed: ${failedTopics.join(", ")})' : '';
        _respondToFunction(callId, 'addMultipleTopics', {
          'success': true,
          'message': '$added topics added to "${subject.name}" in first read$dupNote$failNote. Revision dates are set only after markFirstReadCompleted.',
        }, params: args);
      }
    } catch (e) {
      Get.snackbar('addMultipleTopics Failed', '$e', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4));
      _respondToFunction(callId, 'addMultipleTopics', {'success': false, 'error': e.toString()}, params: args);
    }
  }

  Future<void> _deleteAllSubjects(String callId, Map<String, dynamic> args) async {
    try {
      final subjects = await _subjectRepo.getAll();
      int count = 0;
      for (final sub in subjects) {
        try {
          await _subjectRepo.delete(sub.id);
          count++;
        } catch (e) {
          debugPrint('[Gemini] ⚠️ Failed to delete subject "${sub.name}": $e');
        }
      }
      _subjectRepo.refresh();
      _topicRepo.refresh();
      _summaryCache = null;
      _respondToFunction(callId, 'deleteAllSubjects', {
        'success': true,
        'message': '$count subjects deleted',
      }, params: args);
    } catch (e) {
      Get.snackbar('deleteAllSubjects Failed', '$e', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4));
      _respondToFunction(callId, 'deleteAllSubjects', {'success': false, 'error': e.toString()}, params: args);
    }
  }

  Future<void> _deleteSubjectByName(String callId, Map<String, dynamic> args) async {
    final name = args['name'] as String?;
    if (name == null || name.trim().isEmpty) {
      _respondToFunction(callId, 'deleteSubjectByName', {'success': false, 'error': 'Subject name is required'}, params: args);
      return;
    }
    try {
      final subject = await _findSubjectByName(name);
      if (subject == null) {
        _respondToFunction(callId, 'deleteSubjectByName', {'success': false, 'error': 'Subject "$name" not found'}, params: args);
        return;
      }
      await _subjectRepo.delete(subject.id);
      _subjectRepo.refresh();
      _topicRepo.refresh();
      _summaryCache = null;
      _respondToFunction(callId, 'deleteSubjectByName', {
        'success': true,
        'message': 'Subject "${subject.name}" deleted',
      }, params: args);
    } catch (e) {
      Get.snackbar('deleteSubjectByName Failed', '$e', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4));
      _respondToFunction(callId, 'deleteSubjectByName', {'success': false, 'error': e.toString()}, params: args);
    }
  }

  Future<void> _deleteTopicByName(String callId, Map<String, dynamic> args) async {
    var subjectName = args['subjectName'] as String?;
    final topicName = args['topicName'] as String?;
    if ((subjectName == null || subjectName.trim().isEmpty) && currentSubjectName != null) {
      subjectName = currentSubjectName;
    }
    if (subjectName == null || subjectName.trim().isEmpty || topicName == null || topicName.trim().isEmpty) {
      _respondToFunction(callId, 'deleteTopicByName', {
        'success': false,
        'error': 'Both subject name and topic name are required',
      }, params: args);
      return;
    }

    try {
      final subject = await _findSubjectByName(subjectName);
      if (subject == null) {
        _respondToFunction(callId, 'deleteTopicByName', {'success': false, 'error': 'Subject "$subjectName" not found'}, params: args);
        return;
      }

      final topic = await _findTopicByName(subject.id, topicName);
      if (topic == null) {
        _respondToFunction(callId, 'deleteTopicByName', {
          'success': false,
          'error': 'Topic "$topicName" not found in "${subject.name}"',
        }, params: args);
        return;
      }

      await _topicRepo.delete(topic.id, subjectId: subject.id);
      _subjectRepo.refresh();
      _topicRepo.refresh();
      _summaryCache = null;
      _respondToFunction(callId, 'deleteTopicByName', {
        'success': true,
        'message': 'Topic "${topic.name}" deleted from "${subject.name}"',
      }, params: args);
    } catch (e) {
      Get.snackbar('deleteTopicByName Failed', '$e', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4));
      _respondToFunction(callId, 'deleteTopicByName', {'success': false, 'error': e.toString()}, params: args);
    }
  }

}

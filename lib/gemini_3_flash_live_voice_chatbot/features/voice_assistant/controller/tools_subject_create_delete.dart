part of '../voice_assistant_controller.dart';

/// Voice tools that CREATE/DELETE subjects and topics.
extension VoiceAssistantSubjectCrudTools on VoiceAssistantController {
  /// Accepts ["A", "B"] or [{"name":"A","subtopics":["A1"]}, ...].
  List<Map<String, dynamic>> _parseTopicEntries(dynamic raw) {
    final out = <Map<String, dynamic>>[];
    if (raw is! List) return out;
    for (final e in raw) {
      if (e is String) {
        final n = _sanitizeName(e.trim());
        if (n.isNotEmpty) {
          out.add({'name': n, 'subtopics': <String>[]});
        }
      } else if (e is Map) {
        final m = e.map((k, v) => MapEntry(k.toString(), v));
        final n = _sanitizeName(
            ((m['name'] ?? m['topic'])?.toString() ?? '').trim());
        if (n.isEmpty) continue;
        final subs = ((m['subtopics'] ?? m['children']) is List
                ? (m['subtopics'] ?? m['children']) as List
                : const [])
            .map((x) => _sanitizeName(x.toString()))
            .where((s) => s.isNotEmpty)
            .toList();
        out.add({'name': n, 'subtopics': subs});
      }
    }
    return out;
  }

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
          slice.map((item) => _processOneBulkSubject(item, existingByName, args)),
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

    final createdTopics = <String>[];
    final createdSubtopics = <Map<String, dynamic>>[];
    for (final r in succeeded) {
      final tops = (r['topics_created'] as List?)?.whereType<String>() ?? const [];
      createdTopics.addAll(tops);
      final subs = (r['subtopics_created'] as List?)?.whereType<Map>() ?? const [];
      createdSubtopics.addAll(subs.map((e) => e.map((k, v) => MapEntry(k.toString(), v))));
    }

    debugPrint('[Gemini] 📦 addSubjectsBulk done — ${succeeded.length}/${items.length} succeeded');

    final payload = <String, dynamic>{
      'success': failed.isEmpty,
      'total': items.length,
      'succeeded': succeeded.length,
      'failed_items': reportedFailures,
      if (createdTopics.isNotEmpty) 'topics_created': createdTopics,
      if (createdSubtopics.isNotEmpty) 'subtopics_created': createdSubtopics,
    };
    if (createdTopics.isNotEmpty) {
      final subjectForAsk = (succeeded.first['name'] as String?) ?? '';
      final perSubject = <String, List<String>>{};
      for (final r in succeeded) {
        final sName = (r['name'] as String?) ?? '';
        final tops = (r['topics_created'] as List?)?.whereType<String>() ?? const [];
        if (sName.isNotEmpty && tops.isNotEmpty) {
          perSubject.putIfAbsent(sName, () => []).addAll(tops);
        }
      }
      if (perSubject.length == 1 && subjectForAsk.isNotEmpty) {
        payload['required_next_step'] =
            _mustAskSubtopicsMessage(subjectForAsk, createdTopics);
      } else if (perSubject.isNotEmpty) {
        payload['required_next_step'] = 'MANDATORY: For EACH subject below, ask in the user\'s language '
            '"Do you want any subtopics under <topics>?" and WAIT. '
            'Subtopics → addSubtopics(subjectName, topicName, names) ONLY — never subject-level topics. '
            '${perSubject.entries.map((e) => '${e.key}: ${e.value.join(', ')}').join(' | ')}';
      }
      payload['pending_subtopic_question_for'] = createdTopics.join(', ');
    } else if (createdSubtopics.isNotEmpty) {
      payload['required_next_step'] =
          'Subtopics already nested under their topics. Confirm in ONE language, then ask once if they want MORE subtopics under those parents.';
    }

    _respondToFunction(callId, 'addSubjectsBulk', payload, params: args);
  }

  Future<Map<String, dynamic>> _processOneBulkSubject(
    Map<String, dynamic> item,
    Map<String, dynamic> existingByName,
    Map<String, dynamic> bulkArgs,
  ) async {
    final name = _sanitizeName((item['name'] as String?)?.trim() ?? '');
    if (name.isEmpty) {
      return {'name': '(unnamed)', 'success': false, 'error': 'Subject name cannot be empty'};
    }
    final topicEntries = _parseTopicEntries(item['topics']);
    final color = item['color'] as String?;
    final lower = name.toLowerCase();
    final confirmNew = item['confirmNewTopics'] == true ||
        bulkArgs['confirmNewTopics'] == true;

    if (_subjectCreationCompleters.containsKey(lower)) {
      debugPrint('[Gemini] 🔗 Awaiting in-flight subject creation for "$name"');
      final existing = await _subjectCreationCompleters[lower]!.future;
      if (existing == null) {
        return {'name': name, 'success': false, 'error': 'Concurrent creation of this subject failed'};
      }
      return _addTopicsToSubject(
          existing, name, topicEntries, confirmNewTopics: confirmNew);
    }

    // Reuse preloaded map first — no extra network call.
    final cached = existingByName[lower];
    if (cached != null) {
      return _addTopicsToSubject(
          cached, name, topicEntries, confirmNewTopics: confirmNew);
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

      final topicResult = await _addTopicsToSubject(
          subject, name, topicEntries,
          confirmNewTopics: true); // brand-new subject — no pending gate
      return topicResult;
    } catch (e) {
      if (!completer.isCompleted) completer.complete(null);
      return {'name': name, 'success': false, 'error': e.toString()};
    } finally {
      _subjectCreationCompleters.remove(lower);
    }
  }

  Future<Map<String, dynamic>> _addTopicsToSubject(
    dynamic subject,
    String name,
    List<Map<String, dynamic>> topicEntries, {
    bool confirmNewTopics = false,
  }) async {
    if (topicEntries.isEmpty) {
      return {'name': name, 'success': true, 'topics_added': 0};
    }

    final topLevelNames = topicEntries
        .map((e) => (e['name'] as String?) ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    if (!confirmNewTopics) {
      final pending = _pendingAskForSubject(name);
      if (pending != null && pending.isNotEmpty) {
        final pendingLower =
            pending.split(', ').map((n) => n.toLowerCase()).toSet();
        final newLower =
            topLevelNames.map((n) => n.toLowerCase()).toSet();
        final allArePending =
            newLower.isNotEmpty && newLower.every(pendingLower.contains);
        if (!allArePending) {
          return {
            'name': name,
            'success': false,
            'blocked': 'hierarchy_pending_subtopic_question',
            'error':
                'Blocked: must ask about subtopics under "$pending" first, '
                'or pass confirmNewTopics: true. '
                'Subtopics → addSubtopics(subjectName: "$name", topicName, names).',
            'pending_subtopic_question_for': pending,
          };
        }
      }
    }

    try {
      final existingTopics = await _topicRepo.getBySubject(subject.id);
      final existingLower = existingTopics
          .where((t) => t.parentTopicId == null || t.parentTopicId!.isEmpty)
          .map((t) => t.name.toLowerCase())
          .toSet();
      final allByName = <String, dynamic>{};
      for (final t in existingTopics) {
        if (t.parentTopicId == null || t.parentTopicId!.isEmpty) {
          allByName[t.name.toLowerCase()] = t;
        }
      }

      int added = 0;
      int skippedDuplicates = 0;
      final failedTopics = <String>[];
      final createdParents = <String>[];
      final createdSubtopics = <Map<String, dynamic>>[];

      for (final entry in topicEntries) {
        final trimmed = (entry['name'] as String?) ?? '';
        if (trimmed.isEmpty) continue;
        final subs = ((entry['subtopics'] as List?) ?? const [])
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toList();

        dynamic parent;
        if (existingLower.contains(trimmed.toLowerCase())) {
          skippedDuplicates++;
          parent = allByName[trimmed.toLowerCase()];
        } else {
          try {
            parent = await _topicRepo.create(subjectId: subject.id, name: trimmed);
            existingLower.add(trimmed.toLowerCase());
            allByName[trimmed.toLowerCase()] = parent;
            added++;
            createdParents.add(trimmed);
            _noteTopicCreated(name, trimmed);
          } catch (e) {
            debugPrint('[Gemini] ⚠️ Failed to add topic "$trimmed" under "$name": $e');
            failedTopics.add(trimmed);
            continue;
          }
        }

        if (subs.isEmpty || parent == null) continue;
        final parentId = parent.id as String?;
        if (parentId == null || parentId.isEmpty) continue;

        final kids = existingTopics
            .where((t) => t.parentTopicId == parentId)
            .map((t) => t.name.toLowerCase())
            .toSet();
        for (final sub in subs) {
          if (kids.contains(sub.toLowerCase())) continue;
          try {
            await _topicRepo.create(
              subjectId: subject.id,
              name: sub,
              parentTopicId: parentId,
            );
            kids.add(sub.toLowerCase());
            createdSubtopics.add({'parent': trimmed, 'name': sub});
          } catch (e) {
            debugPrint('[Gemini] ⚠️ Failed to add subtopic "$sub" under "$trimmed": $e');
          }
        }
      }
      _topicRepo.refresh();
      _summaryCache = null;

      String? requiredNext;
      if (createdParents.isNotEmpty) {
        requiredNext = _mustAskSubtopicsMessage(name, createdParents);
      } else if (createdSubtopics.isNotEmpty) {
        requiredNext =
            'Subtopics nested under topic(s) — not subject-level. Confirm in ONE language; ask once if more subtopics are wanted.';
      }

      return {
        'name': name,
        'success': true,
        'topics_added': added,
        if (createdParents.isNotEmpty) 'topics_created': createdParents,
        if (createdSubtopics.isNotEmpty) 'subtopics_created': createdSubtopics,
        if (skippedDuplicates > 0) 'topics_skipped_existing': skippedDuplicates,
        if (failedTopics.isNotEmpty) 'topics_failed': failedTopics,
        if (requiredNext != null) 'required_next_step': requiredNext,
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
        'required_next_step':
            'Ask the user in THEIR language what TOPICS they want under subject "$name". '
            'If they list topic names → addMultipleTopics/addSubjectsBulk. '
            'AFTER those topics exist you MUST still ask: "Do you want any subtopics under <topic>?" — subtopic ≠ topic.',
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
    var parentTopicName = (args['parentTopicName'] as String?)?.trim();
    // On a subtopic screen: unparented adds belong UNDER the open topic.
    if ((parentTopicName == null || parentTopicName.isEmpty) &&
        currentTopicName != null &&
        currentTopicName!.trim().isNotEmpty) {
      parentTopicName = currentTopicName!.trim();
    }

    if ((subjectName == null || subjectName.trim().isEmpty) && currentSubjectName != null) {
      subjectName = currentSubjectName;
    }

    if (subjectName == null || subjectName.trim().isEmpty) {
      _respondToFunction(callId, 'addTopic', {
        'success': false,
        'error': 'No subject specified. Please tell me which subject to add the topic to.',
      }, params: args);
      return;
    }

    final isSubtopicPath = parentTopicName != null && parentTopicName.isNotEmpty;
    if (!isSubtopicPath &&
        _gatePendingSubtopicAsk(callId, 'addTopic', subjectName.trim(), args, [name])) {
      return;
    }

    try {
      var subject = await _findSubjectByName(subjectName, retry: true);
      subject ??= await _findOrCreateSubjectByName(subjectName);

      String? parentId;
      final parentLookup = parentTopicName;
      if (parentLookup != null && parentLookup.isNotEmpty) {
        final parents = await _topicRepo.getBySubject(subject.id);
        final parent = parents.firstWhereOrNull(
          (t) =>
              (t.parentTopicId == null || t.parentTopicId!.isEmpty) &&
              t.name.toLowerCase() == parentLookup.toLowerCase(),
        );
        parentId = parent?.id;
        if (parentId == null) {
          _respondToFunction(callId, 'addTopic', {
            'success': false,
            'error':
                'Parent topic "$parentLookup" not found under "${subject.name}". '
                'Subtopics must go UNDER an existing TOPIC — do not add "$name" as a subject-level topic. '
                'Use getSubjectDetail to list topics, then call addSubtopics(subjectName, topicName, names).',
          }, params: args);
          return;
        }
      }

      await _topicRepo.create(
        subjectId: subject.id,
        name: name,
        parentTopicId: parentId,
      );
      _subjectRepo.refresh();
      _topicRepo.refresh();
      _summaryCache = null;

      if (parentId != null) {
        _clearPendingSubtopicAsk(subject.name, parentTopicName!);
        _respondToFunction(callId, 'addTopic', {
          'success': true,
          'kind': 'subtopic',
          'message':
              'SUBTOPIC "$name" was added UNDER topic "$parentTopicName" in "${subject.name}" — not a new subject topic. '
              'Confirm that in ONE language. Ask once if they want more subtopics under "$parentTopicName". '
              'Do not invent names.',
        }, params: args);
      } else {
        _noteTopicCreated(subject.name, name);
        _respondToFunction(callId, 'addTopic', {
          'success': true,
          'kind': 'topic',
          'message': 'TOPIC "$name" added under SUBJECT "${subject.name}". '
              '${_mustAskSubtopicsMessage(subject.name, [name])}',
          'required_next_step': _mustAskSubtopicsMessage(subject.name, [name]),
          'pending_subtopic_question_for': name,
        }, params: args);
      }
    } catch (e) {
      Get.snackbar('addTopic Failed', '$e', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4));
      _respondToFunction(callId, 'addTopic', {'success': false, 'error': e.toString()}, params: args);
    }
  }

  /// Batch-create subtopics under an existing topic (must not invent names).
  Future<void> _addSubtopics(String callId, Map<String, dynamic> args) async {
    final names = ((args['names'] as List?) ?? [])
        .map((e) => _sanitizeName(e.toString()))
        .where((s) => s.isNotEmpty)
        .toList();
    if (names.isEmpty) {
      _respondToFunction(callId, 'addSubtopics', {
        'success': false,
        'error': 'Provide at least one subtopic name.',
      }, params: args);
      return;
    }
    var subjectName = (args['subjectName'] as String?)?.trim();
    var topicName = (args['topicName'] as String?)?.trim();
    if ((subjectName == null || subjectName.isEmpty) && currentSubjectName != null) {
      subjectName = currentSubjectName;
    }
    if ((topicName == null || topicName.isEmpty) &&
        currentTopicName != null &&
        currentTopicName!.trim().isNotEmpty) {
      topicName = currentTopicName!.trim();
    }
    if (subjectName == null || subjectName.isEmpty || topicName == null || topicName.isEmpty) {
      _respondToFunction(callId, 'addSubtopics', {
        'success': false,
        'error': 'subjectName and topicName are required. '
            'topicName = EXISTING parent TOPIC — subtopics go under the topic, not the subject.',
      }, params: args);
      return;
    }
    try {
      final subject = await _findSubjectByName(subjectName, retry: true);
      if (subject == null) {
        _respondToFunction(callId, 'addSubtopics', {
          'success': false,
          'error': 'Subject "$subjectName" not found.',
        }, params: args);
        return;
      }
      final all = await _topicRepo.getBySubject(subject.id);
      final parentLookup = topicName!;
      final parent = all.firstWhereOrNull((t) =>
          (t.parentTopicId == null || t.parentTopicId!.isEmpty) &&
          t.name.toLowerCase() == parentLookup.toLowerCase());
      if (parent == null) {
        _respondToFunction(callId, 'addSubtopics', {
          'success': false,
          'error':
              'Topic "$parentLookup" not found under "$subjectName". Subtopics attach to a TOPIC. '
              'Call getSubjectDetail first if unsure of the topic name. Do NOT add these names as subject-level topics.',
        }, params: args);
        return;
      }
      final existing = all
          .where((t) => t.parentTopicId == parent.id)
          .map((t) => t.name.toLowerCase())
          .toSet();
      final created = <String>[];
      final skipped = <String>[];
      for (final n in names) {
        if (existing.contains(n.toLowerCase())) {
          skipped.add(n);
          continue;
        }
        await _topicRepo.create(
          subjectId: subject.id,
          name: n,
          parentTopicId: parent.id,
        );
        created.add(n);
      }
      _topicRepo.refresh();
      _summaryCache = null;
      _clearPendingSubtopicAsk(subject.name, parent.name);
      _respondToFunction(callId, 'addSubtopics', {
        'success': true,
        'kind': 'subtopics',
        'created': created,
        'skipped': skipped,
        'parent_topic': parent.name,
        'message':
            'SUBTOPICS under TOPIC "${parent.name}" in subject "${subject.name}": ${created.join(', ')} '
            '(not subject-level topics). Parent is Done only when ALL subtopics finish first-read and all 6 revisions — '
            'parent itself is never revised. Reply ONE language. Ask once if they want more subtopics under "${parent.name}".',
      }, params: args);
    } catch (e) {
      Get.snackbar('addSubtopics Failed', '$e',
          snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4));
      _respondToFunction(callId, 'addSubtopics',
          {'success': false, 'error': e.toString()}, params: args);
    }
  }

  Future<void> _addMultipleTopics(String callId, Map<String, dynamic> args) async {
    final subjectName = args['subjectName'] as String?;
    var parentTopicName = (args['parentTopicName'] as String?)?.trim();
    final topicEntries = _parseTopicEntries(args['topics']);
    final topicNames = topicEntries
        .map((e) => (e['name'] as String?) ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    // On a subtopic screen: unparented names are SUBTOPICS, not subject topics.
    if ((parentTopicName == null || parentTopicName.isEmpty) &&
        currentTopicName != null &&
        currentTopicName!.trim().isNotEmpty) {
      parentTopicName = currentTopicName!.trim();
    }

    // Subtopic request mis-routed here → create under the parent TOPIC.
    if (parentTopicName != null && parentTopicName.isNotEmpty) {
      final nested = <String>[];
      for (final e in topicEntries) {
        nested.add(e['name'] as String);
        final subs = (e['subtopics'] as List?)?.whereType<String>() ?? const [];
        nested.addAll(subs);
      }
      await _addSubtopics(callId, {
        'subjectName': subjectName,
        'topicName': parentTopicName,
        'names': nested,
      });
      return;
    }

    if (subjectName == null || subjectName.trim().isEmpty) {
      _respondToFunction(callId, 'addMultipleTopics', {'success': false, 'error': 'Subject name is required'}, params: args);
      return;
    }
    if (topicNames.isEmpty) {
      _respondToFunction(callId, 'addMultipleTopics', {'success': false, 'error': 'At least one topic name is required'}, params: args);
      return;
    }

    if (_gatePendingSubtopicAsk(
        callId, 'addMultipleTopics', subjectName.trim(), args, topicNames)) {
      return;
    }

    try {
      var subject = await _findSubjectByName(subjectName, retry: true);
      subject ??= await _findOrCreateSubjectByName(subjectName);

      final existingTopics = await _topicRepo.getBySubject(subject.id);
      final existingLower = existingTopics
          .where((t) => t.parentTopicId == null || t.parentTopicId!.isEmpty)
          .map((t) => t.name.toLowerCase())
          .toSet();
      final parentByName = <String, dynamic>{};
      for (final t in existingTopics) {
        if (t.parentTopicId == null || t.parentTopicId!.isEmpty) {
          parentByName[t.name.toLowerCase()] = t;
        }
      }

      int added = 0;
      int skippedDuplicates = 0;
      final failedTopics = <String>[];
      final createdParents = <String>[];
      final createdSubtopics = <Map<String, dynamic>>[];

      for (final entry in topicEntries) {
        final trimmed = (entry['name'] as String?) ?? '';
        if (trimmed.isEmpty) continue;
        final subs = ((entry['subtopics'] as List?) ?? const [])
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toList();

        dynamic parent;
        if (existingLower.contains(trimmed.toLowerCase())) {
          skippedDuplicates++;
          parent = parentByName[trimmed.toLowerCase()];
        } else {
          try {
            parent = await _topicRepo.create(subjectId: subject.id, name: trimmed);
            existingLower.add(trimmed.toLowerCase());
            parentByName[trimmed.toLowerCase()] = parent;
            added++;
            createdParents.add(trimmed);
            _noteTopicCreated(subject.name, trimmed);
          } catch (e) {
            debugPrint('[Gemini] ⚠️ Failed to add topic "$trimmed": $e');
            failedTopics.add(trimmed);
            continue;
          }
        }

        if (subs.isEmpty || parent == null) continue;
        final parentId = parent.id as String?;
        if (parentId == null || parentId.isEmpty) continue;
        final kids = existingTopics
            .where((t) => t.parentTopicId == parentId)
            .map((t) => t.name.toLowerCase())
            .toSet();
        for (final sub in subs) {
          if (kids.contains(sub.toLowerCase())) continue;
          try {
            await _topicRepo.create(
              subjectId: subject.id,
              name: sub,
              parentTopicId: parentId,
            );
            kids.add(sub.toLowerCase());
            createdSubtopics.add({'parent': trimmed, 'name': sub});
          } catch (e) {
            debugPrint('[Gemini] ⚠️ Failed to add subtopic "$sub" under "$trimmed": $e');
          }
        }
      }
      _subjectRepo.refresh();
      _topicRepo.refresh();
      _summaryCache = null;

      if (added == 0 && skippedDuplicates == 0 && createdSubtopics.isEmpty) {
        _respondToFunction(callId, 'addMultipleTopics', {
          'success': false,
          'error': 'Failed to add any topics to "${subject.name}"',
        }, params: args);
      } else {
        final dupNote = skippedDuplicates > 0 ? ' ($skippedDuplicates already existed, skipped)' : '';
        final failNote = failedTopics.isNotEmpty ? ' (failed: ${failedTopics.join(", ")})' : '';
        final subNote = createdSubtopics.isNotEmpty
            ? ' Nested subtopics under topics (NOT subject-level): ${createdSubtopics.map((e) => '${e['parent']}→${e['name']}').join(', ')}.'
            : '';
        final req = createdParents.isNotEmpty
            ? _mustAskSubtopicsMessage(subject.name, createdParents)
            : (createdSubtopics.isNotEmpty
                ? 'Confirm nesting in ONE language; ask once if more subtopics are wanted under those parents.'
                : null);
        _respondToFunction(callId, 'addMultipleTopics', {
          'success': true,
          if (createdParents.isNotEmpty) 'topics_created': createdParents,
          if (createdSubtopics.isNotEmpty) 'subtopics_created': createdSubtopics,
          'message':
              '$added topic(s) added to SUBJECT "${subject.name}" in first read$dupNote$failNote$subNote '
              'Revision dates are set only after markFirstReadCompleted.'
              '${req != null ? ' $req' : ''}',
          if (req != null) 'required_next_step': req,
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
      pendingSubtopicAsks.clear();
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
      _clearPendingSubtopicAsksForSubject(subject.name);
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
      _clearPendingSubtopicAsk(subject.name, topic.name);
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

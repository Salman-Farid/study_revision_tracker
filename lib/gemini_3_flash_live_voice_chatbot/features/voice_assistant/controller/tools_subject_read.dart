part of '../voice_assistant_controller.dart';

/// Voice tools that READ subjects/topics (getAllData, getSubjectDetail).
extension VoiceAssistantSubjectReadTools on VoiceAssistantController {
  // ── getAllData: returns cached result if available, otherwise queries DB.
  // Cache is invalidated (set to null) on every write (add/delete).
  Future<void> _getAllData(String callId) async {
    try {
      // Always live-read for routine planning — stale cache after delete/create
      // made the model "see" a ghost routine and loop. Keep a very short TTL only.
      final cacheAge = _summaryCachedAt == null
          ? null
          : DateTime.now().difference(_summaryCachedAt!);
      if (_summaryCache != null &&
          cacheAge != null &&
          cacheAge < const Duration(seconds: 2)) {
        debugPrint('[Gemini] ⚡ getAllData — fresh cache (${cacheAge.inMilliseconds}ms)');
        _respondToFunction(callId, 'getAllData', _summaryCache!, params: {});
        return;
      }

      final subjects = await _subjectRepo.getAll();
      final allSchedules = await _revRepo.getSchedules(topicId: null);

      // ── Get today's class routines ──
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      final classRoutines = await _routineRepo.getClassRoutines(fromDate: todayStart, toDate: todayEnd);
      final todayClasses = <Map<String, dynamic>>[];
      for (final cr in classRoutines) {
        final crDay = cr.startTime;
        // Check if this routine applies to today
        final isToday = cr.recurring
            ? cr.recurringDays.contains(now.weekday)
            : cr.dates.any((d) => d == '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}');
        if (isToday) {
          todayClasses.add({
            'subject': cr.subjectName,
            'time': '${cr.startTime.hour.toString().padLeft(2, '0')}:${cr.startTime.minute.toString().padLeft(2, '0')}',
            'duration': cr.durationMinutes,
            'location': cr.locationText,
          });
        }
      }

      // Live daily-routine snapshot (empty after delete) so the model never loops.
      List<Map<String, dynamic>> dailyToday = [];
      try {
        final drs = await _routineRepo.getDailyRoutines(fromDate: todayStart, toDate: todayEnd);
        for (final dr in drs) {
          dailyToday.addAll(dr.items.map((e) => {
                'time': e.time,
                'subject': e.subject,
                'topic': e.topic,
                'type': e.type,
              }));
        }
      } catch (_) {}

      // ── Get revision dates due today for each subject ──
      const revisionDays = [1, 3, 7, 14, 30, 90]; // Day 1, 3, 7, 14, 30, 90 after first read
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final revisionsDueToday = <Map<String, dynamic>>[];
      for (final sub in subjects) {
        final topics = await _topicRepo.getBySubject(sub.id);
        for (final topic in topics) {
          if (topic.firstReadDate != null && topic.firstReadCompleted) {
            // Compute all 6 revision dates from firstReadDate
            for (var i = topic.totalRevisions; i < 6; i++) {
              final revDate = topic.firstReadDate!.add(Duration(days: revisionDays[i]));
              final revDateStr = '${revDate.year}-${revDate.month.toString().padLeft(2, '0')}-${revDate.day.toString().padLeft(2, '0')}';
              if (revDateStr == todayStr) {
                revisionsDueToday.add({
                  'subject': sub.name,
                  'topic': topic.name,
                  'revision': '${i + 1} of 6',
                  'date': revDateStr,
                });
              }
            }
          }
        }
      }

      final summary = <Map<String, dynamic>>[];
      final fastReadTopics = <Map<String, dynamic>>[];
      for (final sub in subjects) {
        final topics = await _topicRepo.getBySubject(sub.id);
        final subSchedules = allSchedules.where((s) => s.subjectId == sub.id);
        final pendingCount = subSchedules.where((s) => s.status == 'pending').length;

        for (final t in topics) {
          if (!t.firstReadCompleted) {
            fastReadTopics.add({
              'subject': sub.name,
              'topic': t.name,
            });
          }
        }

        summary.add({
          's': sub.name,
          't': topics.length,
          'c': topics.where((t) => t.totalRevisions >= 6).length,
          'p': pendingCount,
          'fr': topics.where((t) => t.firstReadCompleted).length,
          'fast_read_left': topics.where((t) => !t.firstReadCompleted).length,
        });
      }

      final result = {
        'success': true,
        'total_subjects': subjects.length,
        'subjects': summary,
        'class_routines_today': todayClasses,
        'revisions_due_today': revisionsDueToday,
        'daily_routines_today': dailyToday,
        'daily_routines_today_empty': dailyToday.isEmpty,
        'topics_for_fast_read': fastReadTopics,
        'today': todayStr,
        'note': 'subjects: s=name,t=topics,c=completed,p=pending,fr=first_read_done,fast_read_left=topics not yet first-read. topics_for_fast_read = exact subject+topic names still in first read — answer "which subjects/topics for fast read" from THIS list in the user\'s language. daily_routines_today is the live plan (empty = none).',
      };
      _summaryCache = result;
      _summaryCachedAt = DateTime.now();
      _respondToFunction(callId, 'getAllData', result, params: {});
    } catch (e) {
      Get.snackbar('getAllData Failed', '$e', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4));
      _respondToFunction(callId, 'getAllData', {'success': false, 'error': e.toString()}, params: {});
    }
  }

  Future<void> _getSubjectDetail(String callId, Map<String, dynamic> args) async {
    final subjectName = args['subjectName'] as String?;
    if (subjectName == null || subjectName.trim().isEmpty) {
      _respondToFunction(callId, 'getSubjectDetail', {'success': false, 'error': 'Subject name is required'}, params: args);
      return;
    }
    try {
      final subject = await _findSubjectByName(subjectName);
      if (subject == null) {
        _respondToFunction(callId, 'getSubjectDetail', {'success': false, 'error': 'Subject "$subjectName" not found'}, params: args);
        return;
      }

      final topics = await _topicRepo.getBySubject(subject.id);
      final schedules = await _revRepo.getSchedules(topicId: null);
      final subSchedules = schedules.where((s) => s.subjectId == subject.id).toList();

      final topicList = <Map<String, dynamic>>[];
      for (final t in topics) {
        final topicSchedules = subSchedules.where((s) => s.topicId == t.id).toList();
        final pending = topicSchedules.where((s) => s.status == 'pending').length;
        final completed = topicSchedules.where((s) => s.status == 'completed').length;
        final nextDate = topicSchedules
            .where((s) => s.status == 'pending')
            .map((s) => s.scheduledDate)
            .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);

        topicList.add({
          'name': t.name,
          'first_read_done': t.firstReadCompleted,
          'pending': pending,
          'completed': completed,
          'next': nextDate != null ? '${nextDate.day}/${nextDate.month}/${nextDate.year}' : 'none',
        });
      }

      _respondToFunction(callId, 'getSubjectDetail', {
        'success': true,
        'subject': subject.name,
        'topics': topicList,
      }, params: args);
    } catch (e) {
      Get.snackbar('getSubjectDetail Failed', '$e', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4));
      _respondToFunction(callId, 'getSubjectDetail', {'success': false, 'error': e.toString()}, params: args);
    }
  }

}

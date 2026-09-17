part of '../voice_assistant_controller.dart';

/// Voice tools for topic status + mark first-read / revision complete.
extension VoiceAssistantTopicRevisionTools on VoiceAssistantController {
  Future<void> _getTopicStatus(String callId, Map<String, dynamic> args) async {
    var subjectName = args['subjectName'] as String?;
    final topicName = args['topicName'] as String?;
    if ((subjectName == null || subjectName.trim().isEmpty) && currentSubjectName != null) {
      subjectName = currentSubjectName;
    }
    if (subjectName == null || subjectName.trim().isEmpty || topicName == null || topicName.trim().isEmpty) {
      _respondToFunction(callId, 'getTopicStatus', {
        'success': false, 'error': 'Both subject name and topic name are required',
      }, params: args);
      return;
    }
    try {
      final subject = await _findSubjectByName(subjectName);
      if (subject == null) {
        _respondToFunction(callId, 'getTopicStatus', {
          'success': false, 'error': 'Subject "$subjectName" not found',
        }, params: args);
        return;
      }
      final topic = await _findTopicByName(subject.id, topicName);
      if (topic == null) {
        _respondToFunction(callId, 'getTopicStatus', {
          'success': false, 'error': 'Topic "$topicName" not found in "${subject.name}"',
        }, params: args);
        return;
      }

      final status = await _topicRepo.getTopicFullStatus(topic.id);
      final nextIdx = status['nextPendingRevisionIndex'] as int;
      final completedCount = status['completedRevisionCount'] as int;
      final totalCount = status['totalRevisions'] as int;
      final pendingBeforeNext = status['pendingBeforeNext'] as List<int>;
      final completedDays = status['completedDays'] as List<int>;
      final schedules = status['schedules'] as List<dynamic>;

      // Build revision schedule with actual dates
      final revisionLabels = ['1st (Day 1)', '2nd (Day 3)', '3rd (Day 7)', '4th (Day 14)', '5th (Day 30)', '6th (Day 90)'];
      final revisionSchedule = <String>[];
      for (int i = 0; i < schedules.length; i++) {
        final s = schedules[i];
        final date = s.scheduledDate.toString().substring(0, 10); // YYYY-MM-DD
        final statusStr = s.status == 'completed' ? '✅ Done' : '⏳ Pending';
        revisionSchedule.add('${revisionLabels[i]}: $date ($statusStr)');
      }

      String nextRevisionInfo;
      if (nextIdx < 0) {
        nextRevisionInfo = 'All $totalCount revisions completed';
      } else {
        final nextDate = (schedules[nextIdx]['scheduled_date'] as String).substring(0, 10);
        nextRevisionInfo = 'Next: ${revisionLabels[nextIdx]} on $nextDate';
      }

      _respondToFunction(callId, 'getTopicStatus', {
        'success': true,
        'subject': subject.name,
        'topic': topic.name,
        'first_read_completed': topic.firstReadCompleted,
        'first_read_date': topic.firstReadDate?.toString().substring(0, 10),
        'completed_revisions': completedCount,
        'total_revisions': totalCount,
        'completed_revision_days': completedDays,
        'revision_schedule': revisionSchedule,
        'next_revision': nextRevisionInfo,
        'pending_before_next': pendingBeforeNext,
      }, params: args);
    } catch (e) {
      Get.snackbar('getTopicStatus Failed', '$e', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4));
      _respondToFunction(callId, 'getTopicStatus', {'success': false, 'error': e.toString()}, params: args);
    }
  }

  Future<void> _getAllTopicsRevisionDates(String callId, Map<String, dynamic> args) async {
    var subjectName = args['subjectName'] as String?;
    if ((subjectName == null || subjectName.trim().isEmpty) && currentSubjectName != null) {
      subjectName = currentSubjectName;
    }
    if (subjectName == null || subjectName.trim().isEmpty) {
      _respondToFunction(callId, 'getAllTopicsRevisionDates', {
        'success': false, 'error': 'Subject name is required',
      }, params: args);
      return;
    }
    try {
      final subject = await _findSubjectByName(subjectName);
      if (subject == null) {
        _respondToFunction(callId, 'getAllTopicsRevisionDates', {
          'success': false, 'error': 'Subject "$subjectName" not found',
        }, params: args);
        return;
      }

      final topics = await _topicRepo.getBySubject(subject.id);
      if (topics.isEmpty) {
        _respondToFunction(callId, 'getAllTopicsRevisionDates', {
          'success': true,
          'subject': subject.name,
          'topics': [],
          'message': 'No topics found in "${subject.name}".',
        }, params: args);
        return;
      }

      final revisionLabels = ['1st (Day 1)', '2nd (Day 3)', '3rd (Day 7)', '4th (Day 14)', '5th (Day 30)', '6th (Day 90)'];
      final topicsData = <Map<String, dynamic>>[];

      for (final topic in topics) {
        final status = await _topicRepo.getTopicFullStatus(topic.id);
        final schedules = status['schedules'] as List<dynamic>;
        final completedCount = status['completedRevisionCount'] as int;

        final scheduleList = <String>[];
        for (int i = 0; i < schedules.length; i++) {
          final s = schedules[i];
          final date = s.scheduledDate.toString().substring(0, 10);
          final st = s.status == 'completed' ? 'Done' : 'Pending';
          scheduleList.add('${revisionLabels[i]}: $date ($st)');
        }

        topicsData.add({
          'topic': topic.name,
          'first_read_completed': topic.firstReadCompleted,
          'first_read_date': topic.firstReadDate?.toString().substring(0, 10),
          'completed_revisions': completedCount,
          'schedule': scheduleList,
        });
      }

      _respondToFunction(callId, 'getAllTopicsRevisionDates', {
        'success': true,
        'subject': subject.name,
        'topics': topicsData,
      }, params: args);
    } catch (e) {
      Get.snackbar('getAllTopicsRevisionDates Failed', '$e', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4));
      _respondToFunction(callId, 'getAllTopicsRevisionDates', {'success': false, 'error': e.toString()}, params: args);
    }
  }

  Future<void> _markFirstReadCompleted(String callId, Map<String, dynamic> args) async {
    var subjectName = args['subjectName'] as String?;
    final topicName = args['topicName'] as String?;
    if ((subjectName == null || subjectName.trim().isEmpty) && currentSubjectName != null) {
      subjectName = currentSubjectName;
    }
    if (subjectName == null || subjectName.trim().isEmpty || topicName == null || topicName.trim().isEmpty) {
      _respondToFunction(callId, 'markFirstReadCompleted', {
        'success': false, 'error': 'Both subject name and topic name are required',
      }, params: args);
      return;
    }
    try {
      final subject = await _findSubjectByName(subjectName);
      if (subject == null) {
        _respondToFunction(callId, 'markFirstReadCompleted', {
          'success': false, 'error': 'Subject "$subjectName" not found',
        }, params: args);
        return;
      }
      final topic = await _findTopicByName(subject.id, topicName);
      if (topic == null) {
        _respondToFunction(callId, 'markFirstReadCompleted', {
          'success': false, 'error': 'Topic "$topicName" not found in "${subject.name}"',
        }, params: args);
        return;
      }

      if (topic.firstReadCompleted) {
        _respondToFunction(callId, 'markFirstReadCompleted', {
          'success': true,
          'already_completed': true,
          'message': 'First read for "${topic.name}" is already completed. You can now work on revisions.',
        }, params: args);
        return;
      }

      await _topicRepo.markFirstReadCompleted(topic.id);

      // Create the 6 revision schedules FROM THIS MOMENT — not from add time.
      final existing = await _revRepo.getSchedules(topicId: topic.id);
      if (existing.isEmpty) {
        final created = await _revRepo.createSchedules(
          topicId: topic.id,
          subjectId: subject.id,
          firstReadDate: DateTime.now(),
        );
        try {
          final notifications = NotificationService.to;
          for (final schedule in created) {
            await notifications.scheduleRevision(
              schedule: schedule,
              topicName: topic.name,
              subjectName: subject.name,
            );
          }
        } catch (e) {
          debugPrint('[Gemini] ⚠️ Failed to schedule revision notifications: $e');
        }
      }

      _topicRepo.refresh();
      _summaryCache = null;

      _respondToFunction(callId, 'markFirstReadCompleted', {
        'success': true,
        'already_completed': false,
        'message': 'First read for "${topic.name}" marked as completed. 6 revision dates are now scheduled starting from today (Day 1, 3, 7, 14, 30, 90).',
      }, params: args);
    } catch (e, st) {
      debugPrint('[Gemini] markFirstReadCompleted FAILED: $e');
      debugPrint('[Gemini] Stacktrace: $st');
      Get.snackbar('markFirstReadCompleted Failed', '$e', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4));
      _respondToFunction(callId, 'markFirstReadCompleted', {'success': false, 'error': e.toString()}, params: args);
    }
  }

  Future<void> _markRevisionCompleted(String callId, Map<String, dynamic> args) async {
    var subjectName = args['subjectName'] as String?;
    final topicName = args['topicName'] as String?;
    if ((subjectName == null || subjectName.trim().isEmpty) && currentSubjectName != null) {
      subjectName = currentSubjectName;
    }
    if (subjectName == null || subjectName.trim().isEmpty || topicName == null || topicName.trim().isEmpty) {
      _respondToFunction(callId, 'markRevisionCompleted', {
        'success': false, 'error': 'Both subject name and topic name are required',
      }, params: args);
      return;
    }
    try {
      final subject = await _findSubjectByName(subjectName);
      if (subject == null) {
        _respondToFunction(callId, 'markRevisionCompleted', {
          'success': false, 'error': 'Subject "$subjectName" not found',
        }, params: args);
        return;
      }
      final topic = await _findTopicByName(subject.id, topicName);
      if (topic == null) {
        _respondToFunction(callId, 'markRevisionCompleted', {
          'success': false, 'error': 'Topic "$topicName" not found in "${subject.name}"',
        }, params: args);
        return;
      }

      final status = await _topicRepo.getTopicFullStatus(topic.id);
      final nextIdx = status['nextPendingRevisionIndex'] as int;
      final completedCount = status['completedRevisionCount'] as int;
      final totalCount = status['totalRevisions'] as int;
      final pendingBeforeNext = status['pendingBeforeNext'] as List<int>;

      if (nextIdx < 0) {
        _respondToFunction(callId, 'markRevisionCompleted', {
          'success': false,
          'all_completed': true,
          'message': 'All $totalCount revisions for "${topic.name}" are already completed. Great job!',
        }, params: args);
        return;
      }

      if (pendingBeforeNext.isNotEmpty) {
        final dayLabels = {1: '1st', 3: '2nd', 7: '3rd', 14: '4th', 30: '5th', 90: '6th'};
        final pendingLabels = pendingBeforeNext.map((d) => '${dayLabels[d] ?? "Day $d"} revision').join(', ');
        _respondToFunction(callId, 'markRevisionCompleted', {
          'success': false,
          'pending_before': pendingBeforeNext,
          'message': 'Cannot mark revision yet. You need to complete the $pendingLabels first. Revisions must follow the order: 1st → 2nd → 3rd → 4th → 5th → 6th.',
        }, params: args);
        return;
      }

      await _topicRepo.markNextRevisionCompleted(topic.id);
      _topicRepo.refresh();
      _summaryCache = null;

      final revisionLabels = ['1st (Day 1)', '2nd (Day 3)', '3rd (Day 7)', '4th (Day 14)', '5th (Day 30)', '6th (Day 90)'];
      final justCompleted = revisionLabels[nextIdx];
      final newCompletedCount = completedCount + 1;

      String nextInfo;
      if (newCompletedCount >= totalCount) {
        nextInfo = 'All revisions completed!';
      } else {
        nextInfo = 'Next revision: ${revisionLabels[nextIdx + 1]}';
      }

      _respondToFunction(callId, 'markRevisionCompleted', {
        'success': true,
        'completed_revision': justCompleted,
        'completed_count': newCompletedCount,
        'total_revisions': totalCount,
        'next_revision': nextInfo,
        'message': '$justCompleted revision for "${topic.name}" completed ($newCompletedCount/$totalCount). $nextInfo',
      }, params: args);
    } catch (e) {
      Get.snackbar('markRevisionCompleted Failed', '$e', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4));
      _respondToFunction(callId, 'markRevisionCompleted', {'success': false, 'error': e.toString()}, params: args);
    }
  }
}

part of '../voice_assistant_controller.dart';

/// Voice tools that CREATE class and daily routines.
extension VoiceAssistantRoutineTools on VoiceAssistantController {
  Future<void> _registerClassRoutine(String callId, Map<String, dynamic> args) async {
    final subjectName = (args['subjectName'] as String?)?.trim();
    final startTimeStr = (args['startTime'] as String?)?.trim();
    final durationMinutes = (args['durationMinutes'] as num?)?.toInt();
    final dates = (args['dates'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final recurringDays = (args['recurringDays'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? [];
    // Accept single "location" field
    final location = (args['location'] as String?)?.trim();
    final notes = (args['notes'] as String?)?.trim();

    if (subjectName == null || subjectName.isEmpty) {
      _respondToFunction(callId, 'registerClassRoutine', {
        'success': false, 'error': 'Subject name is required',
      }, params: args);
      return;
    }
    if (startTimeStr == null || startTimeStr.isEmpty) {
      _respondToFunction(callId, 'registerClassRoutine', {
        'success': false, 'error': 'Start time is required (HH:MM format)',
      }, params: args);
      return;
    }
    if (durationMinutes == null || durationMinutes <= 0) {
      _respondToFunction(callId, 'registerClassRoutine', {
        'success': false, 'error': 'Duration in minutes is required',
      }, params: args);
      return;
    }
    if (dates.isEmpty && recurringDays.isEmpty) {
      _respondToFunction(callId, 'registerClassRoutine', {
        'success': false, 'error': 'At least one date (YYYY-MM-DD) or recurring days (1-7) is required',
      }, params: args);
      return;
    }

    // Location is optional — pass the single location field
    final finalLocation = location;

    try {
      final now = DateTime.now();
      // Parse time — handle "9:00", "09:00", "9:00 AM", "14:00" etc.
      var cleanTime = startTimeStr.replaceAll(RegExp(r'\s*(?:am|pm)\s*$', caseSensitive: false), '').trim();
      final parts = cleanTime.split(':');
      var hour = int.tryParse(parts[0]) ?? 0;
      final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
      // Handle AM/PM
      if (startTimeStr.toLowerCase().contains('pm') && hour < 12) hour += 12;
      if (startTimeStr.toLowerCase().contains('am') && hour == 12) hour = 0;
      final startTime = DateTime(now.year, now.month, now.day, hour, minute);
      debugPrint('[Gemini] Class routine: subject=$subjectName, time=$startTime, dur=$durationMinutes, dates=$dates, location=$finalLocation');

      final routine = await _routineRepo.createClassRoutine(
        subjectName: subjectName,
        startTime: startTime,
        durationMinutes: durationMinutes,
        dates: dates,
        location: finalLocation,
        recurring: recurringDays.isNotEmpty,
        recurringDays: recurringDays,
        notes: notes,
      );

      final locationText = routine.locationText.isNotEmpty ? ' at ${routine.locationText}' : '';
      final dateText = dates.isNotEmpty
          ? ' on ${dates.join(", ")}'
          : recurringDays.isNotEmpty
              ? ' every ${recurringDays.map((d) => ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d]).join(", ")}'
              : '';

      Get.snackbar('Success', 'Class routine saved: $subjectName at ${routine.timeText}$locationText$dateText',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade700,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 3));

      _respondToFunction(callId, 'registerClassRoutine', {
        'success': true,
        'routine_id': routine.id,
        'subject': subjectName,
        'time': routine.timeText,
        'duration': routine.durationText,
        'location': routine.locationText,
        'message': 'Class routine registered: $subjectName at ${routine.timeText} ($durationMinutes min)$locationText$dateText.',
      }, params: args);

      // Force refresh so RoutineController picks it up immediately
      refreshClassRoutines();
    } catch (e, stack) {
      debugPrint('[Gemini] ❌ registerClassRoutine FAILED: $e');
      debugPrint('[Gemini] Stack: $stack');
      Get.snackbar('Error', 'Class routine save failed: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 5));
      _respondToFunction(callId, 'registerClassRoutine', {
        'success': false, 'error': 'Failed to save class routine: $e',
      }, params: args);
    }
  }

  Future<void> _registerDailyRoutine(String callId, Map<String, dynamic> args) async {
    final itemsRaw = args['items'] as List<dynamic>?;
    final dateStr = (args['date'] as String?)?.trim();

    if (itemsRaw == null || itemsRaw.isEmpty) {
      _respondToFunction(callId, 'registerDailyRoutine', {
        'success': false, 'error': 'At least one study block item is required',
      }, params: args);
      return;
    }

    try {
      final now = DateTime.now();
      final date = dateStr != null && dateStr.isNotEmpty
          ? DateTime.parse(dateStr)
          : DateTime(now.year, now.month, now.day);

      // ── Validate: every study/revision/first_read/review block must reference
      //    a subject that actually exists in the DB ──
      final allSubjects = await _subjectRepo.getAll();
      final validNames = allSubjects.map((s) => s.name.toLowerCase()).toSet();
      final invalidSubjects = <String>{};

      for (final raw in itemsRaw) {
        final m = raw as Map<String, dynamic>;
        final type = (m['type'] as String?) ?? 'study';
        final subject = (m['subject'] as String?) ?? '';

        // Allowed non-database subject names for non-study blocks
        const allowedNonDb = {'break', 'breakfast', 'lunch', 'dinner', 'power nap'};

        // Only validate study-related blocks — breaks, meals, naps, recall don't need real subjects
        if (type == 'study' || type == 'first_read' || type == 'revision' ||
            type == 'review' || type == 'question_practice') {
          if (subject.isNotEmpty &&
              !validNames.contains(subject.toLowerCase()) &&
              !allowedNonDb.contains(subject.toLowerCase())) {
            invalidSubjects.add(subject);
          }
        }
      }

      if (invalidSubjects.isNotEmpty) {
        final validList = allSubjects.map((s) => s.name).join(', ');
        Get.snackbar('Error', 'Subjects not found: ${invalidSubjects.join(", ")}. Valid: $validList',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.shade700,
            colorText: Colors.white,
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 5));
        _respondToFunction(callId, 'registerDailyRoutine', {
          'success': false,
          'error': 'Subjects not found in database: ${invalidSubjects.join(", ")}. '
              'Valid subjects: $validList. '
              'Use getAllData first to see available subjects and topics.',
        }, params: args);
        return;
      }

      final items = itemsRaw.map((raw) {
        final m = raw as Map<String, dynamic>;
        // Check both camelCase and snake_case — Gemini sends camelCase
        final dur = (m['durationMinutes'] as num?)?.toInt()
            ?? (m['duration_minutes'] as num?)?.toInt()
            ?? 45;
        return DailyRoutineItem(
          time: m['time'] as String? ?? '',
          subject: m['subject'] as String? ?? '',
          topic: m['topic'] as String? ?? '',
          type: m['type'] as String? ?? 'study',
          durationMinutes: dur,
          notes: m['notes'] as String?,
        );
      }).toList();

      final routine = await _routineRepo.createDailyRoutine(
        date: date,
        items: items,
      );

      final summary = items.map((it) => '${it.time} ${it.subject}→${it.topic}').join('; ');

      Get.snackbar('Success', 'Daily routine saved: ${items.length} blocks for ${date.toIso8601String().substring(0, 10)}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade700,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 3));

      _respondToFunction(callId, 'registerDailyRoutine', {
        'success': true,
        'routine_id': routine.id,
        'date': date.toIso8601String().substring(0, 10),
        'blocks_count': items.length,
        'message': 'Daily routine saved for ${date.toIso8601String().substring(0, 10)} with ${items.length} blocks: $summary',
      }, params: args);

      // Schedule a local notification for every future block right away.
      try {
        final n = await NotificationService.to.scheduleDailyRoutine(routine: routine);
        debugPrint('[Gemini] scheduled $n daily-routine notifications for ${routine.id}');
      } catch (e) {
        debugPrint('[Gemini] ⚠️ Failed to schedule daily routine notifications: $e');
      }

      // Force refresh so RoutineController picks it up immediately
      refreshDailyRoutines();
    } catch (e) {
      Get.snackbar('Error', 'Daily routine save failed: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 5));
      _respondToFunction(callId, 'registerDailyRoutine', {
        'success': false, 'error': e.toString(),
      }, params: args);
    }
  }

  Future<void> _deleteClassRoutine(String callId, Map<String, dynamic> args) async {
    final subjectName = args['subjectName'] as String?;
    if (subjectName == null || subjectName.trim().isEmpty) {
      _respondToFunction(callId, 'deleteClassRoutine', {
        'success': false, 'error': 'Subject name is required to identify which class routine to delete.',
      }, params: args);
      return;
    }

    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, 1);
      final to = from.add(const Duration(days: 60));
      final routines = await _routineRepo.getClassRoutines(fromDate: from, toDate: to);

      final matched = routines.where(
        (r) => r.subjectName.toLowerCase().contains(subjectName.toLowerCase()),
      ).toList();

      if (matched.isEmpty) {
        Get.snackbar('Not Found', 'No class routine found for "$subjectName"',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange.shade700,
            colorText: Colors.white,
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 3));
        _respondToFunction(callId, 'deleteClassRoutine', {
          'success': false, 'error': 'No class routine found for "$subjectName".',
        }, params: args);
        return;
      }

      for (final r in matched) {
        await _routineRepo.deleteClassRoutine(r.id);
      }

      refreshClassRoutines();

      Get.snackbar('Deleted', 'Class routine removed: ${matched.first.subjectName}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade700,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 3));

      _respondToFunction(callId, 'deleteClassRoutine', {
        'success': true,
        'message': 'Deleted ${matched.length} class routine(s) for "${matched.first.subjectName}".',
        'deleted_count': matched.length,
      }, params: args);
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete class routine: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 5));
      _respondToFunction(callId, 'deleteClassRoutine', {
        'success': false, 'error': e.toString(),
      }, params: args);
    }
  }

  Future<void> _deleteDailyRoutine(String callId, Map<String, dynamic> args) async {
    final dateStr = args['date'] as String?;
    final now = DateTime.now();
    final date = dateStr != null && dateStr.isNotEmpty
        ? DateTime.parse(dateStr)
        : DateTime(now.year, now.month, now.day);

    try {
      final deletedCount = await _routineRepo.deleteDailyRoutinesByDate(date);

      if (deletedCount == 0) {
        Get.snackbar('Not Found', 'No daily routine for ${date.toIso8601String().substring(0, 10)}',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange.shade700,
            colorText: Colors.white,
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 3));
        _respondToFunction(callId, 'deleteDailyRoutine', {
          'success': false, 'error': 'No daily routine found for ${date.toIso8601String().substring(0, 10)}.',
        }, params: args);
        return;
      }

      refreshDailyRoutines();

      Get.snackbar('Deleted', 'Daily routine removed: ${date.toIso8601String().substring(0, 10)} ($deletedCount items)',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade700,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 3));

      _respondToFunction(callId, 'deleteDailyRoutine', {
        'success': true,
        'message': 'Deleted daily routine for ${date.toIso8601String().substring(0, 10)} ($deletedCount items).',
        'deleted_count': deletedCount,
      }, params: args);
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete daily routine: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 5));
      _respondToFunction(callId, 'deleteDailyRoutine', {
        'success': false, 'error': e.toString(),
      }, params: args);
    }
  }
}

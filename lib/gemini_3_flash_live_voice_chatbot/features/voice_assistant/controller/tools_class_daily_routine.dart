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
        'message': 'Class routine registered: $subjectName at ${routine.timeText} (${routine.durationText})$locationText$dateText. Reply times in 12-hour AM/PM only.',
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
        final subject = m['subject'] as String? ?? '';
        final type = m['type'] as String? ?? 'study';
        return DailyRoutineItem(
          time: m['time'] as String? ?? '',
          subject: subject,
          topic: m['topic'] as String? ?? '',
          type: type,
          // Enforce canonical durations — never break=50 / study=10; review/QP=50.
          durationMinutes: _canonicalDuration(type, dur, subject: subject),
          notes: m['notes'] as String?,
        );
      }).toList();

      // Policy: no review spam, max 1 QP, break rules, study-first reorder.
      final policyItems = _enforceRoutinePolicy(items, maxBreaks: 6);

      if (!policyItems.any((e) => _isStudy(e.type) || e.type == 'revision')) {
        _respondToFunction(callId, 'registerDailyRoutine', {
          'success': false,
          'error': 'Routine has no study/revision blocks. Include due revisions (30 min each, all at the start) if any are due, then study sessions on real topics. Do not send only breaks/question practice/review.',
        }, params: args);
        return;
      }

      // HARD RULE: day ends at exactly 23:30 (11:30 PM). Times stay continuous.
      final dayEnd = DateTime(date.year, date.month, date.day, 23, 30);
      DateTime parseStart(String time) {
        final parts = time.split(':');
        final h = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
        final mnt = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
        return DateTime(date.year, date.month, date.day, h, mnt);
      }

      String fmt(DateTime t) =>
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

      // Keep class slots fixed; pack other blocks continuously from the first start.
      final sorted = [...policyItems]
        ..sort((a, b) => parseStart(a.time).compareTo(parseStart(b.time)));
      final firstStart = sorted.isEmpty
          ? DateTime.now()
          : parseStart(sorted.first.time);
      var cursor = firstStart.isAfter(dayEnd.subtract(const Duration(minutes: 10)))
          ? dayEnd.subtract(const Duration(minutes: 50))
          : firstStart;

      final clamped = <DailyRoutineItem>[];
      for (final it in sorted) {
        if (cursor.isAfter(dayEnd) || cursor.isAtSameMomentAs(dayEnd)) break;
        var start = parseStart(it.time);
        var duration = it.durationMinutes;

        if (it.type == 'class') {
          // Keep registered class time; resume after it if we're behind.
          if (!start.isBefore(dayEnd)) continue;
          final maxMin = dayEnd.difference(start).inMinutes;
          duration = duration.clamp(1, maxMin);
          final classEnd = start.add(Duration(minutes: duration));
          if (classEnd.isAfter(cursor)) cursor = classEnd;
        } else {
          if (start.isBefore(cursor)) start = cursor;
          if (!start.isBefore(dayEnd)) break;
          final maxMin = dayEnd.difference(start).inMinutes;
          // Don't start a long study block that cannot fit meaningfully.
          if ((it.type == 'study' || it.type == 'first_read') && maxMin < 20) {
            break;
          }
          duration = duration.clamp(1, maxMin);
          cursor = start.add(Duration(minutes: duration));
        }

        clamped.add(DailyRoutineItem(
          time: fmt(start),
          subject: it.subject,
          topic: it.topic,
          type: it.type,
          durationMinutes: duration,
          notes: it.notes,
        ));
      }

      if (clamped.isEmpty) {
        _respondToFunction(callId, 'registerDailyRoutine', {
          'success': false,
          'error': 'All blocks fall outside the day. Routine must run until exactly 11:30 PM — start from the current time.',
        }, params: args);
        return;
      }

      final routine = await _routineRepo.createDailyRoutine(
        date: date,
        items: clamped,
      );

      // Always report times to the user in 12-hour AM/PM.
      final summary = clamped.map((it) {
        final startText = formatTime12Hour(it.time);
        final startDt = parseStart(it.time);
        final endText = formatHm12(
          startDt.add(Duration(minutes: it.durationMinutes)).hour,
          startDt.add(Duration(minutes: it.durationMinutes)).minute,
        );
        return '$startText–$endText ${it.subject}${it.topic.isNotEmpty ? ' / ${it.topic}' : ''} (${it.durationMinutes}m)';
      }).join('; ');

      Get.snackbar('Success', 'Daily routine saved: ${clamped.length} blocks until 11:30 PM',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade700,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 3));

      _respondToFunction(callId, 'registerDailyRoutine', {
        'success': true,
        'routine_id': routine.id,
        'date': date.toIso8601String().substring(0, 10),
        'blocks_count': clamped.length,
        'ends_at': '11:30 PM',
        'time_format_reply': '12-hour AM/PM',
        'message': 'Daily routine saved for ${date.toIso8601String().substring(0, 10)} — ${clamped.length} blocks, ends at 11:30 PM. '
            'Tell the user ONLY in 12-hour format. Blocks: $summary',
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

  /// Canonical block lengths — study is never 10 min; break is never 50 min.
  int _canonicalDuration(String type, int sent, {String subject = ''}) {
    switch (type) {
      case 'study':
      case 'first_read':
      case 'question_practice':
        return 50;
      case 'break':
        return 10;
      case 'recall':
        return 15;
      case 'nap':
        return (sent <= 0 ? 20 : sent).clamp(20, 25);
      case 'revision':
        // Due-revision blocks are always 30 minutes (user rule).
        return 30;
      case 'meal':
        final s = subject.toLowerCase();
        if (s.contains('breakfast')) return 20;
        if (s.contains('lunch')) return 25;
        if (s.contains('dinner')) return 20;
        return (sent <= 0 ? 20 : sent).clamp(15, 30);
      case 'class':
        return sent <= 0 ? 60 : sent;
      // review/quick review are forbidden — duration irrelevant (dropped later).
      case 'review':
        return 50;
      default:
        return (sent <= 0 ? 30 : sent).clamp(5, 90);
    }
  }

  bool _isStudy(String type) => type == 'study' || type == 'first_read';

  /// Break policy (student-realistic, no hard daily cap):
  /// - NEVER a break unless the previous block was study/first_read (or other long work).
  /// - After each study session: add Break 10 ONLY if the next block is not
  ///   already meal / nap / class (those already rest the student).
  /// - If nothing follows the study block (end of list), no break is inserted.
  /// - Never stack two breaks; never break before the first work block.
  List<DailyRoutineItem> _enforceRoutinePolicy(
    List<DailyRoutineItem> items, {
    int maxBreaks = 6,
  }) {
    // maxBreaks is unused — kept for call-site compatibility. No daily cap.
    var qpUsed = 0;
    final revisions = <DailyRoutineItem>[];
    final leadingClasses = <DailyRoutineItem>[];
    final work = <DailyRoutineItem>[];

    for (final it in items) {
      final type = it.type;
      if (type == 'review') continue; // forbidden filler
      if (type == 'break') continue; // re-inserted only after study
      if (type == 'question_practice') {
        if (qpUsed >= 1) continue;
        qpUsed++;
      }
      if (type == 'revision') {
        revisions.add(it);
        continue;
      }
      if (type == 'class' && work.isEmpty && revisions.isEmpty) {
        leadingClasses.add(it);
        continue;
      }
      work.add(it);
    }

    // Rebuild: leading class → ALL due revisions → work, with study→break.
    final body = [...revisions, ...work];
    final out = <DailyRoutineItem>[...leadingClasses];

    for (var i = 0; i < body.length; i++) {
      final it = body[i];
      out.add(it);
      final isStudy = it.type == 'study' || it.type == 'first_read';
      if (!isStudy) continue;
      final next = i + 1 < body.length ? body[i + 1] : null;
      if (next == null) continue; // end of day — no trailing break
      // Meal / nap / class already rest the student → skip break.
      if (next.type == 'meal' || next.type == 'nap' || next.type == 'class') {
        continue;
      }
      out.add(DailyRoutineItem(
        time: it.time,
        subject: 'Break',
        topic: '',
        type: 'break',
        durationMinutes: 10,
        notes: 'After study session',
      ));
    }

    return out;
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

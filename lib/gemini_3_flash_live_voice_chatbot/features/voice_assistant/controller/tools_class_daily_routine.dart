part of '../voice_assistant_controller.dart';

/// Voice tools that CREATE class and daily routines.
extension VoiceAssistantRoutineTools on VoiceAssistantController {
  /// ROUTINE FLOW GATE — returns true when the call may proceed.
  /// Blocks until topicScope is "specific" or "all" (user answered, or the
  /// same turn already made scope obvious). Mirrors the HIERARCHY GATE.
  bool _gateRoutineTopicScope(
    String callId,
    String toolName,
    Map<String, dynamic> args,
  ) {
    final scope = (args['topicScope'] as String?)?.trim().toLowerCase();
    if (scope == 'specific' || scope == 'all') return true;

    _respondToFunction(callId, toolName, {
      'success': false,
      'blocked': 'routine_topic_scope_missing',
      'error':
          'ROUTINE FLOW GATE: topicScope is required ("specific" or "all"). '
          'You MUST first ask the user (their language): '
          '"Specific topic(s) or all topics?" and WAIT for their answer. '
          'Then call $toolName again with topicScope: "specific" '
          '(only the named subject/topic(s); for daily also pass topicNames) '
          'OR topicScope: "all" (first-read topics + due revisions for all subjects). '
          'If this turn already named specific subject(s)/topic(s) → use "specific" with those exact names. '
          'If they said all/everything → use "all". Never invent names.',
      'pending_question': 'specific_topic_or_all_topics',
    }, params: args);
    return false;
  }

  Future<void> _registerClassRoutine(String callId, Map<String, dynamic> args) async {
    // ROUTINE FLOW GATE — topicScope must be decided (asked or obvious) first.
    if (!_gateRoutineTopicScope(callId, 'registerClassRoutine', args)) return;

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
    // ROUTINE FLOW GATE — topicScope must be decided (asked or obvious) first.
    if (!_gateRoutineTopicScope(callId, 'registerDailyRoutine', args)) return;

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
      // Calendar day = actual create day (hard rule: now → 23:30, even at 2 AM).
      final DateTime date = DateTime(now.year, now.month, now.day);

      // ── Validate: every study/revision/first_read/review block must reference
      //    a subject that actually exists in the DB ──
      final allSubjects = await _subjectRepo.getAll();
      final validNames = allSubjects.map((s) => s.name.toLowerCase()).toSet();
      final invalidSubjects = <String>{};

      for (final raw in itemsRaw) {
        final m = raw as Map<String, dynamic>;
        final type = (m['type'] as String?) ?? 'study';
        final subject = (m['subject'] as String?) ?? '';

        // Allowed non-database labels (app fills study gaps with these too).
        const allowedNonDb = {
          'break', 'breakfast', 'lunch', 'dinner', 'snack', 'power nap',
          'self study', 'study gap filler', 'final study gap filler',
          'gap filler', 'focus time', 'wrap up', 'catch up',
        };

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

      // HARD RULE: never fail the first save on invented labels like
      // "Study Gap Filler". Heal them to a real subject instead.
      String? fallbackSubject;
      for (final raw in itemsRaw) {
        final m = raw as Map<String, dynamic>;
        final t = (m['type'] as String?) ?? 'study';
        final sn = (m['subject'] as String?) ?? '';
        if ((t == 'study' ||
                t == 'first_read' ||
                t == 'revision' ||
                t == 'question_practice') &&
            validNames.contains(sn.toLowerCase())) {
          fallbackSubject = sn;
          break;
        }
      }
      fallbackSubject ??=
          allSubjects.isNotEmpty ? allSubjects.first.name : 'Self Study';

      if (invalidSubjects.isNotEmpty) {
        for (final raw in itemsRaw) {
          final m = raw as Map<String, dynamic>;
          final t = (m['type'] as String?) ?? 'study';
          final sn = (m['subject'] as String?) ?? '';
          if (t == 'study' ||
              t == 'first_read' ||
              t == 'revision' ||
              t == 'review' ||
              t == 'question_practice') {
            if (sn.isNotEmpty &&
                !validNames.contains(sn.toLowerCase()) &&
                !const {
                  'self study',
                  'study gap filler',
                  'final study gap filler',
                  'gap filler',
                  'focus time',
                  'wrap up',
                  'catch up',
                }.contains(sn.toLowerCase())) {
              m['subject'] = fallbackSubject;
            }
          }
        }
        debugPrint(
            '[Gemini] healed invented subjects ${invalidSubjects.join(', ')} → $fallbackSubject');
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
      // Meals are injected at FIXED times below — drop any client-sent meals.
      final policyItems = _enforceRoutinePolicy(
        items.where((e) => e.type != 'meal').toList(),
        maxBreaks: 6,
      );

      if (!policyItems.any((e) => _isStudy(e.type) || e.type == 'revision')) {
        _respondToFunction(callId, 'registerDailyRoutine', {
          'success': false,
          'error': 'Routine has no study/revision blocks. Include due revisions (30 min each, all at the start) if any are due, then study sessions on real topics. Do not send only breaks/question practice/review.',
        }, params: args);
        return;
      }

      // HARD RULE (EXACT MINUTE): window is ALWAYS create-time → 23:30.
      // User says "create at 2 AM" → first block starts 2:00, never 00:00/earlier.
      final createMoment = DateTime.now();
      final dayEnd =
          DateTime(createMoment.year, createMoment.month, createMoment.day, 23, 30);
      final startOfWindow = DateTime(createMoment.year, createMoment.month,
          createMoment.day, createMoment.hour, createMoment.minute);

      DateTime parseStart(String time) {
        final parts = time.split(':');
        final h = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
        final mnt = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
        return DateTime(date.year, date.month, date.day, h, mnt);
      }

      String fmt(DateTime t) =>
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

      // Fixed meal slots (20 min). Included ONLY if still upcoming at create time.
      // 9 PM create → no dinner. 3 AM create → all four meals.
      final mealBlocks = <DailyRoutineItem>[];
      final usedMealLines = <String>{};
      for (final slot in _fixedMealSlots) {
        final mStart =
            DateTime(date.year, date.month, date.day, slot.hour, slot.minute);
        if (mStart.isBefore(startOfWindow)) continue; // already passed
        if (!mStart.isBefore(dayEnd)) continue;
        final tip = RoutineMealTaglines.uniqueForDay(slot.name,
            avoid: usedMealLines);
        usedMealLines.add(tip);
        mealBlocks.add(DailyRoutineItem(
          time: fmt(mStart),
          subject: slot.name,
          topic: '',
          type: 'meal',
          durationMinutes: 20,
          notes: tip,
        ));
      }

      final classes = policyItems
          .where((e) => e.type == 'class')
          .toList()
        ..sort((a, b) => parseStart(a.time).compareTo(parseStart(b.time)));
      final work = policyItems
          .where((e) => e.type != 'class' && e.type != 'freshen_up')
          .toList(); // policy order (freshen_up is auto-inserted below)

      // HARD RULE: today's registered classes MUST appear at their times.
      {
        try {
          // Fetch ALL classes (recurring rows are not on "today" in start_time).
          final crs = await _routineRepo.getClassRoutines();
          final weekday = date.weekday;
          final dayKey =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          for (final cr in crs) {
            final hits = (cr.recurring && cr.recurringDays.contains(weekday)) ||
                cr.dates.any((d) => d.toString().startsWith(dayKey));
            if (!hits) continue;
            final cs = cr.startTime;
            final cStart = DateTime(date.year, date.month, date.day, cs.hour, cs.minute);
            if (!cStart.isAfter(startOfWindow) && !cStart.isAtSameMomentAs(startOfWindow)) {
              // class already started before the window — skip if fully past
              if (cStart.add(Duration(minutes: cr.durationMinutes)).isBefore(startOfWindow)) continue;
            }
            if (!cStart.isBefore(dayEnd)) continue;
            // skip duplicates already in items
            final already = classes.any((e) =>
                e.subject.toLowerCase() == cr.subjectName.toLowerCase() &&
                e.durationMinutes == cr.durationMinutes &&
                e.time == fmt(cStart));
            if (already) continue;
            classes.add(DailyRoutineItem(
              time: fmt(cStart),
              subject: cr.subjectName,
              topic: '',
              type: 'class',
              durationMinutes: cr.durationMinutes,
              notes: cr.locationText,
            ));
          }
          classes.sort((a, b) => parseStart(a.time).compareTo(parseStart(b.time)));
        } catch (e) {
          debugPrint('[Gemini] class inject failed: $e');
        }
      }

      // FRESHEN UP — 30 min at create minute if before 8:00 AM (else omit).
      final freshenBlocks = <DailyRoutineItem>[];
      final eightAm = DateTime(date.year, date.month, date.day, 8, 0);
      if (startOfWindow.isBefore(eightAm)) {
        final limits = <DateTime>[
          eightAm,
          ...mealBlocks.map((e) => parseStart(e.time)),
          ...classes.map((e) => parseStart(e.time)),
        ]..sort();
        final room = limits.first.difference(startOfWindow).inMinutes;
        var fDur = room >= 30 ? 30 : room;
        if (fDur >= 5) {
          freshenBlocks.add(DailyRoutineItem(
            time: fmt(startOfWindow),
            subject: 'Freshen Up',
            topic: '',
            type: 'freshen_up',
            durationMinutes: fDur,
            notes: 'Wash up, brush your teeth, get ready for the day.',
          ));
        }
      }

      // Anchored = fixed-time blocks (freshen + meals + classes), chronological.
      final anchored = <DailyRoutineItem>[
        ...freshenBlocks,
        ...mealBlocks,
        ...classes,
      ]..sort((a, b) => parseStart(a.time).compareTo(parseStart(b.time)));

      final clamped = <DailyRoutineItem>[];
      var cursor = startOfWindow;
      var workIdx = 0;

      void packWorkUntil(DateTime limit) {
        // GAP RULE (prefer study, then recall, then break):
        //  - gap >= 20 min → STUDY session (maximize study; not Active Recall).
        //  - gap  > 10 min → ACTIVE RECALL filling that gap.
        //  - gap <= 10 min → single BREAK (adjacent breaks merge).
        // STUDY RULE: 10-min break after every study — SKIP if the next block
        // is meal / nap / class / freshen (that block covers the break).
        // MERGE RULE: never "Break 10" then "Break 6" — one Break 16.

        bool coversBreak(String t) =>
            t == 'meal' || t == 'nap' || t == 'class' || t == 'freshen_up';

        final studyFallbackSubject = work
                .where((e) =>
                    e.type == 'study' ||
                    e.type == 'first_read' ||
                    e.type == 'revision')
                .map((e) => e.subject)
                .firstWhere((e) => e.isNotEmpty,
                    orElse: () => 'Self Study');
        final studyFallbackTopic = work
                .where((e) =>
                    e.type == 'study' ||
                    e.type == 'first_read' ||
                    e.type == 'revision')
                .map((e) => e.topic)
                .firstWhere((e) => e.isNotEmpty, orElse: () => '');

        void addBlock(DailyRoutineItem it, int minutes) {
          if (minutes <= 0) return;
          clamped.add(DailyRoutineItem(
            time: fmt(cursor),
            subject: it.subject,
            topic: it.topic,
            type: it.type,
            durationMinutes: minutes,
            notes: it.notes,
          ));
          cursor = cursor.add(Duration(minutes: minutes));
        }

        void addBreak(int minutes) {
          if (minutes <= 0) return;
          // MERGE RULE: never stack Break 10 then Break 6 — one Break 16.
          if (clamped.isNotEmpty && clamped.last.type == 'break') {
            final last = clamped.removeLast();
            clamped.add(DailyRoutineItem(
              time: last.time,
              subject: 'Break',
              topic: '',
              type: 'break',
              durationMinutes: last.durationMinutes + minutes,
              notes: last.notes,
            ));
            cursor = cursor.add(Duration(minutes: minutes));
            return;
          }
          clamped.add(DailyRoutineItem(
            time: fmt(cursor),
            subject: 'Break',
            topic: '',
            type: 'break',
            durationMinutes: minutes,
            notes: RoutineBreakTaglines.unique(),
          ));
          cursor = cursor.add(Duration(minutes: minutes));
        }

        void addRecall(int minutes) {
          if (minutes <= 0) return;
          clamped.add(DailyRoutineItem(
            time: fmt(cursor),
            subject: 'Active Recall',
            topic: '',
            type: 'recall',
            durationMinutes: minutes,
            notes: 'Active recall strengthens memory',
          ));
          cursor = cursor.add(Duration(minutes: minutes));
        }

        void addStudy(String subject, String topic, int minutes, String type) {
          if (minutes <= 0) return;
          clamped.add(DailyRoutineItem(
            time: fmt(cursor),
            subject: subject,
            topic: topic,
            type: type,
            durationMinutes: minutes,
            notes: null,
          ));
          cursor = cursor.add(Duration(minutes: minutes));
        }

        /// True when the next fixed block (meal/nap/class/freshen) covers the
        /// break — NEVER place a Break right before Breakfast/Lunch/Snack/Dinner.
        bool nextFixedCoversBreak() {
          for (final b in anchored) {
            final st = parseStart(b.time);
            if (st.isAfter(cursor) || st.isAtSameMomentAs(cursor)) {
              return coversBreak(b.type);
            }
          }
          return false;
        }

        /// Gap fill: >= 20 → STUDY; > 10 → Active Recall; ≤ 10 → Break.
        /// Never a Break when a meal/class is next (it already covers the break).
        void fillGapMinutes(int gapMin) {
          if (gapMin <= 0) return;
          if (gapMin >= 20) {
            addStudy(studyFallbackSubject, studyFallbackTopic, gapMin, 'study');
          } else if (gapMin > 10) {
            addRecall(gapMin);
          } else if (!nextFixedCoversBreak()) {
            addBreak(gapMin);
          }
          // else: leave the short gap open — meal/class is about to start.
        }

        bool isStudyType(String t) => t == 'study' || t == 'first_read';

        void maybeBreakAfterStudy() {
          // 10-min break after EVERY study. Skip if the next block is
          // meal/nap/class/freshen (Breakfast/Lunch/Snack/Dinner covers the break).
          if (nextFixedCoversBreak()) return;
          if (workIdx < work.length) {
            if (coversBreak(work[workIdx].type)) return;
            addBreak(10);
            return;
          }
          final toEnd = dayEnd.difference(cursor).inMinutes;
          if (toEnd >= 10) {
            addBreak(10);
          } else if (toEnd > 0) {
            addBreak(toEnd);
          }
        }

        // 1) Queued work — study is NEVER split into tiny slices.
        while (workIdx < work.length) {
          final it = work[workIdx];
          final remaining = it.durationMinutes;
          if (remaining <= 0) {
            workIdx++;
            continue;
          }
          // Queued Breaks are policy noise — packing inserts breaks itself
          // (and skips them when meal/nap/class/freshen covers the break).
          if (it.type == 'break') {
            workIdx++;
            continue;
          }
          final gapMin = limit.difference(cursor).inMinutes;
          if (gapMin <= 0) break;

          if (isStudyType(it.type)) {
            // Only place a study when it fits the gap; otherwise fill per rules.
            if (remaining > gapMin) {
              fillGapMinutes(gapMin);
              break;
            }
            addStudy(it.subject, it.topic, remaining, it.type);
            workIdx++;
            // Mandatory 10-min break after this study — skipped when
            // meal/nap/class/freshen is next (covers the break).
            maybeBreakAfterStudy();
            continue;
          }

          if (remaining <= gapMin) {
            addBlock(it, remaining);
            workIdx++;
          } else {
            fillGapMinutes(gapMin);
            break;
          }
        }

        // 2) Empty gap (no queued work) — prefer STUDY over recall/break.
        while (cursor.isBefore(limit) && cursor.isBefore(dayEnd)) {
          final room = limit.difference(cursor).inMinutes;
          if (room <= 0) break;
          if (room >= 50) {
            addStudy(studyFallbackSubject, studyFallbackTopic, 50, 'study');
            if (!cursor.isBefore(dayEnd)) break;
            maybeBreakAfterStudy();
            if (!cursor.isBefore(limit) || !cursor.isBefore(dayEnd)) break;
          } else if (room >= 20) {
            // Not enough for 50, but >= 20 → still a study session (maximize study).
            addStudy(studyFallbackSubject, studyFallbackTopic, room, 'study');
            break;
          } else if (room > 10) {
            addRecall(room);
            break;
          } else if (!nextFixedCoversBreak()) {
            addBreak(room);
            break;
          } else {
            break; // meal/class is next — no Break before it.
          }
        }
      }

      for (final block in anchored) {
        if (!cursor.isBefore(dayEnd)) break;
        final aStart = parseStart(block.time);
        // Fill free time before this fixed block.
        if (aStart.isAfter(cursor)) {
          packWorkUntil(aStart);
        }
        // Place fixed block at its locked start (or cursor if we somehow passed it).
        var start = aStart.isBefore(cursor) ? cursor : aStart;
        if (!start.isBefore(startOfWindow) && start.isBefore(dayEnd)) {
          final maxMin = dayEnd.difference(start).inMinutes;
          final duration = block.durationMinutes.clamp(1, maxMin);
          clamped.add(DailyRoutineItem(
            time: fmt(start),
            subject: block.subject,
            topic: block.topic,
            type: block.type,
            durationMinutes: duration,
            notes: block.notes,
          ));
          cursor = start.add(Duration(minutes: duration));
        }
      }
      // Remaining work after last fixed block → 11:30 PM.
      packWorkUntil(dayEnd);

      // HARD END RULE: the day ALWAYS finishes at exactly 11:30 PM (23:30).
      // Never earlier. Extend the last block so its end time is 23:30.
      if (clamped.isNotEmpty && cursor.isBefore(dayEnd)) {
        final extra = dayEnd.difference(cursor).inMinutes;
        if (extra > 0) {
          final i = clamped.length - 1;
          final last = clamped[i];
          clamped[i] = DailyRoutineItem(
            time: last.time,
            subject: last.subject,
            topic: last.topic,
            type: last.type,
            durationMinutes: last.durationMinutes + extra,
            notes: last.notes,
          );
          cursor = dayEnd;
        }
      }

      if (clamped.isEmpty) {
        _respondToFunction(callId, 'registerDailyRoutine', {
          'success': false,
          'error': 'All blocks fall outside the day. Routine must run from the current time until exactly 11:30 PM.',
        }, params: args);
        return;
      }

      // HARD GUARANTEE: never two study blocks back-to-back.
      // Insert Break 10 between them and push the next study to after the break.
      for (var i = 0; i < clamped.length - 1; i++) {
        final a = clamped[i];
        final b = clamped[i + 1];
        final aStudy = a.type == 'study' || a.type == 'first_read';
        final bStudy = b.type == 'study' || b.type == 'first_read';
        if (!(aStudy && bStudy)) continue;
        final aStart = parseStart(a.time);
        final aEnd = aStart.add(Duration(minutes: a.durationMinutes));
        final brkEnd = aEnd.add(const Duration(minutes: 10));
        clamped.insert(
          i + 1,
          DailyRoutineItem(
            time: fmt(aEnd),
            subject: 'Break',
            topic: '',
            type: 'break',
            durationMinutes: 10,
            notes: RoutineBreakTaglines.unique(),
          ),
        );
        // Delay the second study (and any flexible block after it) past the break.
        for (var j = i + 2; j < clamped.length; j++) {
          final t = clamped[j].type;
          if (t == 'meal' || t == 'class' || t == 'freshen_up') break;
          final st = parseStart(clamped[j].time);
          if (st.isBefore(brkEnd)) {
            final it = clamped[j];
            clamped[j] = DailyRoutineItem(
              time: fmt(brkEnd),
              subject: it.subject,
              topic: it.topic,
              type: it.type,
              durationMinutes: it.durationMinutes,
              notes: it.notes,
            );
          }
          if (t == 'study' || t == 'first_read') break;
        }
        i++; // skip inserted break
      }

      // HARD STRIP: never a Break immediately before meal/nap/class/freshen.
      // Those blocks already cover the rest — fold any stray break into the
      // previous study (or drop it).
      for (var i = clamped.length - 2; i >= 0; i--) {
        if (clamped[i].type != 'break') continue;
        final next = clamped[i + 1];
        final nextCovers = next.type == 'meal' ||
            next.type == 'nap' ||
            next.type == 'class' ||
            next.type == 'freshen_up';
        if (!nextCovers) continue;
        final brk = clamped.removeAt(i);
        if (i > 0 &&
            (clamped[i - 1].type == 'study' ||
                clamped[i - 1].type == 'first_read')) {
          final prev = clamped[i - 1];
          clamped[i - 1] = DailyRoutineItem(
            time: prev.time,
            subject: prev.subject,
            topic: prev.topic,
            type: prev.type,
            durationMinutes: prev.durationMinutes + brk.durationMinutes,
            notes: prev.notes,
          );
        }
      }

      final routine = await _routineRepo.createDailyRoutine(
        date: date,
        items: clamped,
      );

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
        'starts_at': fmt(startOfWindow),
        'ends_at': '11:30 PM',
        'meals_included': mealBlocks.map((e) => e.subject).toList(),
        'language_rule': 'Reply in EXACTLY ONE language — the user\'s last language.',
        'reply_style': 'CONFIRM_WITH_FEEDBACK',
        'message': 'Daily routine saved (${clamped.length} blocks) until 11:30 PM.',
        'reply_rule': 'YOU MUST give feedback in the user\'s language. '
            'Say the routine is ready and the block count (e.g. "Done — your routine is ready, ${clamped.length} blocks until 11:30 PM"). '
            'Do NOT stay silent. Do NOT dump every time slot. One clear confirmation sentence.',
      }, params: args);

      // Schedule a local notification for every future block right away.
      try {
        final n = await NotificationService.to.scheduleDailyRoutine(routine: routine);
        debugPrint('[Gemini] scheduled $n daily-routine notifications for ${routine.id}');
      } catch (e) {
        debugPrint('[Gemini] ⚠️ Failed to schedule daily routine notifications: $e');
      }

      // Force refresh so RoutineController / Dashboard pick it up immediately.
      _summaryCache = null;
      _summaryCachedAt = null;
      refreshDailyRoutines();
      unawaited(Future<void>.delayed(const Duration(milliseconds: 350), () {
        refreshDailyRoutines();
      }));
    } catch (e) {
      Get.snackbar('Error', 'Daily routine save failed: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 5));
      _respondToFunction(callId, 'registerDailyRoutine', {
        'success': false, 'error': e.toString(),
        'language_rule': 'Tell the user save failed in EXACTLY ONE language (theirs). Do not mix languages. Do not loop.',
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
        // User rule: every meal is exactly 20 minutes.
        return 20;
      case 'freshen_up':
        return 30;
      case 'class':
        return sent <= 0 ? 60 : sent;
      // review/quick review are forbidden — duration irrelevant (dropped later).
      case 'review':
        return 50;
      default:
        return (sent <= 0 ? 30 : sent).clamp(5, 90);
    }
  }

  /// Locked meal windows — not model-invented.
  static const _fixedMealSlots = <({String name, int hour, int minute, String notes})>[
    (name: 'Breakfast', hour: 8, minute: 0, notes: '8:00–8:20 AM'),
    (name: 'Lunch', hour: 13, minute: 30, notes: '1:30–1:50 PM'),
    (name: 'Snack', hour: 17, minute: 0, notes: '5:00–5:20 PM'),
    (name: 'Dinner', hour: 20, minute: 0, notes: '8:00–8:20 PM'),
  ];

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

    // Unique break copy — never the same tagline twice in one day plan.
    final breakLines = RoutineBreakTaglines.uniqueBatch(8);
    var breakIdx = 0;

    for (var i = 0; i < body.length; i++) {
      final it = body[i];
      out.add(it);
      final isStudy = it.type == 'study' || it.type == 'first_read';
      if (!isStudy) continue;
      final next = i + 1 < body.length ? body[i + 1] : null;
      if (next == null) continue; // end of day — no trailing break
      // Meal / nap / class already rest the student → skip break.
      // Meal / nap / class / freshen cover the break — no extra Break block.
      if (next.type == 'meal' ||
          next.type == 'nap' ||
          next.type == 'class' ||
          next.type == 'freshen_up') {
        continue;
      }
      out.add(DailyRoutineItem(
        time: it.time,
        subject: 'Break',
        topic: '',
        type: 'break',
        durationMinutes: 10,
        notes: breakLines[breakIdx % breakLines.length],
      ));
      breakIdx++;
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
    final dateLabel = date.toIso8601String().substring(0, 10);

    try {
      // Bust caches FIRST so a create/delete in the same turn never sees stale data.
      _summaryCache = null;
      _recentCalls.removeWhere((h) => h.contains('deleteDailyRoutine') || h.contains('getAllData'));

      final deletedCount = await _routineRepo.deleteDailyRoutinesByDate(date);

      // Force UI refresh (routine tab + dashboard live card).
      refreshDailyRoutines();
      refreshClassRoutines();
      unawaited(Future<void>.delayed(const Duration(milliseconds: 350), () {
        refreshDailyRoutines();
      }));

      if (deletedCount == 0) {
        Get.snackbar('Not Found', 'No daily routine for $dateLabel',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange.shade700,
            colorText: Colors.white,
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 3));
        messages.add(ChatMessage(
          role: ChatRole.system,
          text: 'ℹ️ No daily routine found for $dateLabel — nothing to delete. You can create a new one now.',
        ));
        _triggerUiUpdate();
        _respondToFunction(callId, 'deleteDailyRoutine', {
          'success': false,
          'error': 'No daily routine found for $dateLabel.',
          'ui_refreshed': true,
          'language_rule': 'EXPLAIN in ONE language only (the user\'s last language) that there was no routine to delete. If they want a new one → getAllData then build — no Thinking loop, no second language.',
        }, params: args);
        return;
      }

      Get.snackbar('Deleted', 'Daily routine removed for $dateLabel ($deletedCount blocks)',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green.shade700,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 3));

      // Visible chat feedback even if the model is slow to speak.
      messages.add(ChatMessage(
        role: ChatRole.system,
        text: '🗑️ Daily routine deleted for $dateLabel ($deletedCount blocks).',
      ));
      _triggerUiUpdate();

      _respondToFunction(callId, 'deleteDailyRoutine', {
        'success': true,
        'deleted_count': deletedCount,
        'date': dateLabel,
        'ui_refreshed': true,
        'message': 'Deleted daily routine for $dateLabel ($deletedCount blocks).',
        'language_rule': 'Confirm deletion in EXACTLY ONE language (the user\'s last language) — short. No bilingual reply. If they already asked to create a new routine → getAllData (fresh) → registerDailyRoutine. Never re-delete. Never stall on Thinking.',
        'next_step': 'If user wants a new routine: getAllData → if they named subject/topic use only those → registerDailyRoutine ending at 23:30. Do not ask the same question twice in one turn.',
      }, params: args);
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete daily routine: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade700,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 5));
      messages.add(ChatMessage(
        role: ChatRole.system,
        text: '⚠️ Could not delete the daily routine. Please try again.',
      ));
      _triggerUiUpdate();
      _respondToFunction(callId, 'deleteDailyRoutine', {
        'success': false,
        'error': e.toString(),
        'language_rule': 'Tell the user delete failed in ONE language only (theirs). Do not mix. Do not loop.',
      }, params: args);
    }
  }
}

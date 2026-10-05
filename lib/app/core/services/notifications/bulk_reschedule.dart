part of '../notification_service.dart';

/// Bulk reschedule + immediate due-now alerts.
extension NotificationBulkReschedule on NotificationService {
  /// Rebuild all alarms from the DB.
  /// [force] skips the long debounce when the user just changed data
  /// (complete revision, create class/daily routine, first-read).
  Future<void> rescheduleAll({bool force = false}) async {
    if (!_notificationsEnabled) return;
    if (kIsWeb) {
      await _rescheduleWebBlocks(force: force);
      return;
    }
    if (_rescheduleRunning) return;
    final now = DateTime.now();
    if (!force &&
        _lastReschedule != null &&
        now.difference(_lastReschedule!).inSeconds < 30) {
      return;
    }
    _lastReschedule = now;
    _rescheduleRunning = true;

    try {
      await _plugin.cancelAll();
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      final userId = user.id;
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final farFuture = todayStart.add(const Duration(days: 90));

      final results = await Future.wait([
        _fetchPendingRevisions(client, userId, todayStart, farFuture),
        _fetchActiveClassRoutines(client, userId),
        _fetchActiveDailyRoutines(client, userId, todayStart),
      ]);

      final schedules = results[0] as List<RevisionScheduleModel>;
      final classRoutines = results[1] as List<ClassRoutineModel>;
      final dailyRoutines = results[2] as List<DailyRoutineModel>;

      final topicIds = schedules.map((s) => s.topicId).toSet();
      final subjectIds = schedules.map((s) => s.subjectId).toSet();
      final names = await Future.wait([
        _fetchNames(client, 'topics', topicIds),
        _fetchNames(client, 'subjects', subjectIds),
      ]);
      final topicNames = names[0];
      final subjectNames = names[1];

      debugPrint(
          '[NotificationService] rescheduleAll force=$force: ${schedules.length} revisions, '
          '${classRoutines.length} classes, ${dailyRoutines.length} daily routines');

      for (final schedule in schedules) {
        try {
          await scheduleRevision(
            schedule: schedule,
            topicName: topicNames[schedule.topicId] ?? 'Topic',
            subjectName: subjectNames[schedule.subjectId] ?? 'Subject',
          );
        } catch (_) {}
      }

      for (final routine in classRoutines) {
        try {
          await scheduleClassRoutine(routine: routine, daysAhead: 14);
        } catch (_) {}
      }

      for (final routine in dailyRoutines) {
        try {
          final n = await scheduleDailyRoutine(routine: routine, daysAhead: 2);
          debugPrint('[NotificationService] daily ${routine.id}: $n alarms');
        } catch (e) {
          debugPrint('[NotificationService] daily schedule failed: $e');
        }
      }

      // Fire anything that is already due right now.
      await _notifyDueNow(
        schedules: schedules,
        topicNames: topicNames,
        subjectNames: subjectNames,
        classRoutines: classRoutines,
        dailyRoutines: dailyRoutines,
      );
    } catch (e, stack) {
      debugPrint('[NotificationService] rescheduleAll error: $e');
      debugPrint('[NotificationService] stack: $stack');
    } finally {
      _rescheduleRunning = false;
      try {
        final pending = await getPending();
        debugPrint('[NotificationService] pending alarms: ${pending.length}');
      } catch (_) {}
    }
  }

  /// Show an immediate notification for anything due now so the user
  /// doesn't wait for the next scheduled alarm tick.
  Future<void> _notifyDueNow({
    required List<RevisionScheduleModel> schedules,
    required Map<String, String> topicNames,
    required Map<String, String> subjectNames,
    required List<ClassRoutineModel> classRoutines,
    required List<DailyRoutineModel> dailyRoutines,
  }) async {
    if (!_notificationsEnabled) return;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrow = todayStart.add(const Duration(days: 1));

    Future<void> show(int id, String title, String body, String channel, String chName) async {
      try {
        await _plugin.show(
          id,
          title,
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel,
              chName,
              channelDescription: chName,
              importance: Importance.max,
              priority: Priority.max,
              icon: 'ic_stat_notif',
              color: const Color(0xFF87CEEB),
              fullScreenIntent: true,
              category: AndroidNotificationCategory.alarm,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
      } catch (e) {
        debugPrint('[NotificationService] show due-now failed: $e');
      }
    }

    // Revisions due today or overdue.
    for (final s in schedules) {
      final day = DateTime(s.scheduledDate.year, s.scheduledDate.month, s.scheduledDate.day);
      final dueToday = !day.isBefore(todayStart) && day.isBefore(tomorrow);
      final overdue = day.isBefore(todayStart);
      if (!dueToday && !overdue) continue;
      final topic = topicNames[s.topicId] ?? 'Topic';
      final subject = subjectNames[s.subjectId] ?? 'Subject';
      await show(
        910000 + (s.id.hashCode & 0x7FFF),
        overdue ? '📚 Overdue revision: $subject' : '📚 Revision due today: $subject',
        'Day ${s.dayNumber} — $topic',
        NotificationService._channelRevision,
        NotificationService._channelRevisionName,
      );
      break; // one summary notification is enough
    }

    // Class happening now.
    for (final cr in classRoutines) {
      final isToday = ClassDayMatcher.matchesDay(
        dates: cr.dates,
        recurringDays: cr.recurringDays,
        day: now,
      );
      if (!isToday) continue;
      final start = DateTime(now.year, now.month, now.day, cr.startTime.hour, cr.startTime.minute);
      final end = start.add(Duration(minutes: cr.durationMinutes));
      if (!now.isBefore(start) && now.isBefore(end)) {
        await show(
          920000 + (cr.id.hashCode & 0x7FFF),
          '🏫 Class in progress',
          '${cr.subjectName} — ${cr.timeText}',
          NotificationService._channelClass,
          NotificationService._channelClassName,
        );
        break;
      }
    }

    // Daily block happening now.
    for (final dr in dailyRoutines) {
      final sameDay = isSameCalendarDay(dr.date, now);
      if (!sameDay) continue;
      for (final item in dr.items) {
        final hm = parseClock(item.time);
        if (hm == null) continue;
        final start = DateTime(now.year, now.month, now.day, hm[0], hm[1]);
        final end = start.add(Duration(minutes: item.durationMinutes));
        if (!now.isBefore(start) && now.isBefore(end)) {
          await show(
            930000 + (item.time.hashCode & 0x7FFF),
            '📋 Block started',
            '${item.subject.isNotEmpty ? item.subject : item.type} — ${item.durationMinutes} min',
            NotificationService._channelDaily,
            NotificationService._channelDailyName,
          );
          break;
        }
      }
    }
  }

  Future<void> cancelAll() async {
    if (kIsWeb) {
      if (Get.isRegistered<WebPushService>()) {
        WebPushService.to.resetTimers();
      }
      return;
    }
    await _plugin.cancelAll();
  }

  // ── Web path ───────────────────────────────────────────────────────────

  /// Rebuild the in-tab timers for every daily-routine block in the next
  /// 7 days. Closed-tab delivery is handled entirely by the server cron +
  /// `send-web-push` edge function, so this only arms local timers.
  Future<void> _rescheduleWebBlocks({required bool force}) async {
    if (!Get.isRegistered<WebPushService>()) return;
    final now = DateTime.now();
    if (!force &&
        _lastReschedule != null &&
        now.difference(_lastReschedule!).inSeconds < 30) {
      return;
    }
    _lastReschedule = now;

    final service = WebPushService.to;
    await service.ensureReady();
    service.resetTimers();

    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final routines =
          await _fetchActiveDailyRoutines(client, user.id, todayStart);

      int total = 0;
      for (final routine in routines) {
        try {
          final d = routine.date;
          total += service.scheduleDailyRoutineBlocks(
            routineId: routine.id,
            date: DateTime(d.year, d.month, d.day),
            items: routine.items
                .map((e) => {
                      'time': e.time,
                      'subject': e.subject,
                      'topic': e.topic,
                      'type': e.type,
                      'duration_minutes': e.durationMinutes,
                    })
                .toList(),
            cancelExisting: false,
          );
        } catch (e) {
          debugPrint('[NotificationService] web routine ${routine.id} failed: $e');
        }
      }

      debugPrint('[NotificationService] web reschedule force=$force: '
          '${routines.length} routines, $total timers armed');

      await _showWebCatchUp(routines, todayStart);
    } catch (e) {
      debugPrint('[NotificationService] web reschedule error: $e');
    }
  }

  /// A block that started while the tab was closed should still surface
  /// once the app loads (within a 10-minute grace window).
  Future<void> _showWebCatchUp(
    List<DailyRoutineModel> routines,
    DateTime todayStart,
  ) async {
    if (!Get.isRegistered<WebPushService>()) return;
    final service = WebPushService.to;
    final now = DateTime.now();
    final dayKey = todayStart.toIso8601String().substring(0, 10);

    for (final routine in routines) {
      final d = routine.date;
      if (!isSameCalendarDay(DateTime(d.year, d.month, d.day), todayStart)) {
        continue;
      }
      for (var i = 0; i < routine.items.length; i++) {
        final item = routine.items[i];
        final hm = parseClock(item.time);
        if (hm == null) continue;
        final start =
            DateTime(todayStart.year, todayStart.month, todayStart.day, hm[0], hm[1]);
        final late = now.difference(start);
        if (late.isNegative || late.inMinutes > 10) continue;
        final key = '${routine.id}:$dayKey:$i';
        if (!_shownCatchUpKeys.add(key)) continue;
        final label = item.subject.isNotEmpty
            ? item.subject
            : (item.type.isNotEmpty ? item.type : 'Study');
        final topic = item.topic.isEmpty ? '' : ': ${item.topic}';
        service.showNow(
          '📋 $label$topic',
          'Started ${late.inMinutes} min ago — ${item.durationMinutes} min block',
          tag: key,
        );
      }
    }
  }
}

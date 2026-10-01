part of '../notification_service.dart';

/// Daily-routine block reminders.
extension NotificationDailySchedule on NotificationService {

  /// Parse "9:00", "09:30", "9:00 AM", "9 AM", "14:00:00" into [hour, minute].
  /// Returns null if the string cannot be understood.
  Future<int> scheduleDailyRoutine({
    required DailyRoutineModel routine,
    int daysAhead = 7,
  }) async {
    if (!_notificationsEnabled) {
      debugPrint('[NotificationService] scheduleDailyRoutine skipped (disabled)');
      return 0;
    }

    final now = tz.TZDateTime.now(tz.local);
    // Normalize the routine's calendar day in LOCAL time (date-only DB
    // strings parse as UTC midnight and would shift the day).
    final rawDate = routine.date;
    final baseDate = DateTime(rawDate.year, rawDate.month, rawDate.day);

    if (kIsWeb) {
      try {
        if (Get.isRegistered<WebPushService>()) {
          final n = WebPushService.to.scheduleDailyRoutineBlocks(
            routineId: routine.id,
            date: baseDate,
            items: routine.items
                .map((e) => {
                      'time': e.time,
                      'subject': e.subject,
                      'topic': e.topic,
                      'type': e.type,
                      'duration_minutes': e.durationMinutes,
                    })
                .toList(),
          );
          debugPrint('[WebPush] scheduled $n local block reminders');
          return n;
        }
      } catch (e) {
        debugPrint('[WebPush] schedule failed: $e');
      }
      return 0;
    }

    int scheduled = 0;
    for (int d = 0; d < daysAhead; d++) {
      final day = baseDate.add(Duration(days: d));

      for (int i = 0; i < routine.items.length; i++) {
        final item = routine.items[i];
        final hm = parseClock(item.time);
        if (hm == null) {
          debugPrint('[NotificationService] skip block #$i bad time="${item.time}"');
          continue;
        }
        final h = hm[0];
        final m = hm[1];

        final blockStart = tz.TZDateTime(tz.local, day.year, day.month, day.day, h, m);
        if (!blockStart.isAfter(now)) continue;

        final id = _dailyNotifId(routine.id, i, day);
        final label = item.subject.isNotEmpty ? item.subject : (item.type.isNotEmpty ? item.type : 'Study');
        final topicPart = item.topic.isNotEmpty ? ': ${item.topic}' : '';
        final payload = 'study-revision-tracker://routine/${routine.id}';

        try {
          await _plugin.zonedSchedule(
            id,
            '📋 $label$topicPart',
            '${formatTime12(h, m)} — ${item.durationMinutes} min block',
            blockStart,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                NotificationService._channelDaily,
                NotificationService._channelDailyName,
                channelDescription: 'Reminders when each daily routine block starts',
                importance: Importance.high,
                priority: Priority.high,
                icon: 'ic_stat_notif',
          largeIcon: const DrawableResourceAndroidBitmap('ic_launcher_large'),
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
                    color: const Color(0xFF87CEEB),
                playSound: true,
                enableVibration: true,
                visibility: NotificationVisibility.public,
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: payload,
          );
          scheduled++;
        } catch (e) {
          debugPrint('[NotificationService] schedule failed: $e');
        }
      }
    }
    debugPrint('[NotificationService] scheduleDailyRoutine done id=${routine.id} '
        'items=${routine.items.length} scheduled=$scheduled now=$now');
    return scheduled;
  }

  Future<void> cancelDailyRoutine(String routineId, {int daysAhead = 30}) async {
    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);
    for (int d = 0; d < daysAhead; d++) {
      final date = today.add(Duration(days: d));
      for (int i = 0; i < 20; i++) {
        await _plugin.cancel(_dailyNotifId(routineId, i, date));
      }
    }
  }
}

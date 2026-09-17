part of '../notification_service.dart';

/// Class-reminder scheduling (30 min before).
extension NotificationClassSchedule on NotificationService {

  /// Schedule class reminders for the next [daysAhead] days.
  /// Each class gets a notification 30 minutes before its start time.
  Future<void> scheduleClassRoutine({
    required ClassRoutineModel routine,
    int daysAhead = 14,
  }) async {
    if (!_notificationsEnabled) return;

    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);

    for (int d = 0; d < daysAhead; d++) {
      final date = today.add(Duration(days: d));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final isToday = routine.dates.any((d) =>
              d == dateStr || d.startsWith(dateStr)) ||
          routine.recurringDays.contains(date.weekday);
      if (!isToday) continue;

      final classStart = tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day,
        routine.startTime.hour,
        routine.startTime.minute,
      );
      var reminderTime = classStart.subtract(const Duration(minutes: 30));

      // If the 30-min-before slot already passed but class hasn't started,
      // fire immediately so the user still gets a heads-up.
      if (!reminderTime.isAfter(now)) {
        if (classStart.isAfter(now)) {
          reminderTime = now.add(const Duration(seconds: 30));
        } else {
          continue;
        }
      }

      final id = _classNotifId(routine.id, date);
      final locationPart = routine.locationText.isNotEmpty
          ? ' at ${routine.locationText}'
          : '';
      final payload = 'study-revision-tracker://class/${routine.id}';

      await _plugin.zonedSchedule(
        id,
        '🏫 Class soon: ${routine.subjectName}',
        '${routine.timeText}$locationPart — ${routine.durationText} class',
        reminderTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            NotificationService._channelClass,
            NotificationService._channelClassName,
            channelDescription: 'Reminders 30 minutes before class',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_notif',
          largeIcon: const DrawableResourceAndroidBitmap('ic_launcher_large'),
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
                    color: const Color(0xFF87CEEB),
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
    }
  }

  Future<void> cancelClassRoutine(String routineId, {int daysAhead = 30}) async {
    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);
    for (int d = 0; d < daysAhead; d++) {
      final date = today.add(Duration(days: d));
      await _plugin.cancel(_classNotifId(routineId, date));
    }
  }
}

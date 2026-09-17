part of '../notification_service.dart';

/// Revision reminder scheduling.
extension NotificationRevisionSchedule on NotificationService {

  /// Schedule a single revision reminder at [schedule.scheduledDate], 08:00
  /// device-local time. If that slot already passed today, fire soon (now+1min)
  /// so overdue revisions still notify instead of waiting until tomorrow.
  Future<void> scheduleRevision({
    required RevisionScheduleModel schedule,
    required String topicName,
    required String subjectName,
  }) async {
    if (!_notificationsEnabled) return;
    if (schedule.status != 'pending') return;

    final now = tz.TZDateTime.now(tz.local);
    final scheduledDay = schedule.scheduledDate;

    // 08:00 local on the scheduled calendar day.
    var scheduled = tz.TZDateTime(
      tz.local,
      scheduledDay.year,
      scheduledDay.month,
      scheduledDay.day,
      8,
      0,
    );

    // If today's 08:00 already passed but the revision is still due today,
    // notify within the next minute instead of skipping to tomorrow.
    if (!scheduled.isAfter(now)) {
      final isSameDay = scheduledDay.year == now.year &&
          scheduledDay.month == now.month &&
          scheduledDay.day == now.day;
      final isOverdueDay = scheduledDay.isBefore(DateTime(now.year, now.month, now.day));
      if (isSameDay || isOverdueDay) {
        scheduled = now.add(const Duration(minutes: 1));
      } else {
        // Future day whose 08:00 hasn't come yet — already handled above.
        // If we get here the date is in the past beyond "today", skip.
        return;
      }
    }

    if (!scheduled.isAfter(now)) return;

    final id = _revisionNotifId(schedule.id);
    final payload = 'study-revision-tracker://revision/${schedule.id}';

    await _plugin.zonedSchedule(
      id,
      '📚 Revision: $subjectName',
      'Day ${schedule.dayNumber} — $topicName is due',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationService._channelRevision,
          NotificationService._channelRevisionName,
          channelDescription: 'Reminders for scheduled revisions',
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

  Future<void> cancelRevision(String scheduleId) async {
    await _plugin.cancel(_revisionNotifId(scheduleId));
  }
}

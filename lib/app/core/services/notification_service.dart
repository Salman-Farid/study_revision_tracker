import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService extends GetxService {
  final _plugin = FlutterLocalNotificationsPlugin();

  Future<NotificationService> init() async {
    tz_data.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true);
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
    return this;
  }

  Future<void> scheduleRevision({
    required int id, required String topicName, required String subjectName,
    required DateTime scheduledDate, required int dayNumber,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) return;
    final tzDt = tz.TZDateTime.from(scheduledDate, tz.local);
    const details = NotificationDetails(
      android: AndroidNotificationDetails('revision_channel', 'Revision Reminders',
        channelDescription: 'Reminders for scheduled revisions',
        importance: Importance.high, priority: Priority.high));
    await _plugin.zonedSchedule(id, 'Revision: $subjectName',
      'Day $dayNumber revision for "$topicName" is due!', tzDt, details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}

part of '../notification_service.dart';

/// Exact-alarm permission + pending list.
extension NotificationExactAlarm on NotificationService {

  Future<bool> requestExactAlarmPermission() async {
    if (kIsWeb) return false;
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true;
    final allowed = await androidPlugin.areNotificationsEnabled() ?? false;
    if (!allowed) {
      await androidPlugin.requestNotificationsPermission();
    }
    try {
      final granted = await androidPlugin.requestExactAlarmsPermission();
      return granted ?? false;
    } catch (_) {
      return true;
    }
  }

  Future<List<PendingNotificationRequest>> getPending() async {
    return await _plugin.pendingNotificationRequests();
  }
}

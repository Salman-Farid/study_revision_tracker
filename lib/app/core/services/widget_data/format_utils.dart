part of '../widget_data_service.dart';

/// Time formatting and periodic widget refresh helpers.
String _formatTime12(int hour, int minute) {
  final period = hour >= 12 ? 'PM' : 'AM';
  var h = hour;
  if (h == 0) {
    h = 12;
  } else if (h > 12) {
    h -= 12;
  }
  return '$h:${minute.toString().padLeft(2, '0')} $period';
}

/// Schedule periodic widget updates via AlarmManager.
Future<void> schedulePeriodicUpdate() async {
  if (kIsWeb) return;
  try {
    await HomeWidget.registerInteractivityCallback(backgroundCallback);
  } catch (_) {}
}

/// Save the App Group ID for iOS widget data sharing.
Future<void> setAppGroupId(String groupId) async {
  if (kIsWeb) return;
  try {
    await HomeWidget.setAppGroupId(groupId);
  } catch (e) {
    debugPrint('[WidgetData] setAppGroupId failed: $e');
  }
}

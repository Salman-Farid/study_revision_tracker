part of '../widget_data_service.dart';

/// Time formatting — delegates to domain `formatHm12`.
String _formatTime12(int hour, int minute) => formatHm12(hour, minute);

/// Schedule periodic widget updates via AlarmManager.
Future<void> _schedulePeriodicUpdate() async {
  if (kIsWeb) return;
  try {
    await HomeWidget.registerInteractivityCallback(backgroundCallback);
  } catch (_) {}
}

/// Save the App Group ID for iOS widget data sharing.
Future<void> _setAppGroupId(String groupId) async {
  if (kIsWeb) return;
  try {
    await HomeWidget.setAppGroupId(groupId);
  } catch (e) {
    debugPrint('[WidgetData] setAppGroupId failed: $e');
  }
}

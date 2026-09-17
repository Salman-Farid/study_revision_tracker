part of '../widget_data_service.dart';

/// Persist widget payloads into HomeWidgetPreferences.
Future<void> _saveDailyWidgetData(
  Map<String, dynamic> data,
) async {
  final hasData = data['hasData'] as bool? ?? false;
  final statusMessage = data['statusMessage'] as String? ?? '';
  await HomeWidget.saveWidgetData<String>(_kDailyHasData, hasData.toString());
  await HomeWidget.saveWidgetData<String>(
    _kDailyStatusMessage,
    statusMessage.isEmpty ? _kDailyEmptyMessage : statusMessage,
  );
  await HomeWidget.saveWidgetData<String>(_kDailyCurrentSubject, data['currentSubject'] as String? ?? '');
  await HomeWidget.saveWidgetData<String>(_kDailyCurrentTopic, data['currentTopic'] as String? ?? '');
  await HomeWidget.saveWidgetData<String>(_kDailyCurrentType, data['currentType'] as String? ?? '');
  await HomeWidget.saveWidgetData<String>(_kDailyCurrentTime, data['currentTime'] as String? ?? '');
  await HomeWidget.saveWidgetData<String>(_kDailyRemaining, data['remaining'] as String? ?? '');
  await HomeWidget.saveWidgetData<String>(_kDailyCurrentEndTimestamp, (data['currentEndTimestamp'] as int? ?? 0).toString());
  await HomeWidget.saveWidgetData<String>(_kDailyNextSubject, data['nextSubject'] as String? ?? '');
  await HomeWidget.saveWidgetData<String>(_kDailyNextTime, data['nextTime'] as String? ?? '');
  // Always write valid JSON arrays so the native list never sees null/"null".
  await HomeWidget.saveWidgetData<String>(
    _kDailyUpcomingItems,
    jsonEncode(data['upcomingItems'] as List? ?? const []),
  );
  await HomeWidget.saveWidgetData<String>(
    _kDailyAllItems,
    jsonEncode(data['allItems'] as List? ?? const []),
  );
}

Future<void> _saveRevisionWidgetData(
  Map<String, dynamic> data,
) async {
  List safeList(Object? value) =>
      value is List ? value : const <dynamic>[];
  await HomeWidget.saveWidgetData<String>(_kRevisionHasData, (data['hasData'] as bool? ?? false).toString());
  await HomeWidget.saveWidgetData<String>(_kRevisionStatusMessage, data['statusMessage'] as String? ?? 'Nothing planned yet');
  await HomeWidget.saveWidgetData<String>(_kRevisionOverdueCount, (data['overdueCount'] as int? ?? 0).toString());
  await HomeWidget.saveWidgetData<String>(_kRevisionTodayCount, (data['todayCount'] as int? ?? 0).toString());
  await HomeWidget.saveWidgetData<String>(_kRevisionUpcomingCount, (data['upcomingCount'] as int? ?? 0).toString());
  await HomeWidget.saveWidgetData<String>(_kRevisionItems, jsonEncode(safeList(data['items'])));
  await HomeWidget.saveWidgetData<String>(_kRevisionOverdueItems, jsonEncode(safeList(data['overdueItems'])));
  await HomeWidget.saveWidgetData<String>(_kRevisionTodayItems, jsonEncode(safeList(data['todayItems'])));
  await HomeWidget.saveWidgetData<String>(_kRevisionUpcomingItems, jsonEncode(safeList(data['upcomingItems'])));
}

Future<void> _saveClassWidgetData(
  Map<String, dynamic> data,
) async {
  final hasToday = data['hasToday'] as bool? ?? false;
  final items = data['classItems'] as List? ?? [];
  final todayItems = data['todayItems'] as List? ??
      items.where((e) => (e as Map)['isToday'] == true).toList();
  await HomeWidget.saveWidgetData<String>(_kClassHasToday, hasToday.toString());
  await HomeWidget.saveWidgetData<String>(_kClassStatusMessage, data['statusMessage'] as String? ?? '');
  await HomeWidget.saveWidgetData<String>(_kClassCurrentSubject, data['currentSubject'] as String? ?? '');
  await HomeWidget.saveWidgetData<String>(_kClassCurrentTime, data['currentTime'] as String? ?? '');
  await HomeWidget.saveWidgetData<String>(_kClassCurrentLocation, data['currentLocation'] as String? ?? '');
  await HomeWidget.saveWidgetData<String>(_kClassCurrentEndTime, data['currentRemaining'] as String? ?? '');
  await HomeWidget.saveWidgetData<String>(_kClassNextSubject, data['nextSubject'] as String? ?? '');
  await HomeWidget.saveWidgetData<String>(_kClassNextTime, data['nextTime'] as String? ?? '');
  await HomeWidget.saveWidgetData<String>(_kClassNextLocation, data['nextLocation'] as String? ?? '');
  await HomeWidget.saveWidgetData<String>(_kClassItems, jsonEncode(items));
  await HomeWidget.saveWidgetData<String>(_kClassTodayItems, jsonEncode(todayItems));
}

Future<void> _setEmptyData() async {
  await HomeWidget.saveWidgetData<String>(_kDailyHasData, 'false');
  await HomeWidget.saveWidgetData<String>(_kDailyStatusMessage, _kDailyEmptyMessage);
  await HomeWidget.saveWidgetData<String>(_kDailyUpcomingItems, '[]');
  await HomeWidget.saveWidgetData<String>(_kDailyAllItems, '[]');
  await HomeWidget.saveWidgetData<String>(_kDailyCurrentSubject, '');
  await HomeWidget.saveWidgetData<String>(_kDailyCurrentEndTimestamp, '0');
  await HomeWidget.saveWidgetData<String>(_kRevisionHasData, 'false');
  await HomeWidget.saveWidgetData<String>(_kRevisionStatusMessage, 'Nothing planned yet');
  await HomeWidget.saveWidgetData<String>(_kRevisionItems, '[]');
  await HomeWidget.saveWidgetData<String>(_kRevisionOverdueItems, '[]');
  await HomeWidget.saveWidgetData<String>(_kRevisionTodayItems, '[]');
  await HomeWidget.saveWidgetData<String>(_kRevisionUpcomingItems, '[]');
  await HomeWidget.saveWidgetData<String>(_kRevisionOverdueCount, '0');
  await HomeWidget.saveWidgetData<String>(_kRevisionTodayCount, '0');
  await HomeWidget.saveWidgetData<String>(_kRevisionUpcomingCount, '0');
  await HomeWidget.saveWidgetData<String>(_kClassHasToday, 'false');
  await HomeWidget.saveWidgetData<String>(_kClassStatusMessage, 'Nothing to show');
  await HomeWidget.saveWidgetData<String>(_kClassItems, '[]');
  await HomeWidget.saveWidgetData<String>(_kClassTodayItems, '[]');
}

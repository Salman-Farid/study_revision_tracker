part of '../widget_data_service.dart';

/// Daily-routine payload for the home-screen widget.
/// Matches the Routine tab: this widget shows ONLY assistant-created daily
/// routine items for today. Class routines live on the Class widget.
const String _kDailyEmptyMessage =
    'No Daily Routine Created, Tap To Create One';

Future<Map<String, dynamic>> _fetchDailyRoutineData(
  SupabaseClient client, String userId, DateTime now, DateTime today, DateTime tomorrow,
) async {
  final result = <String, dynamic>{
    'hasData': false,
    'statusMessage': _kDailyEmptyMessage,
    'upcomingItems': <Map<String, dynamic>>[],
    'allItems': <Map<String, dynamic>>[],
  };

  try {
    final dailyRows = await client
        .from('daily_routines')
        .select()
        .eq('user_id', userId)
        .gte('date', today.toIso8601String().substring(0, 10))
        .lt('date', tomorrow.toIso8601String().substring(0, 10))
        .order('date', ascending: true);

    final dailyItems = <Map<String, dynamic>>[];
    for (final row in dailyRows) {
      final model = DailyRoutineModel.fromJson(row);
      for (final item in model.items) {
        final parts = item.time.split(':');
        final h = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
        final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
        final start = DateTime(today.year, today.month, today.day, h, m);
        final end = start.add(Duration(minutes: item.durationMinutes));
        dailyItems.add({
          'subject': item.subject,
          'topic': item.topic,
          'type': item.type,
          'start': start,
          'end': end,
          'timeText': _formatTime12(h, m),
          'endTimeText': _formatTime12(end.hour, end.minute),
          'sortKey': item.time,
        });
      }
    }

    final allItems = [...dailyItems];
    allItems.sort((a, b) => (a['sortKey'] as String).compareTo(b['sortKey'] as String));

    if (allItems.isEmpty) return result;

    result['hasData'] = true;

    // Find current item (now falls within its time range)
    Map<String, dynamic>? currentItem;
    for (final item in allItems) {
      final start = item['start'] as DateTime;
      final end = item['end'] as DateTime;
      if (!now.isBefore(start) && now.isBefore(end)) {
        currentItem = item;
        break;
      }
    }

    if (currentItem != null) {
      final end = currentItem['end'] as DateTime;
      final remaining = end.difference(now);
      final remainingMin = remaining.inMinutes;
      result['currentSubject'] = currentItem['subject'] as String;
      result['currentTopic'] = currentItem['topic'] as String? ?? '';
      result['currentType'] = currentItem['type'] as String;
      result['currentTime'] = '${currentItem['timeText']} – ${currentItem['endTimeText']}';
      result['remaining'] = remainingMin > 60
          ? '${remainingMin ~/ 60}h ${remainingMin % 60}m left'
          : '${remainingMin}m left';
      result['currentEndTimestamp'] = end.millisecondsSinceEpoch;
      result['statusMessage'] = 'Currently: ${currentItem['subject']}';
    } else {
      result['statusMessage'] = 'No active block right now';
    }

    // Build upcoming items list (all future items, not just next)
    final upcomingItems = <Map<String, dynamic>>[];
    for (final item in allItems) {
      final start = item['start'] as DateTime;
      final end = item['end'] as DateTime;
      if (start.isAfter(now)) {
        final remainingMs = end.difference(now).inMilliseconds;
        final remainingMin = remainingMs ~/ 60000;
        upcomingItems.add({
          'subject': item['subject'] as String,
          'topic': item['topic'] as String? ?? '',
          'type': item['type'] as String,
          'timeText': '${item['timeText']} – ${item['endTimeText']}',
          'endTimestamp': end.millisecondsSinceEpoch,
          'remainingMin': remainingMin,
        });
      }
    }
    result['upcomingItems'] = upcomingItems;

    // Keep single next for backward compat
    if (upcomingItems.isNotEmpty) {
      result['nextSubject'] = upcomingItems[0]['subject'];
      result['nextTime'] = upcomingItems[0]['timeText'];
    }

    // Also save ALL items for full widget view
    final allItemsJson = <Map<String, dynamic>>[];
    for (final item in allItems) {
      final start = item['start'] as DateTime;
      final end = item['end'] as DateTime;
      final isPast = end.isBefore(now);
      final isCurrent = !now.isBefore(start) && now.isBefore(end);
      final remainingMs = end.difference(now).inMilliseconds;
      allItemsJson.add({
        'subject': item['subject'] as String,
        'topic': item['topic'] as String? ?? '',
        'type': item['type'] as String,
        'timeText': item['timeText'] as String,
        'endTimeText': item['endTimeText'] as String,
        'startTimestamp': start.millisecondsSinceEpoch,
        'endTimestamp': end.millisecondsSinceEpoch,
        'isPast': isPast,
        'isCurrent': isCurrent,
        'remainingMin': remainingMs > 0 ? remainingMs ~/ 60000 : 0,
      });
    }
    result['allItems'] = allItemsJson;
  } catch (e) {
    debugPrint('[WidgetData] _fetchDailyRoutineData error: $e');
    result['hasData'] = false;
    result['statusMessage'] = _kDailyEmptyMessage;
    result['upcomingItems'] = <Map<String, dynamic>>[];
    result['allItems'] = <Map<String, dynamic>>[];
  }

  return result;
}

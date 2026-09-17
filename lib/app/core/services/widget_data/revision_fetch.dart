part of '../widget_data_service.dart';

/// Revision payload for the home-screen widget.
Future<Map<String, dynamic>> _fetchRevisionData(
  SupabaseClient client, String userId, DateTime today, DateTime tomorrow,
) async {
  final result = <String, dynamic>{
    'hasData': false,
    'overdueCount': 0,
    'todayCount': 0,
    'upcomingCount': 0,
    'statusMessage': 'Nothing planned yet',
    'items': <Map<String, dynamic>>[],
  };

  try {
    // Fetch overdue
    final overdueRows = await client
        .from('revision_schedules')
        .select()
        .eq('user_id', userId)
        .eq('status', 'pending')
        .lt('scheduled_date', today.toIso8601String());

    // Fetch today
    final todayRows = await client
        .from('revision_schedules')
        .select()
        .eq('user_id', userId)
        .eq('status', 'pending')
        .gte('scheduled_date', today.toIso8601String())
        .lt('scheduled_date', tomorrow.toIso8601String());

    // Fetch upcoming — ALL future pending (Day 14 / 30 / 90 too),
    // not only the next 7 days.
    final upcomingRows = await client
        .from('revision_schedules')
        .select()
        .eq('user_id', userId)
        .eq('status', 'pending')
        .gte('scheduled_date', tomorrow.toIso8601String())
        .order('scheduled_date', ascending: true);

    // Calendar-date-only helpers. scheduled_date may parse as UTC midnight
    // while [today] is local midnight — instant compare wrongly puts today
    // into "upcoming". Always compare yyyy-MM-dd strings.
    String dayKey(DateTime d) {
      if (d.isUtc) return d.toIso8601String().substring(0, 10);
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '${d.year.toString().padLeft(4, '0')}-$m-$day';
    }

    final todayKey = dayKey(today);

    // Build items list for display — all overdue + today + upcoming
    final allPending = [
      ...?overdueRows as List?,
      ...?todayRows as List?,
      ...?upcomingRows as List?,
    ];
    final items = <Map<String, dynamic>>[];
    final overdueItems = <Map<String, dynamic>>[];
    final todayItems = <Map<String, dynamic>>[];
    final upcomingItems = <Map<String, dynamic>>[];

    // Batch-fetch topic and subject names for ALL items
    final topicIds = allPending.map((r) => r['topic_id'] as String).toSet();
    final subjectIds = allPending.map((r) => r['subject_id'] as String).toSet();

    Map<String, String> topicNames = {};
    Map<String, String> subjectNames = {};
    try {
      if (topicIds.isNotEmpty) {
        final topicRows = await client
            .from('topics')
            .select('id, name')
            .inFilter('id', topicIds.toList());
        for (final t in topicRows) {
          topicNames[t['id'] as String] = t['name'] as String? ?? '';
        }
      }
      if (subjectIds.isNotEmpty) {
        final subjectRows = await client
            .from('subjects')
            .select('id, name')
            .inFilter('id', subjectIds.toList());
        for (final s in subjectRows) {
          subjectNames[s['id'] as String] = s['name'] as String? ?? '';
        }
      }
    } catch (_) {}

    for (final row in allPending) {
      final schedule = RevisionScheduleModel.fromJson(row);
      final topicName = topicNames[schedule.topicId] ?? '';
      final subjectName = subjectNames[schedule.subjectId] ?? '';

      final dateStr = dayKey(schedule.scheduledDate);
      final cmp = dateStr.compareTo(todayKey);
      final isOverdue = cmp < 0;
      final isToday = cmp == 0;
      // Upcoming is strictly after today — today never belongs here.
      final isUpcoming = cmp > 0;
      final dayLabel = isOverdue ? 'Missed' : 'Day ${schedule.dayNumber}';
      final item = {
        'topicName': topicName,
        'subjectName': subjectName,
        'dayLabel': dayLabel,
        'dayNumber': schedule.dayNumber,
        'isOverdue': isOverdue,
        'isToday': isToday,
        'scheduleId': schedule.id,
        'topicId': schedule.topicId,
        'subjectId': schedule.subjectId,
        'scheduledDate': dateStr,
      };
      items.add(item);
      if (isOverdue) {
        overdueItems.add(item);
      } else if (isUpcoming) {
        upcomingItems.add(item);
      } else if (isToday) {
        todayItems.add(item);
      }
    }
    result['overdueCount'] = overdueItems.length;
    result['todayCount'] = todayItems.length;
    result['upcomingCount'] = upcomingItems.length;
    result['items'] = items;
    result['overdueItems'] = overdueItems;
    result['todayItems'] = todayItems;
    result['upcomingItems'] = upcomingItems;
    result['hasData'] = items.isNotEmpty;

    final totalPending = result['overdueCount'] + result['todayCount'];
    if (totalPending == 0 && result['upcomingCount'] == 0) {
      result['statusMessage'] = 'Nothing planned yet';
    } else if (result['overdueCount'] > 0) {
      result['statusMessage'] = '${result['overdueCount']} overdue, ${result['todayCount']} due today';
    } else {
      result['statusMessage'] = '${result['todayCount']} due today, ${result['upcomingCount']} upcoming';
    }
  } catch (e) {
    debugPrint('[WidgetData] _fetchRevisionData error: $e');
    // Never surface a raw error on the home screen widget.
    result['statusMessage'] = 'Nothing planned yet';
    result['items'] = <Map<String, dynamic>>[];
    result['overdueItems'] = <Map<String, dynamic>>[];
    result['todayItems'] = <Map<String, dynamic>>[];
    result['upcomingItems'] = <Map<String, dynamic>>[];
  }

  return result;
}

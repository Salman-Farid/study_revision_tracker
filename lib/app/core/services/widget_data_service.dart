import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/class_routine_model.dart';
import '../../data/models/daily_routine_model.dart';
import '../../data/models/revision_schedule_model.dart';

/// Background callback entry point — MUST be a top-level function.
/// Invoked by home_widget WorkManager / interactive taps when the
/// Flutter UI is not running.
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseAnonKey,
      );
    } catch (_) {
      // Already initialized in this isolate.
    }
    await WidgetDataProvider.updateAllWidgets(forceRefresh: true);
  } catch (e) {
    debugPrint('[WidgetData] backgroundCallback error: $e');
  }
}

/// Provides widget data to home screen widgets.
///
/// This service fetches data directly from Supabase (bypassing GetX)
/// so it works both in foreground and background callbacks.
class WidgetDataProvider {
  WidgetDataProvider._();

  // ── Deep-link scheme ──
  static const String urlScheme = 'study-revision-tracker';

  // ── SharedPreferences keys ──
  static const String _kDailyCurrentSubject = 'widget_daily_current_subject';
  static const String _kDailyCurrentTopic = 'widget_daily_current_topic';
  static const String _kDailyCurrentType = 'widget_daily_current_type';
  static const String _kDailyCurrentTime = 'widget_daily_current_time';
  static const String _kDailyRemaining = 'widget_daily_remaining';
  static const String _kDailyCurrentEndTimestamp = 'widget_daily_current_end_timestamp';
  static const String _kDailyNextSubject = 'widget_daily_next_subject';
  static const String _kDailyNextTime = 'widget_daily_next_time';
  static const String _kDailyHasData = 'widget_daily_has_data';
  static const String _kDailyStatusMessage = 'widget_daily_status_message';
  static const String _kDailyUpcomingItems = 'widget_daily_upcoming_items';
  static const String _kDailyAllItems = 'widget_daily_all_items';

  static const String _kRevisionOverdueItems = 'widget_revision_overdue_items';
  static const String _kRevisionTodayItems = 'widget_revision_today_items';
  static const String _kRevisionUpcomingItems = 'widget_revision_upcoming_items';
  static const String _kRevisionOverdueCount = 'widget_revision_overdue_count';
  static const String _kRevisionTodayCount = 'widget_revision_today_count';
  static const String _kRevisionUpcomingCount = 'widget_revision_upcoming_count';
  static const String _kRevisionItems = 'widget_revision_items';
  static const String _kRevisionHasData = 'widget_revision_has_data';
  static const String _kRevisionStatusMessage = 'widget_revision_status_message';

  static const String _kClassCurrentSubject = 'widget_class_current_subject';
  static const String _kClassCurrentTime = 'widget_class_current_time';
  static const String _kClassCurrentLocation = 'widget_class_current_location';
  static const String _kClassCurrentEndTime = 'widget_class_current_end_time';
  static const String _kClassNextSubject = 'widget_class_next_subject';
  static const String _kClassNextTime = 'widget_class_next_time';
  static const String _kClassNextLocation = 'widget_class_next_location';
  static const String _kClassItems = 'widget_class_items';
  static const String _kClassTodayItems = 'widget_class_today_items';
  static const String _kClassHasToday = 'widget_class_has_today';
  static const String _kClassStatusMessage = 'widget_class_status_message';

  static const String _kLastUpdated = 'widget_last_updated';

  // ── Initialize ──

  /// Call once during app startup to register background callbacks.
  static Future<void> init() async {
    try {
      await HomeWidget.registerInteractivityCallback(backgroundCallback);
    } catch (e) {
      debugPrint('[WidgetData] registerInteractivityCallback failed: $e');
    }
  }

  /// Get the initial deep link URI from a widget tap (if any).
  static Future<Uri?> getInitialLink() async {
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (_) {
      return null;
    }
  }

  // ── Widget tap handler ──
  // Interactive taps are handled by the Flutter app's navigation via deep links.
  // Background data refresh is handled by [backgroundCallback].

  // ── Public API ──

  /// Update all three widgets. Call on data changes and periodically.
  static Future<void> updateAllWidgets({bool forceRefresh = false}) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        await _setEmptyData();
        return;
      }
      final userId = user.id;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      // Fetch all needed data in parallel
      final results = await Future.wait([
        _fetchDailyRoutineData(client, userId, now, today, tomorrow),
        _fetchRevisionData(client, userId, today, tomorrow),
        _fetchClassRoutineData(client, userId, now, today, tomorrow),
      ]);

      debugPrint('[WidgetData] updateAllWidgets daily=${results[0]['hasData']} '
          'rev=${results[1]['hasData']} class=${results[2]['hasToday']}');

      // Save data via HomeWidget (writes to the platform-native shared
      // preferences file that Android/iOS widgets can read).
      await Future.wait([
        HomeWidget.saveWidgetData<String>(_kLastUpdated, now.toIso8601String()),
        _saveDailyWidgetData(results[0]),
        _saveRevisionWidgetData(results[1]),
        _saveClassWidgetData(results[2]),
      ]);

      // Notify native widgets to update
      await Future.wait([
        HomeWidget.updateWidget(
          qualifiedAndroidName: 'com.example.study_revision_tracker.DailyRoutineWidget',
        ),
        HomeWidget.updateWidget(
          qualifiedAndroidName: 'com.example.study_revision_tracker.RevisionWidget',
        ),
        HomeWidget.updateWidget(
          qualifiedAndroidName: 'com.example.study_revision_tracker.ClassRoutineWidget',
        ),
      ]);
    } catch (e, stack) {
      debugPrint('[WidgetData] updateAllWidgets error: $e\n$stack');
    }
  }

  // ── Daily Routine ──

  static Future<Map<String, dynamic>> _fetchDailyRoutineData(
    SupabaseClient client, String userId, DateTime now, DateTime today, DateTime tomorrow,
  ) async {
    final result = <String, dynamic>{
      'hasData': false,
      'statusMessage': 'Nothing to show',
    };

    try {
      // Fetch daily routines for today
      final dailyRows = await client
          .from('daily_routines')
          .select()
          .eq('user_id', userId)
          .gte('date', today.toIso8601String().substring(0, 10))
          .lt('date', tomorrow.toIso8601String().substring(0, 10))
          .order('date', ascending: true);

      // Fetch class routines for today
      final classRows = await client
          .from('class_routines')
          .select()
          .eq('user_id', userId);

      // Parse daily routine items
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

      // Parse class routine items for today
      final classItems = <Map<String, dynamic>>[];
      for (final row in classRows) {
        final cr = ClassRoutineModel.fromJson(row);
        final isToday = _classMatchesDay(cr, today);
        if (isToday) {
          final start = DateTime(today.year, today.month, today.day, cr.startTime.hour, cr.startTime.minute);
          final end = start.add(Duration(minutes: cr.durationMinutes));
          classItems.add({
            'subject': cr.subjectName,
            'topic': '',
            'type': 'class',
            'start': start,
            'end': end,
            'timeText': cr.timeText,
            'endTimeText': cr.endTimeText,
            'sortKey': '${cr.startTime.hour.toString().padLeft(2, '0')}:${cr.startTime.minute.toString().padLeft(2, '0')}',
            'location': cr.locationText,
          });
        }
      }

      // Merge and sort
      final allItems = [...classItems, ...dailyItems];
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
      result['statusMessage'] = 'No routine for today';
    }

    return result;
  }

  // ── Revision ──

  static Future<Map<String, dynamic>> _fetchRevisionData(
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

      result['overdueCount'] = (overdueRows as List).length;
      result['todayCount'] = (todayRows as List).length;
      result['upcomingCount'] = (upcomingRows as List).length;

      final totalPending = result['overdueCount'] + result['todayCount'];
      if (totalPending == 0 && result['upcomingCount'] == 0) {
        result['statusMessage'] = 'Nothing planned yet';
      } else if (result['overdueCount'] > 0) {
        result['statusMessage'] = '${result['overdueCount']} overdue, ${result['todayCount']} due today';
      } else {
        result['statusMessage'] = '${result['todayCount']} due today, ${result['upcomingCount']} upcoming';
      }

      // Build items list for display — all overdue + today + upcoming
      final allPending = [...overdueRows as List, ...todayRows as List, ...upcomingRows as List];
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

        final isOverdue = schedule.scheduledDate.isBefore(today);
        final isUpcoming = schedule.scheduledDate.isAfter(tomorrow.subtract(const Duration(days: 1)));
        final dayLabel = isOverdue ? 'Missed' : 'Day ${schedule.dayNumber}';
        final item = {
          'topicName': topicName,
          'subjectName': subjectName,
          'dayLabel': dayLabel,
          'dayNumber': schedule.dayNumber,
          'isOverdue': isOverdue,
          'scheduleId': schedule.id,
          'topicId': schedule.topicId,
          'subjectId': schedule.subjectId,
          'scheduledDate': schedule.scheduledDate.toIso8601String().substring(0, 10),
        };
        items.add(item);
        if (isOverdue) {
          overdueItems.add(item);
        } else if (isUpcoming) {
          upcomingItems.add(item);
        } else {
          todayItems.add(item);
        }
      }
      result['items'] = items;
      result['overdueItems'] = overdueItems;
      result['todayItems'] = todayItems;
      result['upcomingItems'] = upcomingItems;
      result['hasData'] = totalPending > 0 || result['upcomingCount'] > 0;
    } catch (e) {
      debugPrint('[WidgetData] _fetchRevisionData error: $e');
      // Never surface a raw error on the home screen widget.
      result['statusMessage'] = 'Nothing planned yet';
    }

    return result;
  }

  // ── Class Routine ──

  /// True if [cr] occurs on [day]. Tolerates ISO timestamps in `dates`,
  /// weekday names, numeric weekdays stored in `dates`, and a missing
  /// `recurring` flag when `recurringDays` is set.
  static bool _classMatchesDay(ClassRoutineModel cr, DateTime day) {
    final dateStr =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    const weekdayNames = [
      '', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
    ];
    const weekdayShort = ['', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final dayName = weekdayNames[day.weekday];
    final dayShort = weekdayShort[day.weekday];

    for (final raw in cr.dates) {
      final d = raw.trim();
      if (d.isEmpty) continue;
      // Exact or prefix date match (YYYY-MM-DD or ISO datetime)
      if (d == dateStr || d.startsWith(dateStr)) return true;
      final lower = d.toLowerCase();
      if (lower == dayName || lower == dayShort) return true;
      // Weekday number stored in dates: "3" or 3 as string
      final asInt = int.tryParse(d);
      if (asInt != null && asInt == day.weekday) return true;
    }
    if (cr.recurringDays.contains(day.weekday)) return true;
    return false;
  }

  static Future<Map<String, dynamic>> _fetchClassRoutineData(
    SupabaseClient client, String userId, DateTime now, DateTime today, DateTime tomorrow,
  ) async {
    // Always return a complete, valid payload so widgets never show an error.
    final result = <String, dynamic>{
      'hasToday': false,
      'statusMessage': 'Nothing to show',
      'classItems': <Map<String, dynamic>>[],
    };

    try {
      final classRows = await client
          .from('class_routines')
          .select()
          .eq('user_id', userId);

      final rowsList = classRows as List;
      final todayClasses = <Map<String, dynamic>>[];
      final displayClasses = <Map<String, dynamic>>[];

      for (final row in rowsList) {
        try {
          final cr = ClassRoutineModel.fromJson(row);
          final isToday = _classMatchesDay(cr, today);
          final startToday = DateTime(
            today.year, today.month, today.day, cr.startTime.hour, cr.startTime.minute,
          );
          final endToday = startToday.add(Duration(minutes: cr.durationMinutes));

          if (isToday) {
            todayClasses.add({
              'subject': cr.subjectName,
              'start': startToday,
              'end': endToday,
              'timeText': cr.timeText,
              'endTimeText': cr.endTimeText,
              'location': cr.locationText,
              'durationText': cr.durationText,
            });
          }

          displayClasses.add({
            'subject': cr.subjectName,
            'timeText': cr.timeText,
            'endTimeText': cr.endTimeText,
            'location': cr.locationText,
            'daysText': cr.daysText.isNotEmpty
                ? cr.daysText
                : (cr.dates.isNotEmpty ? cr.dates.join(', ') : 'One-time'),
            'durationMinutes': cr.durationMinutes,
            'durationText': cr.durationText,
            'startTimestamp': startToday.millisecondsSinceEpoch,
            'endTimestamp': endToday.millisecondsSinceEpoch,
            'isToday': isToday,
            'isCurrent': isToday &&
                !now.isBefore(startToday) &&
                now.isBefore(endToday),
            'isPast': isToday && endToday.isBefore(now),
          });
        } catch (_) {}
      }

      // Sort: today's classes first by time, then the rest by time-of-day.
      displayClasses.sort((a, b) {
        final aToday = a['isToday'] == true ? 0 : 1;
        final bToday = b['isToday'] == true ? 0 : 1;
        if (aToday != bToday) return aToday.compareTo(bToday);
        return (a['startTimestamp'] as int).compareTo(b['startTimestamp'] as int);
      });

      todayClasses.sort((a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));
      debugPrint('[WidgetData][Class] total=${displayClasses.length} today=${todayClasses.length}');

      if (displayClasses.isEmpty) {
        result['statusMessage'] = 'Nothing to show';
        return result;
      }

      // Widget has content whenever the user has any class routine (matches UI).
      result['hasToday'] = true;
      result['classItems'] = displayClasses;
      result['todayItems'] =
          displayClasses.where((e) => e['isToday'] == true).toList();

      // Prefer a live "now" card from today's schedule.
      Map<String, dynamic>? currentClass;
      for (final cls in todayClasses) {
        final start = cls['start'] as DateTime;
        final end = cls['end'] as DateTime;
        if (!now.isBefore(start) && now.isBefore(end)) {
          currentClass = cls;
          break;
        }
      }

      if (currentClass != null) {
        final end = currentClass['end'] as DateTime;
        final remainingMin = end.difference(now).inMinutes;
        result['currentSubject'] = currentClass['subject'] as String;
        result['currentTime'] = '${currentClass['timeText']} – ${currentClass['endTimeText']}';
        result['currentLocation'] = currentClass['location'] as String? ?? '';
        result['currentRemaining'] = remainingMin > 60
            ? '${remainingMin ~/ 60}h ${remainingMin % 60}m left'
            : '${remainingMin}m left';
        result['statusMessage'] = 'Now: ${currentClass['subject']}';
      } else if (todayClasses.isNotEmpty) {
        final next = todayClasses.firstWhere(
          (cls) => (cls['start'] as DateTime).isAfter(now),
          orElse: () => todayClasses.first,
        );
        result['nextSubject'] = next['subject'] as String;
        result['nextTime'] = '${next['timeText']} – ${next['endTimeText']}';
        result['nextLocation'] = next['location'] as String? ?? '';
        result['statusMessage'] = 'Next: ${next['subject']}';
      } else {
        result['statusMessage'] = '${displayClasses.length} classes scheduled';
      }
    } catch (e, st) {
      debugPrint('[WidgetData] _fetchClassRoutineData error: $e');
      debugPrint('[WidgetData] stack: $st');
      result['hasToday'] = false;
      result['statusMessage'] = 'Nothing to show';
      result['classItems'] = <Map<String, dynamic>>[];
    }

    return result;
  }

  // ── Save helpers ──

  static Future<void> _saveDailyWidgetData(
    Map<String, dynamic> data,
  ) async {
    await HomeWidget.saveWidgetData<String>(_kDailyHasData, (data['hasData'] as bool? ?? false).toString());
    await HomeWidget.saveWidgetData<String>(_kDailyStatusMessage, data['statusMessage'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kDailyCurrentSubject, data['currentSubject'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kDailyCurrentTopic, data['currentTopic'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kDailyCurrentType, data['currentType'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kDailyCurrentTime, data['currentTime'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kDailyRemaining, data['remaining'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kDailyCurrentEndTimestamp, (data['currentEndTimestamp'] as int? ?? 0).toString());
    await HomeWidget.saveWidgetData<String>(_kDailyNextSubject, data['nextSubject'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kDailyNextTime, data['nextTime'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kDailyUpcomingItems, jsonEncode(data['upcomingItems'] ?? []));
    await HomeWidget.saveWidgetData<String>(_kDailyAllItems, jsonEncode(data['allItems'] ?? []));
  }

  static Future<void> _saveRevisionWidgetData(
    Map<String, dynamic> data,
  ) async {
    await HomeWidget.saveWidgetData<String>(_kRevisionHasData, (data['hasData'] as bool? ?? false).toString());
    await HomeWidget.saveWidgetData<String>(_kRevisionStatusMessage, data['statusMessage'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kRevisionOverdueCount, (data['overdueCount'] as int? ?? 0).toString());
    await HomeWidget.saveWidgetData<String>(_kRevisionTodayCount, (data['todayCount'] as int? ?? 0).toString());
    await HomeWidget.saveWidgetData<String>(_kRevisionUpcomingCount, (data['upcomingCount'] as int? ?? 0).toString());
    await HomeWidget.saveWidgetData<String>(_kRevisionItems, jsonEncode(data['items']));
    await HomeWidget.saveWidgetData<String>(_kRevisionOverdueItems, jsonEncode(data['overdueItems']));
    await HomeWidget.saveWidgetData<String>(_kRevisionTodayItems, jsonEncode(data['todayItems']));
    await HomeWidget.saveWidgetData<String>(_kRevisionUpcomingItems, jsonEncode(data['upcomingItems']));
  }

  static Future<void> _saveClassWidgetData(
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

  static Future<void> _setEmptyData() async {
    await HomeWidget.saveWidgetData<String>(_kDailyHasData, 'false');
    await HomeWidget.saveWidgetData<String>(_kDailyStatusMessage, 'Nothing to show');
    await HomeWidget.saveWidgetData<String>(_kRevisionHasData, 'false');
    await HomeWidget.saveWidgetData<String>(_kRevisionStatusMessage, 'Nothing planned yet');
    await HomeWidget.saveWidgetData<String>(_kClassHasToday, 'false');
    await HomeWidget.saveWidgetData<String>(_kClassStatusMessage, 'Nothing to show');
    await HomeWidget.saveWidgetData<String>(_kClassItems, '[]');
    await HomeWidget.saveWidgetData<String>(_kClassTodayItems, '[]');
  }

  // ── Utility ──

  static String _formatTime12(int hour, int minute) {
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
  static Future<void> schedulePeriodicUpdate() async {
    try {
      await HomeWidget.registerInteractivityCallback(backgroundCallback);
    } catch (_) {}
  }

  /// Save the App Group ID for iOS widget data sharing.
  static Future<void> setAppGroupId(String groupId) async {
    try {
      await HomeWidget.setAppGroupId(groupId);
    } catch (e) {
      debugPrint('[WidgetData] setAppGroupId failed: $e');
    }
  }
}

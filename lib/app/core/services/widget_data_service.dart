import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/class_routine_model.dart';
import '../../data/models/daily_routine_model.dart';
import '../../data/models/revision_schedule_model.dart';

/// Background callback entry point — MUST be a top-level function.
@pragma('vm:entry-point')
void backgroundCallback(Uri? uri) async {
  if (uri?.host == 'updateWidgets') {
    await WidgetDataProvider.updateAllWidgets(forceRefresh: true);
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
  static const String _kDailyNextSubject = 'widget_daily_next_subject';
  static const String _kDailyNextTime = 'widget_daily_next_time';
  static const String _kDailyHasData = 'widget_daily_has_data';
  static const String _kDailyStatusMessage = 'widget_daily_status_message';

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
  static const String _kClassHasToday = 'widget_class_has_today';
  static const String _kClassStatusMessage = 'widget_class_status_message';

  static const String _kLastUpdated = 'widget_last_updated';

  // ── Initialize ──

  /// Call once during app startup to register background callbacks.
  static Future<void> init() async {
    await HomeWidget.registerInteractivityCallback(_onWidgetTapped);
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

  static Future<void> _onWidgetTapped(Uri? uri) async {
    // Deep links are handled by the Flutter app's navigation.
    // The URI scheme is registered in native config.
  }

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

      // Save data via HomeWidget (writes to the platform-native shared
      // preferences file that Android/iOS widgets can read).
      await HomeWidget.saveWidgetData<String>(_kLastUpdated, now.toIso8601String());

      await Future.wait([
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
      'statusMessage': 'No routine set for today',
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
        final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        final isToday = cr.dates.contains(dateStr) ||
            (cr.recurring && cr.recurringDays.contains(today.weekday));
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
        result['statusMessage'] = 'Currently: ${currentItem['subject']}';
      } else {
        result['statusMessage'] = 'No active block right now';
      }

      // Find next item
      Map<String, dynamic>? nextItem;
      for (final item in allItems) {
        final start = item['start'] as DateTime;
        if (start.isAfter(now)) {
          nextItem = item;
          break;
        }
      }
      if (nextItem != null) {
        result['nextSubject'] = nextItem['subject'] as String;
        result['nextTime'] = '${nextItem['timeText']} – ${nextItem['endTimeText']}';
      }
    } catch (e) {
      debugPrint('[WidgetData] _fetchDailyRoutineData error: $e');
      result['statusMessage'] = 'Error loading routine';
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
      'statusMessage': 'No revisions scheduled',
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

      // Fetch upcoming (next 7 days)
      final upcomingEnd = tomorrow.add(const Duration(days: 7));
      final upcomingRows = await client
          .from('revision_schedules')
          .select()
          .eq('user_id', userId)
          .eq('status', 'pending')
          .gte('scheduled_date', tomorrow.toIso8601String())
          .lt('scheduled_date', upcomingEnd.toIso8601String());

      result['overdueCount'] = (overdueRows as List).length;
      result['todayCount'] = (todayRows as List).length;
      result['upcomingCount'] = (upcomingRows as List).length;

      final totalPending = result['overdueCount'] + result['todayCount'];
      if (totalPending == 0 && result['upcomingCount'] == 0) {
        result['statusMessage'] = 'All caught up!';
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
      result['statusMessage'] = 'Error loading revisions';
    }

    return result;
  }

  // ── Class Routine ──

  static Future<Map<String, dynamic>> _fetchClassRoutineData(
    SupabaseClient client, String userId, DateTime now, DateTime today, DateTime tomorrow,
  ) async {
    final result = <String, dynamic>{
      'hasToday': false,
      'statusMessage': 'No classes today',
    };

    try {
      final classRows = await client
          .from('class_routines')
          .select()
          .eq('user_id', userId);

      final todayClasses = <Map<String, dynamic>>[];
      for (final row in classRows) {
        final cr = ClassRoutineModel.fromJson(row);
        final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        final isToday = cr.dates.contains(dateStr) ||
            (cr.recurring && cr.recurringDays.contains(today.weekday));
        if (isToday) {
          final start = DateTime(today.year, today.month, today.day, cr.startTime.hour, cr.startTime.minute);
          final end = start.add(Duration(minutes: cr.durationMinutes));
          todayClasses.add({
            'subject': cr.subjectName,
            'start': start,
            'end': end,
            'timeText': cr.timeText,
            'endTimeText': cr.endTimeText,
            'location': cr.locationText,
            'durationText': cr.durationText,
          });
        }
      }

      todayClasses.sort((a, b) => (a['start'] as DateTime).compareTo(b['start'] as DateTime));

      if (todayClasses.isEmpty) return result;

      result['hasToday'] = true;

      // Find current class
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
        final remaining = end.difference(now);
        final remainingMin = remaining.inMinutes;
        result['currentSubject'] = currentClass['subject'] as String;
        result['currentTime'] = '${currentClass['timeText']} – ${currentClass['endTimeText']}';
        result['currentLocation'] = currentClass['location'] as String? ?? '';
        result['currentRemaining'] = remainingMin > 60
            ? '${remainingMin ~/ 60}h ${remainingMin % 60}m left'
            : '${remainingMin}m left';
        result['statusMessage'] = 'Now: ${currentClass['subject']}';
      } else {
        result['statusMessage'] = 'No class right now';
      }

      // Find next class
      Map<String, dynamic>? nextClass;
      for (final cls in todayClasses) {
        final start = cls['start'] as DateTime;
        if (start.isAfter(now)) {
          nextClass = cls;
          break;
        }
      }

      if (nextClass != null) {
        result['nextSubject'] = nextClass['subject'] as String;
        result['nextTime'] = '${nextClass['timeText']} – ${nextClass['endTimeText']}';
        result['nextLocation'] = nextClass['location'] as String? ?? '';
      }

      // Build class items JSON for widget list display
      final classItems = <Map<String, dynamic>>[];
      for (final cls in todayClasses) {
        final start = cls['start'] as DateTime;
        final end = cls['end'] as DateTime;
        final isCurrent = !now.isBefore(start) && now.isBefore(end);
        classItems.add({
          'subject': cls['subject'] as String,
          'timeText': cls['timeText'] as String,
          'endTimeText': cls['endTimeText'] as String,
          'location': cls['location'] as String? ?? '',
          'isCurrent': isCurrent,
        });
      }
      result['classItems'] = classItems;
    } catch (e) {
      debugPrint('[WidgetData] _fetchClassRoutineData error: $e');
      result['statusMessage'] = 'Error loading classes';
    }

    return result;
  }

  // ── Save helpers ──

  static Future<void> _saveDailyWidgetData(
    Map<String, dynamic> data,
  ) async {
    await HomeWidget.saveWidgetData<bool>(_kDailyHasData, data['hasData'] as bool? ?? false);
    await HomeWidget.saveWidgetData<String>(_kDailyStatusMessage, data['statusMessage'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kDailyCurrentSubject, data['currentSubject'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kDailyCurrentTopic, data['currentTopic'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kDailyCurrentType, data['currentType'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kDailyCurrentTime, data['currentTime'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kDailyRemaining, data['remaining'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kDailyNextSubject, data['nextSubject'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kDailyNextTime, data['nextTime'] as String? ?? '');
  }

  static Future<void> _saveRevisionWidgetData(
    Map<String, dynamic> data,
  ) async {
    await HomeWidget.saveWidgetData<bool>(_kRevisionHasData, data['hasData'] as bool? ?? false);
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
    await HomeWidget.saveWidgetData<bool>(_kClassHasToday, data['hasToday'] as bool? ?? false);
    await HomeWidget.saveWidgetData<String>(_kClassStatusMessage, data['statusMessage'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kClassCurrentSubject, data['currentSubject'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kClassCurrentTime, data['currentTime'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kClassCurrentLocation, data['currentLocation'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kClassCurrentEndTime, data['currentRemaining'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kClassNextSubject, data['nextSubject'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kClassNextTime, data['nextTime'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kClassNextLocation, data['nextLocation'] as String? ?? '');
    await HomeWidget.saveWidgetData<String>(_kClassItems, jsonEncode(data['classItems'] ?? []));
  }

  static Future<void> _setEmptyData() async {
    await HomeWidget.saveWidgetData<bool>(_kDailyHasData, false);
    await HomeWidget.saveWidgetData<String>(_kDailyStatusMessage, 'Sign in to see your routine');
    await HomeWidget.saveWidgetData<bool>(_kRevisionHasData, false);
    await HomeWidget.saveWidgetData<String>(_kRevisionStatusMessage, 'Sign in to see revisions');
    await HomeWidget.saveWidgetData<bool>(_kClassHasToday, false);
    await HomeWidget.saveWidgetData<String>(_kClassStatusMessage, 'Sign in to see classes');
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
      // Re-register in case it was lost
      await HomeWidget.registerInteractivityCallback(_onWidgetTapped);
    } catch (_) {}
  }

  /// Save the App Group ID for iOS widget data sharing.
  static Future<void> setAppGroupId(String groupId) async {
    try {
      await HomeWidget.setAppGroupId(groupId);
    } catch (_) {}
  }
}

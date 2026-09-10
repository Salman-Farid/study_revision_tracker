import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../../data/models/class_routine_model.dart';
import '../../data/models/daily_routine_model.dart';
import '../../data/models/revision_schedule_model.dart';

/// Native notification service backed by `flutter_local_notifications`.
///
/// Schedules three kinds of reminders from existing app data:
///   • **Revision** — fires at the scheduled date (default 08:00 local).
///   • **Class Routine** — fires 30 minutes before every class.
///   • **Daily Routine** — fires at the start of each timeline block.
///
/// Timezone is resolved via `flutter_timezone` so alarms fire on device
/// local time (not UTC), which was the root cause of multi-hour delays.
class NotificationService extends GetxService {
  static NotificationService get to => Get.find<NotificationService>();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _notificationsEnabled = true;

  static const _channelRevision = 'revision_channel';
  static const _channelRevisionName = 'Revision Reminders';
  static const _channelClass = 'class_channel';
  static const _channelClassName = 'Class Reminders';
  static const _channelDaily = 'daily_routine_channel';
  static const _channelDailyName = 'Daily Routine Reminders';

  @override
  Future<NotificationService> onInit() async {
    super.onInit();
    await _init();
    return this;
  }

  Future<NotificationService> init() async {
    await _init();
    return this;
  }

  Future<void> _init() async {
    if (_initialized) return;
    _initialized = true;

    await _configureLocalTimeZone();

    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelRevision,
          _channelRevisionName,
          description: 'Reminders for scheduled revisions',
          importance: Importance.high,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelClass,
          _channelClassName,
          description: 'Reminders 30 minutes before class',
          importance: Importance.high,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelDaily,
          _channelDailyName,
          description: 'Reminders when each daily routine block starts',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
      await androidPlugin.requestNotificationsPermission();
    }

    final iosPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(alert: true, badge: true, sound: true);
    }

    const androidSettings = AndroidInitializationSettings('ic_notif');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Resolve the device timezone into the `timezone` package.
  /// Without this, `tz.local` stays UTC and alarms fire hours late/early.
  Future<void> _configureLocalTimeZone() async {
    tz_data.initializeTimeZones();
    try {
      final String name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      debugPrint('[NotificationService] timezone set to $name');
    } catch (e) {
      debugPrint('[NotificationService] timezone resolve failed: $e');
      // Fallback: try common mappings if the plugin fails.
      try {
        final now = DateTime.now();
        final offset = now.timeZoneOffset;
        // Keep UTC as last resort; exact alarms will still use absolute time.
        tz.setLocalLocation(tz.UTC);
        debugPrint('[NotificationService] fallback UTC, local offset=$offset');
      } catch (_) {}
    }
  }

  Future<void> refreshNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = prefs.getBool('notifications_enabled') ?? true;
    if (newValue != _notificationsEnabled) {
      _notificationsEnabled = newValue;
      if (!newValue) {
        await cancelAll();
      } else {
        await rescheduleAll();
      }
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    _handleDeepLink(payload);
  }

  void _handleDeepLink(String uri) {
    try {
      final parsed = Uri.parse(uri);
      if (parsed.host == 'revision') {
        Get.until((route) => route.settings.name == '/home');
      } else if (parsed.host == 'class' || parsed.host == 'routine') {
        Get.until((route) => route.settings.name == '/home');
      }
    } catch (_) {}
  }

  // ── Deterministic notification IDs ──

  static int _revisionNotifId(String scheduleId) =>
      scheduleId.hashCode & 0x7FFFFFFF;

  static int _classNotifId(String routineId, DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year)).inDays;
    return (routineId.hashCode ^ (dayOfYear << 16)) & 0x7FFFFFFF;
  }

  static int _dailyNotifId(String routineId, int itemIndex, DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year)).inDays;
    return (routineId.hashCode ^ (itemIndex << 8) ^ (dayOfYear << 20)) &
        0x7FFFFFFF;
  }

  // ── Revision scheduling ──

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
          _channelRevision,
          _channelRevisionName,
          channelDescription: 'Reminders for scheduled revisions',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notif',
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

  // ── Class routine scheduling ──

  /// Schedule class reminders for the next [daysAhead] days.
  /// Each class gets a notification 30 minutes before its start time.
  Future<void> scheduleClassRoutine({
    required ClassRoutineModel routine,
    int daysAhead = 14,
  }) async {
    if (!_notificationsEnabled) return;

    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);

    for (int d = 0; d < daysAhead; d++) {
      final date = today.add(Duration(days: d));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final isToday = routine.dates.any((d) =>
              d == dateStr || d.startsWith(dateStr)) ||
          routine.recurringDays.contains(date.weekday);
      if (!isToday) continue;

      final classStart = tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day,
        routine.startTime.hour,
        routine.startTime.minute,
      );
      var reminderTime = classStart.subtract(const Duration(minutes: 30));

      // If the 30-min-before slot already passed but class hasn't started,
      // fire immediately so the user still gets a heads-up.
      if (!reminderTime.isAfter(now)) {
        if (classStart.isAfter(now)) {
          reminderTime = now.add(const Duration(seconds: 30));
        } else {
          continue;
        }
      }

      final id = _classNotifId(routine.id, date);
      final locationPart = routine.locationText.isNotEmpty
          ? ' at ${routine.locationText}'
          : '';
      final payload = 'study-revision-tracker://class/${routine.id}';

      await _plugin.zonedSchedule(
        id,
        '🏫 Class soon: ${routine.subjectName}',
        '${routine.timeText}$locationPart — ${routine.durationText} class',
        reminderTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelClass,
            _channelClassName,
            channelDescription: 'Reminders 30 minutes before class',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_notif',
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
  }

  Future<void> cancelClassRoutine(String routineId, {int daysAhead = 30}) async {
    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);
    for (int d = 0; d < daysAhead; d++) {
      final date = today.add(Duration(days: d));
      await _plugin.cancel(_classNotifId(routineId, date));
    }
  }

  // ── Daily routine scheduling ──

  /// Parse "9:00", "09:30", "9:00 AM", "9 AM", "14:00:00" into [hour, minute].
  /// Returns null if the string cannot be understood.
  static List<int>? _parseClock(String raw) {
    var s = raw.trim().toLowerCase();
    if (s.isEmpty) return null;
    var isPm = false;
    var isAm = false;
    if (s.endsWith('am') || s.endsWith('a.m.')) {
      isAm = true;
      s = s.replaceAll(RegExp(r'\s*a\.?m\.?\s*$'), '').trim();
    } else if (s.endsWith('pm') || s.endsWith('p.m.')) {
      isPm = true;
      s = s.replaceAll(RegExp(r'\s*p\.?m\.?\s*$'), '').trim();
    }
    s = s.replaceAll(RegExp(r'\s+'), '');
    if (s.isEmpty) return null;

    final parts = s.split(':');
    var h = int.tryParse(parts[0]) ?? -1;
    if (h < 0) return null;
    var m = 0;
    if (parts.length > 1) {
      m = int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    if (isPm && h < 12) h += 12;
    if (isAm && h == 12) h = 0;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return [h, m];
  }

  /// Schedule a notification for every future block in [routine].
  /// Fires exactly when each block starts (device-local time).
  Future<int> scheduleDailyRoutine({
    required DailyRoutineModel routine,
    int daysAhead = 7,
  }) async {
    if (!_notificationsEnabled) {
      debugPrint('[NotificationService] scheduleDailyRoutine skipped (disabled)');
      return 0;
    }

    final now = tz.TZDateTime.now(tz.local);
    // Normalize the routine's calendar day in LOCAL time (date-only DB
    // strings parse as UTC midnight and would shift the day).
    final rawDate = routine.date;
    final baseDate = DateTime(rawDate.year, rawDate.month, rawDate.day);

    int scheduled = 0;
    for (int d = 0; d < daysAhead; d++) {
      final day = baseDate.add(Duration(days: d));

      for (int i = 0; i < routine.items.length; i++) {
        final item = routine.items[i];
        final hm = _parseClock(item.time);
        if (hm == null) {
          debugPrint('[NotificationService] skip block #$i bad time="${item.time}"');
          continue;
        }
        final h = hm[0];
        final m = hm[1];

        final blockStart = tz.TZDateTime(tz.local, day.year, day.month, day.day, h, m);
        if (!blockStart.isAfter(now)) {
          debugPrint('[NotificationService] skip past block #$i ${item.subject} $blockStart');
          continue;
        }

        final id = _dailyNotifId(routine.id, i, day);
        final label = item.subject.isNotEmpty ? item.subject : (item.type.isNotEmpty ? item.type : 'Study');
        final topicPart = item.topic.isNotEmpty ? ': ${item.topic}' : '';
        final payload = 'study-revision-tracker://routine/${routine.id}';

        try {
          await _plugin.zonedSchedule(
            id,
            '📋 $label$topicPart',
            '${_formatTime12(h, m)} — ${item.durationMinutes} min block',
            blockStart,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                _channelDaily,
                _channelDailyName,
                channelDescription: 'Reminders when each daily routine block starts',
                importance: Importance.high,
                priority: Priority.high,
                icon: 'ic_notif',
          color: const Color(0xFF87CEEB),
                playSound: true,
                enableVibration: true,
                visibility: NotificationVisibility.public,
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
          scheduled++;
          debugPrint('[NotificationService] scheduled daily #$id "$label" at $blockStart');
        } catch (e) {
          debugPrint('[NotificationService] zonedSchedule failed for "$label": $e');
        }
      }
    }
    debugPrint('[NotificationService] scheduleDailyRoutine done id=${routine.id} '
        'items=${routine.items.length} scheduled=$scheduled now=$now');
    return scheduled;
  }

  Future<void> cancelDailyRoutine(String routineId, {int daysAhead = 30}) async {
    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);
    for (int d = 0; d < daysAhead; d++) {
      final date = today.add(Duration(days: d));
      for (int i = 0; i < 20; i++) {
        await _plugin.cancel(_dailyNotifId(routineId, i, date));
      }
    }
  }

  // ── Bulk reschedule ──

  DateTime? _lastReschedule;
  bool _rescheduleRunning = false;

  /// Cancel everything and re-schedule from the database.
  /// Batched name lookups; safe to call many times quickly.
  Future<void> rescheduleAll() async {
    if (!_notificationsEnabled) return;
    if (_rescheduleRunning) return;
    final now = DateTime.now();
    if (_lastReschedule != null &&
        now.difference(_lastReschedule!).inSeconds < 5) {
      return;
    }
    _lastReschedule = now;
    _rescheduleRunning = true;

    try {
      await _plugin.cancelAll();
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      final userId = user.id;
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final farFuture = todayStart.add(const Duration(days: 90));

      final results = await Future.wait([
        _fetchPendingRevisions(client, userId, todayStart, farFuture),
        _fetchActiveClassRoutines(client, userId),
        _fetchActiveDailyRoutines(client, userId, todayStart),
      ]);

      final schedules = results[0] as List<RevisionScheduleModel>;
      final classRoutines = results[1] as List<ClassRoutineModel>;
      final dailyRoutines = results[2] as List<DailyRoutineModel>;

      // Batch-fetch topic/subject names (one query each, not N).
      final topicIds = schedules.map((s) => s.topicId).toSet();
      final subjectIds = schedules.map((s) => s.subjectId).toSet();
      final names = await Future.wait([
        _fetchNames(client, 'topics', topicIds),
        _fetchNames(client, 'subjects', subjectIds),
      ]);
      final topicNames = names[0];
      final subjectNames = names[1];

      debugPrint(
          '[NotificationService] rescheduleAll: ${schedules.length} revisions, '
          '${classRoutines.length} classes, ${dailyRoutines.length} daily routines '
          'tz=${tz.local.name} now=$now');

      for (final schedule in schedules) {
        try {
          await scheduleRevision(
            schedule: schedule,
            topicName: topicNames[schedule.topicId] ?? 'Topic',
            subjectName: subjectNames[schedule.subjectId] ?? 'Subject',
          );
        } catch (_) {}
      }

      for (final routine in classRoutines) {
        try {
          await scheduleClassRoutine(routine: routine, daysAhead: 14);
        } catch (_) {}
      }

      for (final routine in dailyRoutines) {
        try {
          // Only 2 days ahead — 7 days × 25 blocks hits OS alarm limits
          // and Samsung drops extras silently.
          final n = await scheduleDailyRoutine(routine: routine, daysAhead: 2);
          debugPrint('[NotificationService] daily routine ${routine.id} → $n alarms');
        } catch (e) {
          debugPrint('[NotificationService] daily schedule failed: $e');
        }
      }

      // Prove the channel works: one immediate notification.
      try {
        await _plugin.show(
          999001,
          '✅ Notifications ready',
          'Daily routine reminders will fire at each block start.',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelDaily,
              _channelDailyName,
              channelDescription: 'Reminders when each daily routine block starts',
              importance: Importance.max,
              priority: Priority.max,
              icon: 'ic_notif',
          color: const Color(0xFF87CEEB),
            ),
          ),
        );
      } catch (e) {
        debugPrint('[NotificationService] test notification failed: $e');
      }
    } catch (e, stack) {
      debugPrint('[NotificationService] rescheduleAll error: $e');
      debugPrint('[NotificationService] stack: $stack');
    } finally {
      _rescheduleRunning = false;
      try {
        final pending = await getPending();
        debugPrint('[NotificationService] pending alarms after reschedule: ${pending.length}');
        for (final p in pending.take(12)) {
          debugPrint('  id=${p.id} title=${p.title} payload=${p.payload}');
        }
      } catch (_) {}
    }
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Data helpers ──

  Future<Map<String, String>> _fetchNames(
    SupabaseClient client,
    String table,
    Set<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    final rows =
        await client.from(table).select('id, name').inFilter('id', ids.toList());
    return {for (final r in rows as List) r['id'] as String: r['name'] as String? ?? ''};
  }

  Future<List<RevisionScheduleModel>> _fetchPendingRevisions(
    SupabaseClient client,
    String userId,
    DateTime from,
    DateTime to,
  ) async {
    final rows = await client
        .from('revision_schedules')
        .select()
        .eq('user_id', userId)
        .eq('status', 'pending')
        .gte('scheduled_date', from.toIso8601String())
        .lte('scheduled_date', to.toIso8601String())
        .order('scheduled_date', ascending: true);
    return (rows as List)
        .map((j) => RevisionScheduleModel.fromJson(j))
        .toList();
  }

  Future<List<ClassRoutineModel>> _fetchActiveClassRoutines(
    SupabaseClient client,
    String userId,
  ) async {
    final rows = await client
        .from('class_routines')
        .select()
        .eq('user_id', userId)
        .order('start_time', ascending: true);
    return (rows as List)
        .map((j) => ClassRoutineModel.fromJson(j))
        .toList();
  }

  Future<List<DailyRoutineModel>> _fetchActiveDailyRoutines(
    SupabaseClient client,
    String userId,
    DateTime from,
  ) async {
    final to = from.add(const Duration(days: 7));
    final rows = await client
        .from('daily_routines')
        .select()
        .eq('user_id', userId)
        .gte('date', from.toIso8601String().substring(0, 10))
        .lte('date', to.toIso8601String().substring(0, 10))
        .order('date', ascending: true);
    return (rows as List)
        .map((j) => DailyRoutineModel.fromJson(j))
        .toList();
  }

  // ── Android exact-alarm permission ──

  Future<bool> requestExactAlarmPermission() async {
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
}

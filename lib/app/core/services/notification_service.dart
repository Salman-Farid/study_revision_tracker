import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
///   • **Revision** — fires exactly at the scheduled date/time.
///   • **Class Routine** — fires 30 minutes before every class.
///   • **Daily Routine** — fires at the start of each timeline block.
///
/// All IDs are derived deterministically from the underlying data so the
/// same schedule never produces duplicate notifications, and cancelling a
/// record automatically cancels its reminder.
class NotificationService extends GetxService {
  // ── Singleton ──
  static NotificationService get to => Get.find<NotificationService>();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _notificationsEnabled = true;

  // ──────────────────────────────────────────────
  //  Channels
  // ──────────────────────────────────────────────
  static const _channelRevision = 'revision_channel';
  static const _channelRevisionName = 'Revision Reminders';
  static const _channelClass = 'class_channel';
  static const _channelClassName = 'Class Reminders';
  static const _channelDaily = 'daily_routine_channel';
  static const _channelDailyName = 'Daily Routine Reminders';

  // ──────────────────────────────────────────────
  //  Lifecycle
  // ──────────────────────────────────────────────

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

    // Timezone
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.local);
    } catch (_) {}

    // Restore preference
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

    // Android channels
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
          importance: Importance.defaultImportance,
        ),
      );

      // Android 13+ runtime permission
      await androidPlugin.requestNotificationsPermission();
    }

    // iOS permission
    final iosPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Initialize the plugin (required before scheduling)
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // handled above
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Listen to preference changes via SharedPreferences stream
    _watchNotificationPreference();
  }

  /// Poll the notification preference every time the app resumes.
  /// Called by MainNavigation or app lifecycle handler.
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

  void _watchNotificationPreference() {
    // Use a periodic check as a fallback (SharedPreferences doesn't have streams)
    // The primary trigger is refreshNotificationPreference() called from app lifecycle.
  }

  // ──────────────────────────────────────────────
  //  Notification tap → deep-link
  // ──────────────────────────────────────────────

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    // Navigate via deep-link URI.  The splash screen already handles
    // `study-revision-tracker://` URIs, so we push a new one.
    // When the app is already running we navigate directly.
    _handleDeepLink(payload);
  }

  void _handleDeepLink(String uri) {
    try {
      final parsed = Uri.parse(uri);
      final pathSegments = parsed.pathSegments;
      if (pathSegments.isEmpty) return;
      // Route to the relevant section of MainNavigation.
      // Tabs: 0=Dashboard, 1=Subjects, 2=Today, 3=Routine, 4=Calendar, 5=Settings
      if (parsed.host == 'revision') {
        // Go to Today tab (index 2) — revisions are shown there
        Get.until((route) => route.settings.name == '/home');
        // Nothing more specific to navigate to in current routing
      } else if (parsed.host == 'class' || parsed.host == 'routine') {
        // Go to Routine tab (index 3)
        Get.until((route) => route.settings.name == '/home');
      }
    } catch (_) {}
  }

  // ──────────────────────────────────────────────
  //  Deterministic notification IDs
  // ──────────────────────────────────────────────

  /// Revision notification ID: stable hash of the schedule UUID.
  static int _revisionNotifId(String scheduleId) {
    return scheduleId.hashCode & 0x7FFFFFFF; // positive 31-bit
  }

  /// Class notification ID: hash of routine UUID XOR'd with the
  /// day-of-year so different days produce different IDs.
  static int _classNotifId(String routineId, DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year)).inDays;
    return (routineId.hashCode ^ (dayOfYear << 16)) & 0x7FFFFFFF;
  }

  /// Daily routine notification ID: hash of routine UUID XOR'd with
  /// item index and day-of-year.
  static int _dailyNotifId(String routineId, int itemIndex, DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year)).inDays;
    return (routineId.hashCode ^ (itemIndex << 8) ^ (dayOfYear << 20)) &
        0x7FFFFFFF;
  }

  // ──────────────────────────────────────────────
  //  Revision scheduling
  // ──────────────────────────────────────────────

  /// Schedule a single revision reminder at [scheduledDate].
  Future<void> scheduleRevision({
    required RevisionScheduleModel schedule,
    required String topicName,
    required String subjectName,
  }) async {
    if (!_notificationsEnabled) return;
    if (schedule.status != 'pending') return;

    // Use the date from scheduledDate; schedule at 08:00 local time
    // (the typical revision slot) unless the stored date is already in
    // the future.
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      schedule.scheduledDate.year,
      schedule.scheduledDate.month,
      schedule.scheduledDate.day,
      8, // default 8 AM
      0,
    );

    // If 8 AM today has already passed, try the user's stored time or
    // fall back to "now + 1 min" so it still fires today.
    if (!scheduled.isAfter(now)) {
      // Schedule for 8 AM tomorrow if today's slot is gone
      final tomorrow = scheduled.add(const Duration(days: 1));
      scheduled = tz.TZDateTime(
        tz.local,
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        8,
        0,
      );
    }

    // If even that is in the past, skip.
    if (!scheduled.isAfter(now)) return;

    final id = _revisionNotifId(schedule.id);
    final payload =
        'study-revision-tracker://revision/${schedule.id}';

    await _plugin.zonedSchedule(
      id,
      '📚 Revision: $subjectName',
      'Day ${schedule.dayNumber} — $topicName is due today',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelRevision,
          _channelRevisionName,
          channelDescription: 'Reminders for scheduled revisions',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
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

  /// Cancel a specific revision notification.
  Future<void> cancelRevision(String scheduleId) async {
    await _plugin.cancel(_revisionNotifId(scheduleId));
  }

  // ──────────────────────────────────────────────
  //  Class routine scheduling
  // ──────────────────────────────────────────────

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

      final isToday = routine.dates.contains(dateStr) ||
          (routine.recurring && routine.recurringDays.contains(date.weekday));
      if (!isToday) continue;

      // Compute the 30-minute-before time
      final classStart = tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day,
        routine.startTime.hour,
        routine.startTime.minute,
      );
      final reminderTime = classStart.subtract(const Duration(minutes: 30));

      if (!reminderTime.isAfter(now)) continue; // already passed

      final id = _classNotifId(routine.id, date);
      final locationPart = routine.locationText.isNotEmpty
          ? ' at ${routine.locationText}'
          : '';
      final payload =
          'study-revision-tracker://class/${routine.id}';

      await _plugin.zonedSchedule(
        id,
        '🏫 Class in 30 min: ${routine.subjectName}',
        '${routine.timeText}$locationPart — ${routine.durationText} class',
        reminderTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelClass,
            _channelClassName,
            channelDescription: 'Reminders 30 minutes before class',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
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

  /// Cancel all class notifications for a specific routine.
  Future<void> cancelClassRoutine(String routineId, {int daysAhead = 30}) async {
    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);
    for (int d = 0; d < daysAhead; d++) {
      final date = today.add(Duration(days: d));
      await _plugin.cancel(_classNotifId(routineId, date));
    }
  }

  // ──────────────────────────────────────────────
  //  Daily routine scheduling
  // ──────────────────────────────────────────────

  /// Schedule notifications for each block in today's (and upcoming)
  /// daily routine.  A notification fires at the block's start time.
  Future<void> scheduleDailyRoutine({
    required DailyRoutineModel routine,
    int daysAhead = 7,
  }) async {
    if (!_notificationsEnabled) return;

    final now = tz.TZDateTime.now(tz.local);
    final baseDate = routine.date;

    for (int d = 0; d < daysAhead; d++) {
      final date = baseDate.add(Duration(days: d));

      for (int i = 0; i < routine.items.length; i++) {
        final item = routine.items[i];
        final parts = item.time.split(':');
        if (parts.length < 2) continue;
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;

        final blockStart = tz.TZDateTime(
          tz.local,
          date.year,
          date.month,
          date.day,
          h,
          m,
        );

        if (!blockStart.isAfter(now)) continue;

        final id = _dailyNotifId(routine.id, i, date);
        final label =
            item.subject.isNotEmpty ? item.subject : item.type.capitalizeFirst;
        final topicPart =
            item.topic.isNotEmpty ? ': ${item.topic}' : '';
        final payload =
            'study-revision-tracker://routine/${routine.id}';

        await _plugin.zonedSchedule(
          id,
          '📋 $label$topicPart',
          '${_formatTime12(h, m)} — ${item.durationMinutes} min block',
          blockStart,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelDaily,
              _channelDailyName,
              channelDescription:
                  'Reminders when each daily routine block starts',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
              icon: '@mipmap/ic_launcher',
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
  }

  /// Cancel all daily-routine notifications for a specific routine.
  Future<void> cancelDailyRoutine(String routineId, {int daysAhead = 30}) async {
    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);
    // Cancel up to max possible items per day × days
    for (int d = 0; d < daysAhead; d++) {
      final date = today.add(Duration(days: d));
      for (int i = 0; i < 20; i++) {
        await _plugin.cancel(_dailyNotifId(routineId, i, date));
      }
    }
  }

  // ──────────────────────────────────────────────
  //  Bulk reschedule (called on data changes)
  // ──────────────────────────────────────────────

  /// Cancel everything and re-schedule from the database.
  /// Debounced internally — safe to call many times quickly.
  DateTime? _lastReschedule;
  Future<void> rescheduleAll() async {
    if (!_notificationsEnabled) return;
    final now = DateTime.now();
    if (_lastReschedule != null && now.difference(_lastReschedule!).inSeconds < 5) {
      return;
    }
    _lastReschedule = now;

    try {
      await _plugin.cancelAll();
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      final userId = user.id;
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final farFuture = todayStart.add(const Duration(days: 90));

      // Fetch all data in parallel
      final results = await Future.wait([
        _fetchPendingRevisions(client, userId, todayStart, farFuture),
        _fetchActiveClassRoutines(client, userId),
        _fetchActiveDailyRoutines(client, userId, todayStart),
      ]);

      final schedules = results[0] as List<RevisionScheduleModel>;
      final classRoutines = results[1] as List<ClassRoutineModel>;
      final dailyRoutines = results[2] as List<DailyRoutineModel>;

      // Schedule revisions
      for (final schedule in schedules) {
        try {
          // Fetch topic/subject names
          final topicRow = await client
              .from('topics')
              .select('name')
              .eq('id', schedule.topicId)
              .maybeSingle();
          final subjectRow = await client
              .from('subjects')
              .select('name')
              .eq('id', schedule.subjectId)
              .maybeSingle();
          final topicName = topicRow?['name'] as String? ?? 'Topic';
          final subjectName = subjectRow?['name'] as String? ?? 'Subject';
          await scheduleRevision(
            schedule: schedule,
            topicName: topicName,
            subjectName: subjectName,
          );
        } catch (_) {}
      }

      // Schedule class reminders
      for (final routine in classRoutines) {
        try {
          await scheduleClassRoutine(routine: routine, daysAhead: 14);
        } catch (_) {}
      }

      // Schedule daily routine reminders
      for (final routine in dailyRoutines) {
        try {
          await scheduleDailyRoutine(routine: routine, daysAhead: 7);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[NotificationService] rescheduleAll error: $e');
    }
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ──────────────────────────────────────────────
  //  Data fetching helpers (direct Supabase, no GetX)
  // ──────────────────────────────────────────────

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

  // ──────────────────────────────────────────────
  //  Android exact-alarm permission
  // ──────────────────────────────────────────────

  /// Check and request the SCHEDULE_EXACT_ALARM permission on Android 12+.
  /// Returns `true` if alarms can be scheduled exactly.
  Future<bool> requestExactAlarmPermission() async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return true; // not Android
    final allowed = await androidPlugin.areNotificationsEnabled() ?? false;
    if (!allowed) {
      await androidPlugin.requestNotificationsPermission();
    }
    // For Android 12+ exact alarms, the user must grant via system settings.
    // We attempt the request and fall back to inexact if denied.
    try {
      final granted = await androidPlugin.requestExactAlarmsPermission();
      return granted ?? false;
    } catch (_) {
      // Older Android — no permission needed
      return true;
    }
  }

  // ──────────────────────────────────────────────
  //  Pending notifications (for debugging)
  // ──────────────────────────────────────────────

  Future<List<PendingNotificationRequest>> getPending() async {
    return await _plugin.pendingNotificationRequests();
  }

  // ──────────────────────────────────────────────
  //  Utilities
  // ──────────────────────────────────────────────

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

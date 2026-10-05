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
import '../../domain/routine/class_day_matcher.dart';
import '../../domain/routine/routine_time_utils.dart';
import 'web_push_service.dart';

part 'notifications/format_clock.dart';
part 'notifications/ids.dart';
part 'notifications/revision_schedule.dart';
part 'notifications/class_schedule.dart';
part 'notifications/daily_schedule.dart';
part 'notifications/bulk_reschedule.dart';
part 'notifications/data_helpers.dart';
part 'notifications/exact_alarm.dart';


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
  DateTime? _lastReschedule;
  bool _rescheduleRunning = false;

  /// In-memory dedupe keys for blocks we already announced as "started"
  /// while the user was away (web catch-up notification).
  final Set<String> _shownCatchUpKeys = <String>{};

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
    if (kIsWeb) {
      // Web: Web Push + in-tab Notification API (works on any device/browser).
      _initialized = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      } catch (e) {
        debugPrint('[NotificationService] web pref load failed: $e');
      }
      try {
        if (!Get.isRegistered<WebPushService>()) {
          await Get.putAsync(() async => await WebPushService().init());
        } else {
          await WebPushService.to.init();
        }
      } catch (e) {
        debugPrint('[NotificationService] web push init failed: $e');
      }
      return;
    }
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

    const androidSettings = AndroidInitializationSettings('ic_stat_notif');
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
    final changed = newValue != _notificationsEnabled;
    _notificationsEnabled = newValue;

    if (!newValue) {
      await cancelAll();
      return;
    }

    if (kIsWeb) {
      // Enabling must run inside a user gesture so the browser will show
      // the permission prompt at all.
      if (Get.isRegistered<WebPushService>()) {
        await WebPushService.to.requestPermissionAndSubscribe();
      }
      await rescheduleAll(force: true);
      return;
    }

    if (changed) {
      await rescheduleAll();
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
}

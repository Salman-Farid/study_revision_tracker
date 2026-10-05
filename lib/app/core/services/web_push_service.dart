import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'web_push_support_stub.dart'
    if (dart.library.html) 'web_push_support_web.dart';

/// Production Web Push + in-tab notifications for daily-routine blocks.
///
/// - Chrome/Edge/Firefox desktop & Android browser: Web Push works with the
///   tab closed (service worker + VAPID + Supabase edge cron sender).
/// - iOS Safari 16.4+: Web Push works only if the site is installed to the
///   Home Screen (still covered).
/// - While the tab is open we ALSO fire a local Notification immediately
///   when a block starts (best latency).
class WebPushService extends GetxService {
  static WebPushService get to => Get.find<WebPushService>();

  final List<Timer> _timers = [];
  bool _ready = false;
  Future<WebPushService>? _initFuture;
  bool _authHooked = false;

  /// Number of armed in-tab block timers.
  int get pendingTimerCount => _timers.length;

  /// Whether boot has finished (permission prompt included).
  bool get isReady => _ready;

  /// Boot exactly once. Returns immediately for callers that just need the
  /// service to exist; use [ensureReady] when the result matters.
  Future<WebPushService> init() => _initFuture ??= _doInit();

  Future<WebPushService> _doInit() async {
    if (!kIsWeb) {
      _ready = true;
      return this;
    }
    _hookAuth();
    try {
      final perm = await requestNotifPermission()
          .timeout(const Duration(seconds: 8), onTimeout: () => 'default');
      debugPrint('[WebPush] permission=$perm');
      if (perm == 'granted') {
        await _subscribeAndSave();
      }
    } catch (e) {
      debugPrint('[WebPush] init failed: $e');
    } finally {
      _ready = true;
    }
    return this;
  }

  /// Await boot without re-entering it. Safe to call from anywhere.
  Future<void> ensureReady() async {
    if (!kIsWeb) return;
    try {
      await init();
    } catch (e) {
      debugPrint('[WebPush] ensureReady failed: $e');
    }
  }

  void _hookAuth() {
    if (_authHooked) return;
    _authHooked = true;
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((state) {
        if (state.event == AuthChangeEvent.signedIn ||
            state.event == AuthChangeEvent.tokenRefreshed) {
          unawaited(_afterAuth());
        }
      });
    } catch (e) {
      debugPrint('[WebPush] auth hook failed: $e');
    }
  }

  Future<void> _afterAuth() async {
    try {
      final perm = await requestNotifPermission();
      if (perm == 'granted') await _subscribeAndSave();
    } catch (e) {
      debugPrint('[WebPush] post-auth subscribe failed: $e');
    }
  }

  /// Ask for permission (must run from a user gesture) and subscribe.
  /// Returns true when a subscription row was written.
  Future<bool> requestPermissionAndSubscribe() async {
    if (!kIsWeb) return false;
    try {
      final perm = await requestNotifPermission();
      debugPrint('[WebPush] permission=$perm');
      if (perm != 'granted') return false;
      final ok = await _subscribeAndSave();
      _ready = true;
      return ok;
    } catch (e) {
      debugPrint('[WebPush] subscribe failed: $e');
      return false;
    }
  }

  Future<bool> _subscribeAndSave() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return false;
    final sub = await subscribeWebPush();
    if (sub == null) return false;
    final endpoint = sub['endpoint'] as String? ?? '';
    final p256dh = sub['p256dh'] as String? ?? '';
    final auth = sub['auth'] as String? ?? '';
    final tzOff =
        (sub['timezone_offset_minutes'] as num?)?.toInt() ?? deviceTimezoneOffsetMinutes();
    if (endpoint.isEmpty || p256dh.isEmpty || auth.isEmpty) return false;
    await client.from('push_subscriptions').upsert({
      'user_id': uid,
      'endpoint': endpoint,
      'p256dh': p256dh,
      'auth': auth,
      'timezone_offset_minutes': tzOff,
    }, onConflict: 'endpoint');
    debugPrint('[WebPush] subscription saved offset=$tzOff');
    return true;
  }

  /// Schedule in-tab Notification + rely on edge Web Push for closed tab.
  ///
  /// Pass `cancelExisting: false` when batching several routines so each
  /// call adds to the same timer list instead of wiping it.
  int scheduleDailyRoutineBlocks({
    required String routineId,
    required DateTime date,
    required List<Map<String, dynamic>> items,
    bool cancelExisting = true,
  }) {
    if (!kIsWeb) return 0;
    if (cancelExisting) _cancelTimers();
    final now = DateTime.now();
    int n = 0;
    final dayKey = date.toIso8601String().substring(0, 10);
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final time = (item['time'] as String?) ?? '';
      final parts = time.split(':');
      if (parts.length < 2) continue;
      final h = int.tryParse(parts[0]) ?? -1;
      final m = int.tryParse(parts[1]) ?? -1;
      if (h < 0 || m < 0) continue;
      final start = DateTime(date.year, date.month, date.day, h, m);
      if (!start.isAfter(now)) continue;
      final subject = (item['subject'] as String?) ?? '';
      final topic = (item['topic'] as String?) ?? '';
      final type = (item['type'] as String?) ?? '';
      final label = subject.isNotEmpty ? subject : (type.isNotEmpty ? type : 'Study');
      final title = '📋 $label${topic.isEmpty ? '' : ': $topic'}';
      final body = '${start.hour % 12 == 0 ? 12 : start.hour % 12}:'
          '${start.minute.toString().padLeft(2, '0')} '
          '${start.hour >= 12 ? 'PM' : 'AM'} — '
          '${item['duration_minutes'] ?? item['durationMinutes'] ?? ''} min block';
      final tag = '$routineId:$dayKey:$i';
      _timers.add(Timer(start.difference(now), () {
        showLocalNotification(title, body, tag: tag);
      }));
      n++;
    }
    return n;
  }

  /// Drop every armed in-tab timer (disable toggle / full rebuild).
  void resetTimers() => _cancelTimers();

  /// Fire a notification immediately (web catch-up / "block started now").
  /// No-op on non-web platforms.
  void showNow(String title, String body, {String tag = 'routine'}) {
    if (!kIsWeb) return;
    showLocalNotification(title, body, tag: tag);
  }

  void _cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  @override
  void onClose() {
    _cancelTimers();
    super.onClose();
  }
}

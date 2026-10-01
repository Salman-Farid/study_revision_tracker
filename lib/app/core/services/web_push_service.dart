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

  Future<WebPushService> init() async {
    if (!kIsWeb) return this;
    try {
      final perm = await requestNotifPermission();
      debugPrint('[WebPush] permission=$perm');
      if (perm == 'granted') {
        await _subscribeAndSave();
      }
    } catch (e) {
      debugPrint('[WebPush] init failed: $e');
    }
    _ready = true;
    return this;
  }

  Future<void> _subscribeAndSave() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    final sub = await subscribeWebPush();
    if (sub == null) return;
    final endpoint = sub['endpoint'] as String? ?? '';
    final p256dh = sub['p256dh'] as String? ?? '';
    final auth = sub['auth'] as String? ?? '';
    final tzOff = (sub['timezone_offset_minutes'] as num?)?.toInt() ?? deviceTimezoneOffsetMinutes();
    if (endpoint.isEmpty || p256dh.isEmpty || auth.isEmpty) return;
    await client.from('push_subscriptions').upsert({
      'user_id': uid,
      'endpoint': endpoint,
      'p256dh': p256dh,
      'auth': auth,
      'timezone_offset_minutes': tzOff,
    }, onConflict: 'endpoint');
    debugPrint('[WebPush] subscription saved offset=$tzOff');
  }

  /// Schedule in-tab Notification + rely on edge Web Push for closed tab.
  int scheduleDailyRoutineBlocks({
    required String routineId,
    required DateTime date,
    required List<Map<String, dynamic>> items,
  }) {
    if (!kIsWeb || !_ready) return 0;
    _cancelTimers();
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

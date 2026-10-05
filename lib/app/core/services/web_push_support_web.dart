// Web-only Web Push / Notification API (package:web + dart:js_interop).
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// VAPID public key (base64url) — safe to ship in the client.
const kWebPushVapidPublic =
    'BHGiFSsEz4ecfnO4tg1CitLiQbwvzPdCHFCeq4Ro3_B52KWba5IHf3I8YulKfS-i42Aduw2AJ26kyR1e-GYOY7I';

/// Push worker lives in its own scope so Flutter's root-scope
/// `flutter_service_worker.js` (which unregisters itself on activate)
/// can never destroy the push subscription.
const String kPushWorkerUrl = '/push/sw.js';
const String kPushWorkerScope = '/push/';

/// Minutes east of UTC (e.g. Dhaka = 360).
int deviceTimezoneOffsetMinutes() =>
    DateTime.now().timeZoneOffset.inMinutes;

Future<String> requestNotifPermission() async {
  try {
    final result = await web.Notification.requestPermission().toDart;
    return result.toDart;
  } catch (_) {
    return 'denied';
  }
}

web.ServiceWorkerContainer? _container() {
  try {
    return web.window.navigator.serviceWorker;
  } catch (_) {
    return null;
  }
}

Future<List<web.ServiceWorkerRegistration>> _registrations() async {
  final sw = _container();
  if (sw == null) return const [];
  try {
    final arr = await sw.getRegistrations().toDart;
    return arr.toDart;
  } catch (_) {
    return const [];
  }
}

/// Longest-scope matching is ambiguous in some browsers, so pick the
/// registration whose scope *path* is exactly [path].
Future<web.ServiceWorkerRegistration?> _registrationWithPath(
    String path) async {
  for (final r in await _registrations()) {
    final p = Uri.tryParse(r.scope)?.path ?? '';
    if (p == path || p == '$path/') return r;
  }
  return null;
}

/// Resolve the push worker registration, installing it on first use.
Future<web.ServiceWorkerRegistration?> _pushRegistration() async {
  final sw = _container();
  if (sw == null) return null;
  try {
    final existing = await _registrationWithPath('/push');
    if (existing != null && existing.active != null) return existing;
    final reg = await sw
        .register(
          kPushWorkerUrl.toJS,
          web.RegistrationOptions(scope: kPushWorkerScope),
        )
        .toDart;
    final deadline = DateTime.now().add(const Duration(seconds: 4));
    while (reg.active == null && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return reg;
  } catch (_) {
    return null;
  }
}

/// Older builds registered `notification-sw.js` at the site root. Flutter
/// already unregisters that worker, but if any stale root-scope push
/// subscription survives, drop it so only `/push/` owns the subscription.
Future<void> _dropStaleRootSubscription() async {
  try {
    final root = await _registrationWithPath('/');
    if (root == null) return;
    final sub = await root.pushManager.getSubscription().toDart;
    if (sub != null) await sub.unsubscribe().toDart;
  } catch (_) {}
}

/// Show a notification. Prefers `registration.showNotification` because
/// Android Chrome refuses `new Notification()` from a page context.
void showLocalNotification(String title, String body,
    {String tag = 'routine'}) {
  unawaited(_notify(title, body, tag));
}

Future<void> _notify(String title, String body, String tag) async {
  try {
    final reg = await _pushRegistration();
    if (reg != null && reg.active != null) {
      await reg
          .showNotification(
            title,
            web.NotificationOptions(
              body: body,
              tag: tag,
              icon: '/icons/Icon-192.png',
              badge: '/icons/Icon-192.png',
              requireInteraction: true,
              renotify: true,
            ),
          )
          .toDart;
      return;
    }
  } catch (_) {}
  try {
    web.Notification(
      title,
      web.NotificationOptions(
        body: body,
        tag: tag,
        icon: '/icons/Icon-192.png',
      ),
    );
  } catch (_) {}
}

List<int> _b64urlToBytes(String s) {
  var t = s.replaceAll('-', '+').replaceAll('_', '/');
  while (t.length % 4 != 0) {
    t += '=';
  }
  return base64.decode(t);
}

Future<Map<String, dynamic>?> subscribeWebPush() async {
  try {
    final reg = await _pushRegistration();
    if (reg == null) return null;
    await _dropStaleRootSubscription();
    var sub = await reg.pushManager.getSubscription().toDart;
    sub ??= await reg.pushManager
        .subscribe(
          web.PushSubscriptionOptionsInit(
            userVisibleOnly: true,
            applicationServerKey:
                Uint8List.fromList(_b64urlToBytes(kWebPushVapidPublic))
                    .buffer
                    .toJS,
          ),
        )
        .toDart;
    final endpoint = sub.endpoint;
    String? p256dh;
    String? auth;
    try {
      final keys = sub.toJSON().keys.dartify();
      if (keys is Map) {
        p256dh = keys['p256dh']?.toString();
        auth = keys['auth']?.toString();
      }
    } catch (_) {}
    return {
      'endpoint': endpoint,
      'p256dh': p256dh,
      'auth': auth,
      'timezone_offset_minutes': deviceTimezoneOffsetMinutes(),
    };
  } catch (_) {
    return null;
  }
}

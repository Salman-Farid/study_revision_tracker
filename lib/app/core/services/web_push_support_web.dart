// Web-only Web Push / Notification API.
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// VAPID public key (base64url) — safe to ship in the client.
const kWebPushVapidPublic =
    'BHGiFSsEz4ecfnO4tg1CitLiQbwvzPdCHFCeq4Ro3_B52KWba5IHf3I8YulKfS-i42Aduw2AJ26kyR1e-GYOY7I';

/// Minutes east of UTC (e.g. Dhaka = 360).
int deviceTimezoneOffsetMinutes() =>
    DateTime.now().timeZoneOffset.inMinutes;

Future<String> requestNotifPermission() async {
  try {
    final result = await html.Notification.requestPermission();
    return result?.toString() ?? 'default';
  } catch (_) {
    return 'denied';
  }
}

void showLocalNotification(String title, String body, {String tag = 'routine'}) {
  try {
    html.Notification(title, body: body, tag: tag, icon: 'icons/Icon-192.png');
  } catch (_) {
    try {
      html.Notification(title, body: body);
    } catch (_) {}
  }
}

List<int> _b64urlToBytes(String s) {
  var t = s.replaceAll('-', '+').replaceAll('_', '/');
  while (t.length % 4 != 0) {
    t += '=';
  }
  return base64.decode(t);
}

List<int> _bytesOf(dynamic data) {
  if (data is TypedData) {
    return Uint8List.view(data.buffer, data.offsetInBytes, data.lengthInBytes);
  }
  if (data is List) return List<int>.from(data);
  return const [];
}

String _bytesToB64url(List<int> b) =>
    base64Url.encode(b).replaceAll('=', '');

Future<Map<String, dynamic>?> subscribeWebPush() async {
  try {
    final sw = html.window.navigator.serviceWorker;
    if (sw == null) return null;
    final reg = await sw.ready;
    final pm = reg.pushManager;
    if (pm == null) return null;
    html.PushSubscription? sub;
    try {
      sub = await pm.getSubscription();
    } catch (_) {}
    if (sub == null) {
      final key = Uint8List.fromList(_b64urlToBytes(kWebPushVapidPublic));
      sub = await pm.subscribe({
        'userVisibleOnly': true,
        'applicationServerKey': key,
      });
    }
    final endpoint = sub?.endpoint ?? '';
    String? p256dh;
    String? auth;
    try {
      final k1 = sub?.getKey('p256dh');
      final k2 = sub?.getKey('auth');
      if (k1 != null) p256dh = _bytesToB64url(_bytesOf(k1));
      if (k2 != null) auth = _bytesToB64url(_bytesOf(k2));
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

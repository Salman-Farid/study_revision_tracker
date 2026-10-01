int deviceTimezoneOffsetMinutes() => 0;

Future<String> requestNotifPermission() async => 'denied';

void showLocalNotification(String title, String body, {String tag = 'routine'}) {}

const kWebPushVapidPublic = '';

Future<Map<String, dynamic>?> subscribeWebPush() async => null;

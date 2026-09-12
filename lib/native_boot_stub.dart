/// Web stubs — home widgets / WorkManager / AlarmManager do not exist in browsers.
Future<void> backgroundCallbackRef(Uri? uri) async {}

Future<void> registerHomeWidgetCallback(
        Future<void> Function(Uri?) callback) async {}

Future<void> scheduleNativeWidgetTick() async {}

Future<void> registerBackgroundWidgetRefresh() async {}

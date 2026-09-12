import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:workmanager/workmanager.dart';

import 'app/core/services/notification_service.dart';
import 'app/core/services/widget_data_service.dart';
import 'app/core/constants/app_constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';

/// Reference used by HomeWidget interactivity callback (top-level required).
@pragma('vm:entry-point')
Future<void> backgroundCallbackRef(Uri? uri) => backgroundCallback(uri);

Future<void> registerHomeWidgetCallback(
    Future<void> Function(Uri?) callback) async {
  await HomeWidget.registerInteractivityCallback(callback);
}

Future<void> scheduleNativeWidgetTick() async {
  const channel = MethodChannel('study_revision_tracker/widget_tick');
  await channel.invokeMethod('schedule');
}

/// WorkManager entry — keeps widgets fresh when the Flutter UI is closed.
@pragma('vm:entry-point')
void workManagerDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await SharedPreferences.getInstance();
      try {
        await Supabase.initialize(
          url: AppConstants.supabaseUrl,
          anonKey: AppConstants.supabaseAnonKey,
        );
      } catch (_) {}
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return true;
      await WidgetDataProvider.updateAllWidgets(forceRefresh: true);
      try {
        final notifications = NotificationService();
        await notifications.init();
        await notifications.rescheduleAll();
      } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  });
}

Future<void> registerBackgroundWidgetRefresh() async {
  try {
    await Workmanager().initialize(workManagerDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      'study-widget-refresh',
      'study-widget-refresh',
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.linear,
    );
  } catch (e) {
    debugPrint('[native_boot] WorkManager register failed: $e');
  }
}

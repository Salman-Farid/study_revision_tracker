import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../services/notification_service.dart';
import '../services/widget_data_service.dart';
import '../../data/services/supabase_service.dart';

// Native-only imports — never loaded on web (avoids MissingPluginException).
import '../../../native_boot_stub.dart'
    if (dart.library.io) '../../../native_boot_io.dart';

Timer? _periodicWidgetTimer;

/// Home-widget platform channels and WorkManager registration. No-op on web.
Future<void> initNativeWidgets() async {
  if (kIsWeb) return;
  await WidgetDataProvider.init();
  try {
    await registerHomeWidgetCallback(backgroundCallbackRef);
  } catch (e) {
    debugPrint('[main] registerInteractivityCallback failed: $e');
  }
  try {
    await WidgetDataProvider.setAppGroupId('group.HOMEWIDGET');
  } catch (_) {}
}

/// Called once after the first frame: alarms, widgets, WorkManager.
/// No-op on web.
Future<void> postFrameBoot() async {
  if (kIsWeb) return;
  if (Get.find<SupabaseService>().currentUser == null) return;
  try {
    final granted =
        await Get.find<NotificationService>().requestExactAlarmPermission();
    debugPrint('[main] exactAlarmPermission granted=$granted');
  } catch (_) {}
  try {
    await scheduleNativeWidgetTick();
  } catch (e) {
    debugPrint('[main] widget tick channel failed: $e');
  }
  unawaited(Get.find<NotificationService>().rescheduleAll());
  unawaited(WidgetDataProvider.updateAllWidgets());
  _startPeriodicWidgetRefresh();
  unawaited(registerBackgroundWidgetRefresh());
}

void _startPeriodicWidgetRefresh() {
  if (kIsWeb) return;
  _periodicWidgetTimer?.cancel();
  _periodicWidgetTimer = Timer.periodic(const Duration(minutes: 5), (_) {
    if (Get.find<SupabaseService>().currentUser != null) {
      unawaited(WidgetDataProvider.updateAllWidgets());
    }
  });
}

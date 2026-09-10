import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_revision_tracker/gemini_3_flash_live_voice_chatbot/gemini_chatbot.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:workmanager/workmanager.dart';
import 'app/core/constants/app_constants.dart';
import 'app/core/localization/language_controller.dart';
import 'app/core/localization/app_translations.dart';
import 'app/core/services/connectivity_service.dart';
import 'app/core/services/notification_service.dart';
import 'app/core/services/widget_data_service.dart';
import 'app/data/repositories/revision_repository.dart';
import 'app/data/repositories/subject_repository.dart';
import 'app/data/repositories/topic_repository.dart';
import 'app/data/repositories/routine_repository.dart';
import 'app/data/services/supabase_service.dart';
import 'app/modules/settings/settings_controller.dart';
import 'app/modules/navigation/main_navigation.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/theme/app_theme.dart';

Timer? _periodicWidgetTimer;

/// WorkManager entry point — runs in a background isolate even when
/// the Flutter UI is closed, so home widgets stay fresh without
/// requiring the user to open the app.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await SharedPreferences.getInstance();

      try {
        await Supabase.initialize(
          url: AppConstants.supabaseUrl,
          anonKey: AppConstants.supabaseAnonKey,
        );
      } catch (_) {
        // Already initialized in this isolate.
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return true;

      // Refresh widget data from Supabase.
      await WidgetDataProvider.updateAllWidgets(forceRefresh: true);

      // Also refresh local notifications so timings stay in sync.
      try {
        final notifications = NotificationService();
        await notifications.init();
        await notifications.rescheduleAll();
      } catch (e) {
        debugPrint('[WorkManager] notification refresh failed: $e');
      }
      return true;
    } catch (e) {
      debugPrint('[WorkManager] task failed: $e');
      return false;
    }
  });
}

Future<void> _registerBackgroundWidgetRefresh() async {
  try {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      'study-widget-refresh',
      'study-widget-refresh',
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.linear,
    );
    debugPrint('[main] background widget refresh registered');
  } catch (e) {
    debugPrint('[main] WorkManager register failed: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  Get.put(SupabaseService(), permanent: true);
  Get.put(SubjectRepository(), permanent: true);
  Get.put(TopicRepository(), permanent: true);
  Get.put(RevisionRepository(), permanent: true);
  Get.put(RoutineRepository(), permanent: true);
  Get.put(ConnectivityService(), permanent: true);
  Get.put(GeminiLiveService(), permanent: true);
  Get.put(VoiceAssistantController(), permanent: true);
  Get.put(LanguageController(), permanent: true);
  Get.put(SettingsController(), permanent: true);
  await Get.putAsync<NotificationService>(() => NotificationService().init());

  if (Get.find<SupabaseService>().currentUser != null) {
    Get.find<SupabaseService>().initRealtime();
    // Request exact alarm permission first (Android 12+), then schedule.
    final granted =
        await Get.find<NotificationService>().requestExactAlarmPermission();
    debugPrint('[main] exactAlarmPermission granted=$granted');
    // Run off the critical startup path so first frame isn't blocked.
    unawaited(Get.find<NotificationService>().rescheduleAll());
  }

  await WidgetDataProvider.init();
  try {
    await HomeWidget.registerInteractivityCallback(backgroundCallback);
  } catch (e) {
    debugPrint('[main] registerInteractivityCallback failed: $e');
  }
  try {
    await WidgetDataProvider.setAppGroupId('group.HOMEWIDGET');
  } catch (_) {}

  if (Get.find<SupabaseService>().currentUser != null) {
    unawaited(WidgetDataProvider.updateAllWidgets());
    _startPeriodicWidgetRefresh();
    unawaited(_registerBackgroundWidgetRefresh());
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const RevisionTrackerApp());
}

void _startPeriodicWidgetRefresh() {
  _periodicWidgetTimer?.cancel();
  _periodicWidgetTimer = Timer.periodic(const Duration(minutes: 10), (_) {
    if (Get.find<SupabaseService>().currentUser != null) {
      // Fire-and-forget; do not block the timer isolate.
      unawaited(WidgetDataProvider.updateAllWidgets());
    }
  });
}

class RevisionTrackerApp extends StatefulWidget {
  const RevisionTrackerApp({super.key});
  @override
  State<RevisionTrackerApp> createState() => _RevisionTrackerAppState();
}

class _RevisionTrackerAppState extends State<RevisionTrackerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (Get.find<SupabaseService>().currentUser != null) {
        unawaited(WidgetDataProvider.updateAllWidgets());
        unawaited(Get.find<NotificationService>().refreshNotificationPreference());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Get.find<LanguageController>();
    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      locale: lang.locale.value,
      fallbackLocale: const Locale('en'),
      translations: AppTranslations(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLanguages.all.keys.map((c) => Locale(c)).toList(),
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,
      unknownRoute: GetPage(
        name: '/not-found',
        page: () => const MainNavigation(),
      ),
      defaultTransition: Transition.fadeIn,
      transitionDuration: AppConstants.pageTransitionDuration,
    );
  }
}

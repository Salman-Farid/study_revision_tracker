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
  // Heavy chatbot services — create only when first used (mic / voice UI).
  Get.lazyPut<GeminiLiveService>(() => GeminiLiveService(), fenix: true);
  Get.lazyPut<VoiceAssistantController>(() => VoiceAssistantController(), fenix: true);
  Get.put(LanguageController(), permanent: true);
  Get.put(SettingsController(), permanent: true);
  try {
    await Get.putAsync<NotificationService>(
      () => NotificationService().init(),
    ).timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('[main] NotificationService init failed/slow: $e');
    // App must still launch; register lazily on first use.
    Get.put(NotificationService(), permanent: true);
  }

  if (Get.find<SupabaseService>().currentUser != null) {
    Get.find<SupabaseService>().initRealtime();
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

  // Heavy post-login work (alarms, widgets, WorkManager) runs after first frame
  // so splash/home aren't blocked — see _RevisionTrackerAppState.initState.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const RevisionTrackerApp());
}

/// Called once after the first frame: alarms, widgets, WorkManager.
Future<void> _postFrameBoot() async {
  if (Get.find<SupabaseService>().currentUser == null) return;
  try {
    final granted =
        await Get.find<NotificationService>().requestExactAlarmPermission();
    debugPrint('[main] exactAlarmPermission granted=$granted');
  } catch (_) {}
  // Kick native AlarmManager tick so all 3 widgets refresh even if Flutter dies.
  try {
    const channel = MethodChannel('study_revision_tracker/widget_tick');
    await channel.invokeMethod('schedule');
  } catch (e) {
    debugPrint('[main] widget tick channel failed: $e');
  }
  unawaited(Get.find<NotificationService>().rescheduleAll());
  unawaited(WidgetDataProvider.updateAllWidgets());
  _startPeriodicWidgetRefresh();
  unawaited(_registerBackgroundWidgetRefresh());
}

void _startPeriodicWidgetRefresh() {
  _periodicWidgetTimer?.cancel();
  // Refresh widgets more often while app is alive (5 min).
  _periodicWidgetTimer = Timer.periodic(const Duration(minutes: 5), (_) {
    if (Get.find<SupabaseService>().currentUser != null) {
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
    // Defer network/alarm/widget work until after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_postFrameBoot());
    });
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
        preventDuplicates: true,
      ),
      defaultTransition: Transition.fadeIn,
      transitionDuration: AppConstants.pageTransitionDuration,
    );
  }
}

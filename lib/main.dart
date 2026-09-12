import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_revision_tracker/gemini_3_flash_live_voice_chatbot/gemini_chatbot.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app/core/constants/app_constants.dart';
import 'app/core/constants/responsive.dart';
import 'app/core/localization/language_controller.dart';
import 'app/core/localization/app_translations.dart';
import 'app/core/services/connectivity_service.dart';
import 'app/core/services/notification_service.dart';
import 'app/core/services/widget_data_service.dart';
import 'app/core/web/url_strategy_stub.dart'
    if (dart.library.html) 'app/core/web/url_strategy_web.dart';
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

// Native-only imports — never loaded on web (avoids MissingPluginException).
import 'native_boot_stub.dart'
    if (dart.library.io) 'native_boot_io.dart';

Timer? _periodicWidgetTimer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();
  await SharedPreferences.getInstance();

  // Portrait lock is phone-only — web/desktop must rotate/resize freely.
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Supabase persists the session in secure storage (mobile) or
  // localStorage (web). initialize() restores it before we read currentUser.
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
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

  // Local notifications are mobile-only; on web this is a no-op service.
  try {
    await Get.putAsync<NotificationService>(
      () => NotificationService().init(),
    ).timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('[main] NotificationService init failed/slow: $e');
    Get.put(NotificationService(), permanent: true);
  }

  if (Get.find<SupabaseService>().currentUser != null) {
    Get.find<SupabaseService>().initRealtime();
  }

  if (!kIsWeb) {
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

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const RevisionTrackerApp());
}

/// Called once after the first frame: alarms, widgets, WorkManager.
/// No-op on web.
Future<void> _postFrameBoot() async {
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
      if (kIsWeb) return;
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
      builder: (context, child) {
        // Keep Responsive in sync on every rebuild/resize (web window drag).
        Responsive.init(context);
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

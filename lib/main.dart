import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app/core/constants/app_constants.dart';
import 'app/core/constants/responsive.dart';
import 'app/core/localization/language_controller.dart';
import 'app/core/localization/app_translations.dart';
import 'app/core/services/notification_service.dart';
import 'app/core/services/widget_data_service.dart';
import 'app/core/web/url_strategy_stub.dart'
    if (dart.library.html) 'app/core/web/url_strategy_web.dart';
import 'app/core/bootstrap/platform_setup.dart';
import 'app/core/bootstrap/service_registration.dart';
import 'app/core/bootstrap/native_widgets.dart';
import 'app/data/services/supabase_service.dart';
import 'app/modules/navigation/main_navigation.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();
  await SharedPreferences.getInstance();
  await lockPortraitOrientation();

  // Capture the launch URL BEFORE Supabase PKCE exchange can rewrite it.
  // Used to detect password-recovery email links on cold start.
  final Uri launchUri = Uri.base;

  await initSupabaseAndRecovery(launchUri);
  registerAppServices();
  await initNotificationService();
  initRealtimeIfLoggedIn();
  await initNativeWidgets();
  applySystemUiOverlayStyle();

  runApp(const RevisionTrackerApp());
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
      unawaited(postFrameBoot());
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

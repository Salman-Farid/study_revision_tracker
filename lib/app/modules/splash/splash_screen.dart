import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/widget_data_service.dart';
import '../../modules/navigation/navigation_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale, _fade;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: AppConstants.cinematicDuration);
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _c, curve: const Interval(0, 0.5)));
    _c.forward();
    _go();
  }

  Future<void> _go() async {
    // Absolute fail-safe: never leave the user on a blank splash.
    var navigated = false;
    void finish(String route, {String? host}) {
      if (navigated || !mounted) return;
      navigated = true;
      try {
        Get.offAllNamed(route);
        if (host != null) {
          Future.microtask(() {
            try {
              Get.put(NavigationController(), permanent: true).applyHost(host);
            } catch (_) {}
          });
        }
      } catch (_) {
        try {
          Get.offAllNamed(AppRoutes.home);
        } catch (_) {}
      }
    }

    // Force leave splash if anything hangs (deep link, prefs, Supabase).
    Timer(const Duration(seconds: 8), () {
      if (!navigated && mounted) {
        finish(AppRoutes.home);
      }
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Future.delayed(const Duration(milliseconds: 350));
      } else {
        await Future.delayed(const Duration(milliseconds: 700));
      }

      String? linkHost;
      try {
        final initialLink = await WidgetDataProvider.getInitialLink().timeout(
          const Duration(seconds: 2),
        );
        if (initialLink != null) linkHost = initialLink.host;
      } catch (_) {}

      if (user != null) {
        finish(AppRoutes.home, host: linkHost);
        return;
      }

      bool wasLoggedIn = false;
      String? savedEmail;
      try {
        final prefs =
            await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
        wasLoggedIn = prefs.getBool('logged_in') ?? false;
        savedEmail = prefs.getString('user_email');
      } catch (_) {}

      if (wasLoggedIn && savedEmail != null) {
        finish(AppRoutes.home, host: linkHost);
        return;
      }
      finish(AppRoutes.auth);
    } catch (_) {
      finish(AppRoutes.home);
    }
  }

  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(body: Center(
    child: AnimatedBuilder(animation: _c, builder: (_, __) => Opacity(opacity: _fade.value,
      child: Transform.scale(scale: _scale.value,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 80, height: 80, decoration: BoxDecoration(
            color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 42)),
          const SizedBox(height: 24),
          Text(AppConstants.appName, style: AppTextStyles.headlineLarge.copyWith(
            color: AppColors.primary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('startRevisionJourney'.tr, style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textMuted(Theme.of(context).brightness == Brightness.dark))),
        ]))))));
}


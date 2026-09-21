import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/responsive.dart';
import '../../core/services/password_recovery_service.dart';
import '../../core/services/widget_data_service.dart';
import '../../modules/navigation/navigation_controller.dart';
import '../../routes/app_routes.dart';
import 'widgets/splash_feature_orbit.dart';
import 'widgets/splash_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale, _fade;

  /// Desktop / tablet / web: orbit feature loader (breathing ring).
  bool _useOrbitLoader = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: AppConstants.cinematicDuration,
    );
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _c, curve: const Interval(0, 0.5)),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    Responsive.init(context);
    // Phone keeps the cinematic logo; desktop / tablet / web use the orbit.
    _useOrbitLoader = kIsWeb || Responsive.useNavRail;
    if (_useOrbitLoader) {
      // Same orbit UI as HTML boot — no second logo flash.
      unawaited(_go(fast: true));
    } else {
      _c.forward();
      unawaited(_go());
    }
  }

  Future<void> _go({bool fast = false}) async {
    var navigated = false;
    void finish(String route, {String? host}) {
      if (navigated || !mounted) return;
      navigated = true;
      void land() {
        if (!mounted) return;
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

      if (_useOrbitLoader) {
        // Single orbit experience — short hold (~3s) after Flutter paints.
        unawaited(Future<void>.delayed(const Duration(seconds: 3), land));
      } else {
        land();
      }
    }

    if (!fast) {
      Timer(const Duration(seconds: 8), () {
        if (!navigated && mounted) finish(AppRoutes.home);
      });
    }

    try {
      var user = Supabase.instance.client.auth.currentUser;
      if (user == null && !fast) {
        try {
          await Supabase.instance.client.auth.onAuthStateChange
              .first
              .timeout(const Duration(seconds: 2));
          user = Supabase.instance.client.auth.currentUser;
        } catch (_) {}
      } else if (user == null && fast) {
        // Web cold start: session usually hydrates from localStorage during
        // Supabase.initialize — a short poll is enough before Auth.
        try {
          await Supabase.instance.client.auth.onAuthStateChange
              .first
              .timeout(const Duration(milliseconds: 150));
          user = Supabase.instance.client.auth.currentUser;
        } catch (_) {}
        user ??= Supabase.instance.client.auth.currentUser;
      }

      if (!fast) {
        await Future.delayed(
            Duration(milliseconds: user != null ? 350 : 700));
      }

      String? linkHost;
      if (!kIsWeb) {
        try {
          final initialLink =
              await WidgetDataProvider.getInitialLink().timeout(
            const Duration(seconds: 2),
          );
          if (initialLink != null) linkHost = initialLink.host;
        } catch (_) {}
      }

      // Recovery email link → always land on Auth so the new-password
      // dialog can open. Covers PKCE (?recovery=1) and mobile deep link.
      try {
        final recovery = Get.find<PasswordRecoveryService>();
        await recovery.detectInitialRecoveryLink();
        if (recovery.isRecovery.value) {
          finish(AppRoutes.auth);
          return;
        }
      } catch (_) {}

      if (user != null) {
        finish(AppRoutes.home, host: linkHost);
        return;
      }

      if (!fast) {
        bool wasLoggedIn = false;
        String? savedEmail;
        try {
          final prefs = await SharedPreferences.getInstance()
              .timeout(const Duration(seconds: 2));
          wasLoggedIn = prefs.getBool('logged_in') ?? false;
          savedEmail = prefs.getString('user_email');
        } catch (_) {}
        if (wasLoggedIn && savedEmail != null) {
          finish(AppRoutes.home, host: linkHost);
          return;
        }
      }

      finish(AppRoutes.auth);
    } catch (_) {
      finish(fast ? AppRoutes.auth : AppRoutes.home);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_useOrbitLoader) {
      return const Scaffold(
        body: SizedBox.expand(child: SplashFeatureOrbit()),
      );
    }
    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => SplashLogoContent(fade: _fade, scale: _scale),
        ),
      ),
    );
  }
}

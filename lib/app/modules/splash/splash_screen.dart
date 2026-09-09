import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/widget_data_service.dart';
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
    await Future.delayed(const Duration(milliseconds: 1800));
    final user = Supabase.instance.client.auth.currentUser;

    // Determine the deep link target route
    String? targetRoute;
    try {
      final initialLink = await WidgetDataProvider.getInitialLink();
      if (initialLink != null) {
        targetRoute = _resolveDeepLink(initialLink);
      }
    } catch (_) {}

    if (user != null) {
      // Session exists — go straight to home (or deep link target)
      if (targetRoute != null) {
        Get.offAllNamed(targetRoute);
      } else {
        Get.offAllNamed(AppRoutes.home);
      }
      return;
    }
    // No active session — check SharedPreferences for "remember me" login
    final prefs = await SharedPreferences.getInstance();
    final wasLoggedIn = prefs.getBool('logged_in') ?? false;
    final savedEmail = prefs.getString('user_email');
    if (wasLoggedIn && savedEmail != null) {
      // Try to recover session silently; Supabase may have a refresh token stored
      try {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null && !session.isExpired) {
          if (targetRoute != null) {
            Get.offAllNamed(targetRoute);
          } else {
            Get.offAllNamed(AppRoutes.home);
          }
          return;
        }
        // Refresh token might be expired — still go home, user is remembered
        if (targetRoute != null) {
          Get.offAllNamed(targetRoute);
        } else {
          Get.offAllNamed(AppRoutes.home);
        }
        return;
      } catch (_) {
        // Fallback: go home anyway, app will work offline-ish
        if (targetRoute != null) {
          Get.offAllNamed(targetRoute);
        } else {
          Get.offAllNamed(AppRoutes.home);
        }
        return;
      }
    }
    Get.offAllNamed(AppRoutes.auth);
  }

  /// Resolve a deep link URI to a GetX route.
  String? _resolveDeepLink(Uri uri) {
    final path = uri.path;
    if (path.contains('routine')) return AppRoutes.home;
    if (path.contains('today')) return AppRoutes.home;
    if (path.contains('subject')) return AppRoutes.home;
    return AppRoutes.home;
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


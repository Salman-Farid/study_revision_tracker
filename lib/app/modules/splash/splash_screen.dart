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
    await Future.delayed(const Duration(milliseconds: 1800));
    final user = Supabase.instance.client.auth.currentUser;

    // Determine the deep link target route
    String? targetRoute;
    String? linkHost;
    try {
      final initialLink = await WidgetDataProvider.getInitialLink();
      if (initialLink != null) {
        linkHost = initialLink.host;
        targetRoute = _resolveDeepLink(initialLink);
      }
    } catch (_) {}

    void goHomeWithTab() {
      Get.offAllNamed(targetRoute ?? AppRoutes.home);
      // Open the right bottom-nav tab from the widget deep link.
      Future.microtask(() {
        Get.put(NavigationController(), permanent: true).applyHost(linkHost);
      });
    }

    if (user != null) {
      goHomeWithTab();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final wasLoggedIn = prefs.getBool('logged_in') ?? false;
    final savedEmail = prefs.getString('user_email');
    if (wasLoggedIn && savedEmail != null) {
      try {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null && !session.isExpired) {
          goHomeWithTab();
          return;
        }
        goHomeWithTab();
        return;
      } catch (_) {
        goHomeWithTab();
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


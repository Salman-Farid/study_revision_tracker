import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/responsive.dart';
import '../../theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';
import '../dashboard/dashboard_controller.dart';
import '../subjects/subjects_screen.dart';
import '../subjects/subjects_controller.dart';
import '../subject_detail/subject_detail_controller.dart';
import '../today/today_revisions_screen.dart';
import '../today/today_controller.dart';
import '../routine/routine_screen.dart';
import '../routine/routine_controller.dart';
import '../calendar/calendar_screen.dart';
import '../calendar/calendar_controller.dart';
import '../statistics/statistics_screen.dart';
import '../statistics/statistics_controller.dart';
import '../settings/settings_screen.dart';
import '../settings/settings_controller.dart';
import '../settings/about_this_app_panel.dart';
import '../../data/services/supabase_service.dart';
import 'app_side_bar.dart';
import 'navigation_controller.dart';
import 'widgets/desktop_workspace.dart';
import 'widgets/nav_panes.dart';
import 'widgets/phone_nav_shell.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final _nav = Get.put(NavigationController(), permanent: true);
  bool _sidebarExpanded = true;
  bool _sidebarInitialized = false;
  final _pages = const [
    DashboardScreen(),
    SubjectsScreen(),
    TodayRevisionsScreen(),
    RoutineScreen(),
    CalendarScreen(),
    SettingsScreen(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Responsive.init(context);
    // Default to expanded on first wide layout; user toggle is kept after.
    if (!_sidebarInitialized) {
      _sidebarExpanded = Responsive.width >= 1100;
      _sidebarInitialized = true;
    }
  }

  @override
  void initState() {
    super.initState();
    try {
      Get.put(NavigationController(), permanent: true);
      if (!Get.isRegistered<DashboardController>()) {
        Get.put(DashboardController(), permanent: true);
      }
      if (!Get.isRegistered<SubjectsController>()) {
        Get.put(SubjectsController(), permanent: true);
      }
      if (!Get.isRegistered<TodayController>()) {
        Get.put(TodayController(), permanent: true);
      }
      if (!Get.isRegistered<RoutineController>()) {
        Get.put(RoutineController(), permanent: true);
      }
      if (!Get.isRegistered<CalendarController>()) {
        Get.put(CalendarController(), permanent: true);
      }
      if (!Get.isRegistered<HistoryController>()) {
        Get.put(HistoryController(), permanent: true);
      }
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nav.applyInitialWidgetLink();
    });
    ever(_nav.currentIndex, (i) {
      if (i == NavigationController.calendar ||
          i == NavigationController.today) {
        try {
          Get.find<CalendarController>().load(showLoading: false);
        } catch (_) {}
      }
      if (i == NavigationController.dashboard) {
        try {
          if (!Get.isRegistered<HistoryController>()) {
            Get.put(HistoryController(), permanent: true);
          }
          // History pane is always beside Dashboard — keep it live on open.
          Get.find<SupabaseService>().initRealtime();
          Get.find<HistoryController>().load(showLoading: false);
        } catch (_) {}
      }
      if (i == NavigationController.settings) {
        // Profile must reflect the live session every time Settings opens.
        try {
          Get.find<SettingsController>().refreshAccount();
          Get.find<SettingsController>().loadStats();
        } catch (_) {}
      }
    });
  }

  /// Desktop panes (user-specified pairings).
  List<Widget> _panes(int primary) {
    switch (primary) {
      case NavigationController.dashboard:
        return const [DashboardScreen(), HistoryScreen()];
      case NavigationController.subjects:
        return const [SubjectsScreen(), SubjectDetailPane()];
      case NavigationController.today:
        return const [TodayRevisionsScreen(), CalendarScreen()];
      case NavigationController.routine:
        return const [RoutineScreen()];
      case NavigationController.settings:
        return const [SettingsScreen()];
      case NavigationController.calendar:
        return const [TodayRevisionsScreen(), CalendarScreen()];
      default:
        return const [DashboardScreen(), HistoryScreen()];
    }
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    // ── Phone: unchanged bottom-nav shell ──
    if (Responsive.useBottomNav) {
      return PhoneNavShell(nav: _nav, pages: _pages);
    }

    // ── Tablet / Web / Desktop ──
    final d = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppColors.bg(d),
      body: Row(
        children: [
          Obx(() => AppSidebar(
                selectedIndex: _sidebarIndex(_nav.currentIndex.value),
                onSelect: (i) => _nav.goTo(_sidebarToApp(i)),
                expanded: _sidebarExpanded,
                onToggleExpanded: () =>
                    setState(() => _sidebarExpanded = !_sidebarExpanded),
              )),
          Expanded(
            child: Obx(() {
              final tab = _nav.currentIndex.value;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 520),
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) {
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.02, 0.015),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: anim,
                        curve: Curves.easeOutCubic,
                      )),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey('workspace_$tab'),
                  child: _workspace(tab, d),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  int _sidebarIndex(int appIndex) => switch (appIndex) {
        NavigationController.dashboard => 0,
        NavigationController.subjects => 1,
        NavigationController.today || NavigationController.calendar => 2,
        NavigationController.routine => 3,
        NavigationController.settings => 4,
        _ => 0,
      };

  int _sidebarToApp(int railIdx) => switch (railIdx) {
        0 => NavigationController.dashboard,
        1 => NavigationController.subjects,
        2 => NavigationController.today,
        3 => NavigationController.routine,
        _ => NavigationController.settings,
      };

  Widget _workspace(int primary, bool d) {
    final effective = primary == NavigationController.calendar
        ? NavigationController.today
        : primary;

    if (effective == NavigationController.settings) {
      if (Responsive.useSplitLayout) {
        return const SettingsSplitWorkspace();
      }
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.pageMaxWidth),
          child: const SizedBox.expand(child: SettingsScreen()),
        ),
      );
    }

    return DesktopWorkspace(
      primary: effective,
      d: d,
      panesFor: _panes,
    );
  }
}

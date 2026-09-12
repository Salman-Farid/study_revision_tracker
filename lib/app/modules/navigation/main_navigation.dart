import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/responsive.dart';
import '../../data/models/subject_model.dart';
import '../../theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';
import '../dashboard/dashboard_controller.dart';
import '../subjects/subjects_screen.dart';
import '../subjects/subjects_controller.dart';
import '../subject_detail/subject_detail_screen.dart';
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
import 'app_side_bar.dart';
import 'navigation_controller.dart';

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
  ///
  /// Dashboard | History
  /// Subjects  | Subject detail (or empty picker)
  /// Today     | Calendar
  /// Routine   | (full-width dual Daily+Class — no second tab)
  /// Settings  | centered single
  List<Widget> _panes(int primary) {
    switch (primary) {
      case NavigationController.dashboard:
        return const [DashboardScreen(), HistoryScreen()];
      case NavigationController.subjects:
        return const [SubjectsScreen(), _SubjectDetailPane()];
      case NavigationController.today:
        return const [TodayRevisionsScreen(), CalendarScreen()];
      case NavigationController.routine:
        // RoutineScreen itself renders Daily|Class side-by-side when split.
        return const [RoutineScreen()];
      case NavigationController.settings:
        return const [SettingsScreen()];
      case NavigationController.calendar:
        // Calendar is never a primary desktop tab — always pair with Today.
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
      return Scaffold(
        body: Obx(() => IndexedStack(
              index: _nav.currentIndex.value,
              children: _pages,
            )),
        bottomNavigationBar: Obx(() => NavigationBar(
              selectedIndex: _nav.currentIndex.value,
              onDestinationSelected: _nav.goTo,
              animationDuration: const Duration(milliseconds: 200),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard_rounded),
                    label: 'Dashboard'),
                NavigationDestination(
                    icon: Icon(Icons.menu_book_outlined),
                    selectedIcon: Icon(Icons.menu_book_rounded),
                    label: 'Subjects'),
                NavigationDestination(
                    icon: Icon(Icons.today_outlined),
                    selectedIcon: Icon(Icons.today_rounded),
                    label: 'Today'),
                NavigationDestination(
                    icon: Icon(Icons.event_note_outlined),
                    selectedIcon: Icon(Icons.event_note_rounded),
                    label: 'Routine'),
                NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month_rounded),
                    label: 'Calendar'),
                NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings_rounded),
                    label: 'Settings'),
              ],
            )),
      );
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
              // Slow ease-in crossfade when the sidebar tab changes.
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

  /// Sidebar indices skip Calendar (it sits in the Today pane).
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
    // Calendar deep-links land on Today (calendar is a side pane).
    final effective = primary == NavigationController.calendar
        ? NavigationController.today
        : primary;
    final panes = _panes(effective);

    if (effective == NavigationController.settings) {
      // Desktop: Settings list | animated About this app guide.
      if (Responsive.useSplitLayout) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: _PaneFrame(
                  child: const SettingsScreen(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: _PaneFrame(
                  child: const AboutThisAppPanel(),
                ),
              ),
            ],
          ),
        );
      }
      // Tablet mid-width: settings only, centered.
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.pageMaxWidth),
          child: const SizedBox.expand(child: SettingsScreen()),
        ),
      );
    }

    if (panes.length == 1) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: _PaneFrame(showBorder: false, child: panes.first),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Responsive.workspaceMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < panes.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  flex: i == 0 ? 5 : 6,
                  child: _PaneFrame(child: panes[i]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Right pane: selected subject detail, or a picker hint.
class _SubjectDetailPane extends StatelessWidget {
  const _SubjectDetailPane();

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final subjectsCtrl = Get.find<SubjectsController>();
      final subject = subjectsCtrl.selectedSubject;
      if (subject == null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_rounded, size: 48, color: AppColors.textMuted(d)),
                const SizedBox(height: 12),
                Text(
                  'Select a subject',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimary(d),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Topics and revisions open here',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted(d),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return _EmbeddedSubjectDetail(subject: subject);
    });
  }
}

class _EmbeddedSubjectDetail extends StatefulWidget {
  const _EmbeddedSubjectDetail({required this.subject});
  final SubjectModel subject;

  @override
  State<_EmbeddedSubjectDetail> createState() => _EmbeddedSubjectDetailState();
}

class _EmbeddedSubjectDetailState extends State<_EmbeddedSubjectDetail> {
  String? _boundId;

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    if (_boundId != subject.id) {
      _boundId = subject.id;
      if (Get.isRegistered<SubjectDetailController>()) {
        Get.find<SubjectDetailController>().switchSubject(subject);
      } else {
        Get.put(SubjectDetailController(initialSubject: subject));
      }
    }
    if (!Get.isRegistered<SubjectDetailController>()) {
      return const Center(child: CircularProgressIndicator());
    }
    // Key forces a rebuild when the subject changes (title, chips, list).
    return SubjectDetailScreen(key: ValueKey('subject_detail_${subject.id}'));
  }
}

/// Card-like chrome for side-by-side panes.
class _PaneFrame extends StatelessWidget {
  const _PaneFrame({required this.child, this.showBorder = true});

  final Widget child;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    if (!showBorder) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface(d),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(d)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: d ? 0.25 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

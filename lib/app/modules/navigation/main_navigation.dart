import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../dashboard/dashboard_screen.dart';
import '../subjects/subjects_screen.dart';
import '../today/today_revisions_screen.dart';
import '../routine/routine_screen.dart';
import '../calendar/calendar_screen.dart';
import '../settings/settings_screen.dart';
import 'navigation_controller.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final _nav = Get.put(NavigationController(), permanent: true);
  final _pages = const [
    DashboardScreen(), SubjectsScreen(), TodayRevisionsScreen(),
    RoutineScreen(), CalendarScreen(), SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // If opened from a home-widget tap while app was already running.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nav.applyInitialWidgetLink();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() => AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
        child: KeyedSubtree(
          key: ValueKey(_nav.currentIndex.value),
          child: _pages[_nav.currentIndex.value],
        ),
      )),
      bottomNavigationBar: Obx(() => NavigationBar(
        selectedIndex: _nav.currentIndex.value,
        onDestinationSelected: _nav.goTo,
        animationDuration: const Duration(milliseconds: 400),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded), label: 'Subjects'),
          NavigationDestination(icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today_rounded), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note_rounded), label: 'Routine'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      )),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../dashboard/dashboard_screen.dart';
import '../subjects/subjects_screen.dart';
import '../today/today_revisions_screen.dart';
import '../routine/routine_screen.dart';
import '../calendar/calendar_screen.dart';
import '../calendar/calendar_controller.dart';
import '../dashboard/dashboard_controller.dart';
import '../subjects/subjects_controller.dart';
import '../today/today_controller.dart';
import '../routine/routine_controller.dart';
import '../settings/settings_screen.dart';
import 'navigation_controller.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final _nav = Get.put(NavigationController(), permanent: true);
  final _pages = const [
    DashboardScreen(),
    SubjectsScreen(),
    TodayRevisionsScreen(),
    RoutineScreen(),
    CalendarScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Ensure tab controllers exist when opened from a cold widget deep-link
    // (unknownRoute /not-found does not run home bindings).
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
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nav.applyInitialWidgetLink();
    });
    ever(_nav.currentIndex, (i) {
      if (i == NavigationController.calendar) {
        try {
          Get.find<CalendarController>().load(showLoading: false);
        } catch (_) {}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // IndexedStack: one child in the tree at a time — no dual FAB heroes,
    // no GlobalKey collisions, cheaper than rebuilding via AnimatedSwitcher.
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
}

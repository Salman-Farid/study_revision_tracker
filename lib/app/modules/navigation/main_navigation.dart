import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';
import '../subjects/subjects_screen.dart';
import '../today/today_revisions_screen.dart';
import '../calendar/calendar_screen.dart';
import '../settings/settings_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _idx = 0;
  final _pages = const [
    DashboardScreen(), SubjectsScreen(), TodayRevisionsScreen(),
    CalendarScreen(), SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 250),
        transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
        child: _pages[_idx]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx, onDestinationSelected: (i) => setState(() => _idx = i),
        animationDuration: const Duration(milliseconds: 400),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded), label: 'Subjects'),
          NavigationDestination(icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today_rounded), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
        ]),
    );
  }
}

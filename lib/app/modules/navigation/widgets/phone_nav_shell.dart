import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../navigation_controller.dart';

class PhoneNavShell extends StatelessWidget {
  final NavigationController nav;
  final List<Widget> pages;
  const PhoneNavShell({super.key, required this.nav, required this.pages});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() => IndexedStack(
            index: nav.currentIndex.value,
            children: pages,
          )),
      bottomNavigationBar: Obx(() => NavigationBar(
            selectedIndex: nav.currentIndex.value,
            onDestinationSelected: nav.goTo,
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

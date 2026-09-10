import 'package:get/get.dart';

/// Controls the bottom-navigation tab index so dashboard cards
/// and deep links can route to a specific tab.
class NavigationController extends GetxController {
  static NavigationController get to => Get.find<NavigationController>();

  final currentIndex = 0.obs;

  /// Tab indices used by MainNavigation.
  static const int dashboard = 0;
  static const int subjects = 1;
  static const int today = 2;
  static const int routine = 3;
  static const int calendar = 4;
  static const int settings = 5;

  void goTo(int index) {
    if (index < 0 || index > 5) return;
    currentIndex.value = index;
  }

  void goToDashboard() => goTo(dashboard);
  void goToSubjects() => goTo(subjects);
  void goToToday() => goTo(today);
  void goToRoutine() => goTo(routine);
  void goToCalendar() => goTo(calendar);
  void goToSettings() => goTo(settings);
}

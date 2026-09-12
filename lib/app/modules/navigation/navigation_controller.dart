import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/constants/responsive.dart';

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

  /// Calendar is a side pane of Today on desktop — never a primary tab there.
  void goToCalendar() {
    if (Responsive.useSplitLayout) {
      goTo(today);
      return;
    }
    goTo(calendar);
  }

  void goToSettings() => goTo(settings);

  /// Map widget/deep-link hosts to a tab.
  /// Class + daily routine widgets → Routine tab.
  void applyHost(String? host) {
    switch (host) {
      case 'routine':
      case 'class':
      case 'daily':
        goToRoutine();
        break;
      case 'today':
      case 'revision':
        goToToday();
        break;
      case 'calendar':
        goToCalendar();
        break;
      case 'subjects':
        goToSubjects();
        break;
      default:
        break;
    }
  }

  /// Read the launch URI from a home-widget tap and open the right tab.
  /// Never throws — worst case stays on the current tab.
  /// On web there are no home widgets; parse the browser URL instead.
  Future<void> applyInitialWidgetLink() async {
    if (kIsWeb) {
      try {
        final host = Uri.base.host; // e.g. /today after path URL strategy
        final path = Uri.base.path;
        if (path.contains('today') || host == 'today') goToToday();
        if (path.contains('routine') || host == 'routine') goToRoutine();
        if (path.contains('calendar') || host == 'calendar') goToCalendar();
        if (path.contains('subjects') || host == 'subjects') goToSubjects();
      } catch (_) {}
      return;
    }
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget()
          .timeout(const Duration(seconds: 2));
      if (uri != null) {
        applyHost(uri.host);
      }
    } catch (_) {}
  }
}

import 'package:get/get.dart';
import '../modules/splash/splash_screen.dart';
import '../modules/auth/auth_screen.dart';
import '../modules/auth/auth_binding.dart';
import '../modules/navigation/main_navigation.dart';
import '../modules/subject_detail/subject_detail_screen.dart';
import '../modules/subject_detail/subject_detail_binding.dart';
import '../modules/topic_detail/topic_detail_screen.dart';
import '../modules/topic_detail/topic_detail_binding.dart';
import '../modules/statistics/statistics_screen.dart';
import '../modules/statistics/statistics_binding.dart';
import '../modules/settings/settings_screen.dart';
import '../modules/calendar/calendar_screen.dart';
import '../modules/calendar/calendar_binding.dart';
import '../modules/dashboard/dashboard_binding.dart';
import '../modules/subjects/subjects_binding.dart';
import '../modules/today/today_binding.dart';
import '../modules/routine/routine_binding.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(name: AppRoutes.splash, page: () => const SplashScreen()),
    GetPage(name: AppRoutes.auth, page: () => const AuthScreen(), binding: AuthBinding()),
    GetPage(name: AppRoutes.home, page: () => const MainNavigation(),
      bindings: [DashboardBinding(), SubjectsBinding(), TodayBinding(), RoutineBinding(), CalendarBinding()]),
    GetPage(name: AppRoutes.subjectDetail, page: () => const SubjectDetailScreen(),
      binding: SubjectDetailBinding()),
    GetPage(name: AppRoutes.topicDetail, page: () => const TopicDetailScreen(),
      binding: TopicDetailBinding()),
    GetPage(name: AppRoutes.history, page: () => const HistoryScreen(),
      binding: HistoryBinding()),
    GetPage(name: AppRoutes.settings, page: () => const SettingsScreen()),
    GetPage(name: AppRoutes.calendar, page: () => const CalendarScreen()),
  ];
}

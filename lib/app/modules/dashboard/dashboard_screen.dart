import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/responsive.dart';
import '../../core/constants/size_constants.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';
import '../navigation/navigation_controller.dart';
import 'dashboard_controller.dart';
import 'widgets/daily_routine_live_card.dart';
import 'widgets/dashboard_cards.dart';
import 'widgets/dashboard_header.dart';

class DashboardScreen extends GetView<DashboardController> {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(body: SafeArea(child: Obx(() {
      if (controller.isLoading.value) return DashboardShimmerLoader(d: d);
      return RefreshIndicator(onRefresh: controller.load,
        child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), slivers: [
          SliverToBoxAdapter(child: DashboardHeader(d: d, greeting: _greeting())),
          SliverToBoxAdapter(child: DashboardHeroCard(
            d: d,
            today: controller.stats['today_count'] ?? 0,
            overdue: controller.stats['overdue_count'] ?? 0,
            onStartRevising: controller.startRevising,
          )),
          SliverToBoxAdapter(child: DailyRoutineLiveCard(d: d, controller: controller)),
          SliverToBoxAdapter(child: _statsGrid(d)),
          SliverToBoxAdapter(child: DashboardQuickActions(
            d: d,
            onOpenHistory: () => Get.toNamed(AppRoutes.history),
          )),
          SliverPadding(padding: EdgeInsets.only(bottom: S.xxxl)),
        ]));
    })));
  }

  Widget _statsGrid(bool d) {
    final rate = (controller.stats['completion_rate'] as num?)?.toDouble() ?? 0;
    final items = [
      ['statOverdue'.tr, '${controller.stats['overdue_count'] ?? 0}', Icons.warning_rounded, AppColors.error, _goToday],
      ['statToday'.tr, '${controller.stats['today_count'] ?? 0}', Icons.today_rounded, AppColors.primary, _goToday],
      ['statUpcoming'.tr, '${controller.stats['upcoming_count'] ?? 0}', Icons.upcoming_rounded, AppColors.info, _goCalendar],
      ['statCompletion'.tr, '${(rate * 100).round()}%', Icons.check_circle_rounded, AppColors.success, _goSubjects],
    ];
    return Padding(
      padding: EdgeInsets.all(S.xl),
      child: GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          // Split panes stay 2-wide; full-width tablet/web mid uses 4.
          crossAxisCount: Responsive.useSplitLayout
              ? 2
              : (Responsive.width >= Responsive.mobileBreak ? 4 : 2),
          crossAxisSpacing: S.gridSpacing,
          mainAxisSpacing: S.gridSpacing,
          // Fixed height avoids pixel overflow on smaller screens.
          mainAxisExtent: S.statCardMinHeight + 12,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final it = items[i];
          return StatCard(
            title: it[0] as String,
            value: it[1] as String,
            icon: it[2] as IconData,
            color: it[3] as Color,
            onTap: it[4] as VoidCallback,
          );
        },
      ),
    );
  }

  void _goToday() => NavigationController.to.goToToday();
  void _goCalendar() => NavigationController.to.goToCalendar();
  void _goSubjects() => NavigationController.to.goToSubjects();

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'goodMorning'.tr; if (h < 17) return 'goodAfternoon'.tr; return 'goodEvening'.tr;
  }
}

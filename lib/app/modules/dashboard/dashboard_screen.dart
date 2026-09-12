import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/responsive.dart';
import '../../core/constants/size_constants.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';
import '../navigation/navigation_controller.dart';
import 'dashboard_controller.dart';

class DashboardScreen extends GetView<DashboardController> {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(body: SafeArea(child: Obx(() {
      if (controller.isLoading.value) return _shimmerLoader(d);
      return RefreshIndicator(onRefresh: controller.load,
        child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()), slivers: [
          SliverToBoxAdapter(child: _header(d)),
          SliverToBoxAdapter(child: _heroCard(d)),
          SliverToBoxAdapter(child: _statsGrid(d)),
          SliverToBoxAdapter(child: _actions(d)),
          SliverPadding(padding: EdgeInsets.only(bottom: S.xxxl)),
        ]));
    })));
  }

  // ─── SHIMMER LOADER ─────────────────────────────────────────
  Widget _shimmerLoader(bool d) {
    final baseColor = d ? const Color(0xFF2D3140) : const Color(0xFFE8ECF4);
    final highlightColor = d ? const Color(0xFF3D4250) : const Color(0xFFF0F3F8);
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(S.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header shimmer
            Row(children: [
              Container(width: S.avatarSize, height: S.avatarSize,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusMd))),
              SizedBox(width: S.md),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(height: 12, width: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
                SizedBox(height: S.sm),
                Container(height: 16, width: 160, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
              ])),
            ]),
            SizedBox(height: S.lg),
            // Hero card shimmer
            Container(width: double.infinity, height: 140,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusLg))),
            SizedBox(height: S.lg),
            // Stats grid shimmer
            GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, crossAxisSpacing: S.gridSpacing, mainAxisSpacing: S.gridSpacing, childAspectRatio: 1.25,
              children: List.generate(4, (_) => Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusLg))))),
            SizedBox(height: S.lg),
            // Actions shimmer
            Container(height: 16, width: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
            SizedBox(height: S.md),
            Container(height: 64, width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusMd))),
          ],
        ),
      ),
    );
  }

  Widget _header(bool d) => Padding(padding: EdgeInsets.fromLTRB(S.xl, S.xl, S.xl, S.sm),
    child: Row(children: [
      Container(width: S.avatarSize, height: S.avatarSize, decoration: BoxDecoration(
        gradient:  LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
        borderRadius: BorderRadius.circular(S.radiusMd)),
        child: Icon(Icons.person, color: Colors.white, size: S.iconLg)),
      SizedBox(width: S.md),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_greeting(), style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d))),
        Text('smartRevisionTracker'.tr, style: AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimary(d))),
      ])),
    ]));

  // White hero card, no elevation, black/colored text with icons.
  Widget _heroCard(bool d) {
    final today = controller.stats['today_count'] ?? 0;
    final overdue = controller.stats['overdue_count'] ?? 0;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: S.xl, vertical: S.md),
      padding: EdgeInsets.all(S.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(S.radiusLg),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.auto_stories_rounded, color: AppColors.primary, size: S.iconLg),
          SizedBox(width: S.md),
          Expanded(
            child: Text(
              today > 0 ? 'revisionsDueToday'.tr.replaceAll('{n}', '$today') : 'noRevisionsDueToday'.tr,
              style: AppTextStyles.headlineSmall.copyWith(
                color: AppColors.textPrimaryLight,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
        if (overdue > 0) ...[
          SizedBox(height: S.md),
          Container(
            padding: EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(S.radiusSm),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.warning_rounded, color: AppColors.error, size: S.iconSm),
              SizedBox(width: S.sm),
              Text(
                'overdueBadge'.tr.replaceAll('{n}', '$overdue'),
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.error),
              ),
            ]),
          ),
        ],
        SizedBox(height: S.base),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: controller.startRevising,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: Text('startRevising'.tr),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: Size(double.infinity, S.buttonHeight * 0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(S.radiusMd),
              ),
            ),
          ),
        ),
      ]),
    );
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

  Widget _actions(bool d) => Padding(padding: EdgeInsets.symmetric(horizontal: S.xl, vertical: S.md),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('quickActions'.tr, style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary(d))),
      SizedBox(height: S.md),
      Material(color: Colors.transparent, child: InkWell(onTap: () => Get.toNamed(AppRoutes.history),
        borderRadius: BorderRadius.circular(S.radiusMd),
        child: Container(padding: EdgeInsets.all(S.base),
          decoration: BoxDecoration(border: Border.all(color: AppColors.border(d)),
            borderRadius: BorderRadius.circular(S.radiusMd)),
          child: Row(children: [
            Container(padding: EdgeInsets.all(S.md), decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(S.radiusMd)),
              child: Icon(Icons.bar_chart_rounded, color: AppColors.success, size: S.iconMd)),
            SizedBox(width: S.base),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('history'.tr, style: AppTextStyles.titleSmall.copyWith(color: AppColors.textPrimary(d))),
              Text('viewProgressAnalytics'.tr, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d))),
            ])),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted(d)),
          ])))),
    ]));

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'goodMorning'.tr; if (h < 17) return 'goodAfternoon'.tr; return 'goodEvening'.tr;
  }
}

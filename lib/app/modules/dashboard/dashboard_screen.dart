import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/size_constants.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';
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
        Text('Smart Revision Tracker', style: AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimary(d))),
      ])),
    ]));

  // Bug-06 FIX: Frosted glass hero card using ClipRRect + BackdropFilter.
  Widget _heroCard(bool d) {
    final today = controller.stats['today_count'] ?? 0;
    final overdue = controller.stats['overdue_count'] ?? 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(S.radiusLg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: S.xl, vertical: S.md),
          padding: EdgeInsets.all(S.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [
                const Color(0xFF6C63FF).withValues(alpha: 0.88),
                const Color(0xFF9D97FF).withValues(alpha: 0.88),
              ]),
            borderRadius: BorderRadius.circular(S.radiusLg),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
            boxShadow: [
              BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.25),
                blurRadius: 20, offset: const Offset(0, 8)),
            ]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(today > 0 ? '$today revision${today > 1 ? 's' : ''} due today' : 'No revisions due today',
              style: AppTextStyles.headlineSmall.copyWith(color: Colors.white)),
            if (overdue > 0) ...[SizedBox(height: S.sm),
              Container(padding: EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(S.radiusSm)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.warning_rounded, color: Colors.white, size: S.iconSm), SizedBox(width: S.sm),
                  Text('$overdue overdue', style: AppTextStyles.labelLarge.copyWith(color: Colors.white)),
                ])),
            ],
            SizedBox(height: S.base),
            ElevatedButton(onPressed: controller.startRevising,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, foregroundColor: AppColors.primary,
                minimumSize: Size(S.avatarSize * 2, S.buttonHeight * 0.75)),
child: const Text('Start Revising')),
          ]))));
  }

  Widget _statsGrid(bool d) {
    final rate = (controller.stats['completion_rate'] as num?)?.toDouble() ?? 0;
    final items = [
      ['Overdue', '${controller.stats['overdue_count'] ?? 0}', Icons.warning_rounded, AppColors.error],
      ['Today', '${controller.stats['today_count'] ?? 0}', Icons.today_rounded, AppColors.primary],
      ['Upcoming', '${controller.stats['upcoming_count'] ?? 0}', Icons.upcoming_rounded, AppColors.info],
      ['Completion', '${(rate * 100).round()}%', Icons.check_circle_rounded, AppColors.success],
    ];
    return Padding(
      padding: EdgeInsets.all(S.xl),
      child: GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: S.gridSpacing,
          mainAxisSpacing: S.gridSpacing,
          childAspectRatio: 1.25,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final it = items[i];
          return StatCard(
            title: it[0] as String,
            value: it[1] as String,
            icon: it[2] as IconData,
            color: it[3] as Color,
          );
        },
      ),
    );
  }

  Widget _actions(bool d) => Padding(padding: EdgeInsets.symmetric(horizontal: S.xl, vertical: S.md),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Quick Actions', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary(d))),
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
              Text('History', style: AppTextStyles.titleSmall.copyWith(color: AppColors.textPrimary(d))),
              Text('View progress and analytics', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d))),
            ])),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted(d)),
          ])))),
    ]));

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning'; if (h < 17) return 'Good Afternoon'; return 'Good Evening';
  }
}

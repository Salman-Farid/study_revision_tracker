import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';

class DashboardHeroCard extends StatelessWidget {
  final bool d;
  final int today;
  final int overdue;
  final VoidCallback onStartRevising;
  const DashboardHeroCard({
    super.key,
    required this.d,
    required this.today,
    required this.overdue,
    required this.onStartRevising,
  });

  @override
  Widget build(BuildContext context) {
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
            onPressed: onStartRevising,
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
}

class DashboardQuickActions extends StatelessWidget {
  final bool d;
  final VoidCallback onOpenHistory;
  const DashboardQuickActions({super.key, required this.d, required this.onOpenHistory});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: EdgeInsets.symmetric(horizontal: S.xl, vertical: S.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('quickActions'.tr, style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary(d))),
        SizedBox(height: S.md),
        Material(color: Colors.transparent, child: InkWell(onTap: onOpenHistory,
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
  }
}

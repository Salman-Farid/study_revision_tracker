import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';

class StreakCard extends StatelessWidget {
  final bool d;
  final int streak;
  const StreakCard({super.key, required this.d, required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(S.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(S.radiusXl),
        border: Border.all(color: AppColors.borderLight, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(S.md),
            decoration: BoxDecoration(
              color: (streak > 0 ? const Color(0xFFFF6B35) : AppColors.primary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(S.radiusLg),
            ),
            child: Icon(
              streak > 0 ? Icons.local_fire_department_rounded : Icons.menu_book_rounded,
              color: streak > 0 ? const Color(0xFFFF6B35) : AppColors.primary,
              size: S.iconXl,
            ),
          ),
          SizedBox(width: S.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak > 0 ? 'dayStreak'.tr.replaceAll('{n}', '$streak') : 'startYourStreak'.tr,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: S.xs),
                Text(
                  streak > 0 ? 'keepMomentum'.tr : 'reviseToday'.tr,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: S.avatarSize * 1.35,
            height: S.avatarSize * 1.35,
            decoration: BoxDecoration(
              color: (streak > 0 ? const Color(0xFFFF6B35) : AppColors.primary)
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$streak',
                style: AppTextStyles.headlineLarge.copyWith(
                  color: streak > 0 ? const Color(0xFFFF6B35) : AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatisticsEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool d;
  const StatisticsEmptyState({super.key, required this.title, required this.subtitle, required this.d});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(S.xl),
      decoration: BoxDecoration(
        color: AppColors.surface(d),
        borderRadius: BorderRadius.circular(S.radiusLg),
        border: Border.all(color: AppColors.border(d)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.hourglass_empty_rounded,
            size: S.iconXxl,
            color: AppColors.textMuted(d),
          ),
          SizedBox(height: S.md),
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textSecondary(d),
            ),
          ),
          SizedBox(height: S.xs),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted(d),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';
import 'statistics_streak_card.dart';

class InsightItem {
  final String title, description;
  final IconData icon;
  final Color color;
  InsightItem(this.title, this.description, this.icon, this.color);
}

class StatisticsInsights extends StatelessWidget {
  final bool d;
  final double rate;
  final int totalRevisions;
  final int planned;
  final int thisWeek;
  final int streak;
  const StatisticsInsights({
    super.key,
    required this.d,
    required this.rate,
    required this.totalRevisions,
    required this.planned,
    required this.thisWeek,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final insights = <InsightItem>[];

    // Performance rating
    if (rate >= 0.8) {
      insights.add(InsightItem(
        'keepMomentum'.tr,
        'doneOfTotal'.tr.replaceAll('{done}', '$totalRevisions').replaceAll('{total}', '$planned') +
            ' — ${(rate * 100).round()}%',
        Icons.emoji_events_rounded,
        AppColors.success,
      ));
    } else if (rate >= 0.5) {
      insights.add(InsightItem(
        'statCompletion'.tr,
        'doneOfTotal'.tr.replaceAll('{done}', '$totalRevisions').replaceAll('{total}', '$planned') +
            ' — ${(rate * 100).round()}%',
        Icons.trending_up_rounded,
        AppColors.info,
      ));
    } else {
      insights.add(InsightItem(
        'startYourStreak'.tr,
        'doneOfTotal'.tr.replaceAll('{done}', '$totalRevisions').replaceAll('{total}', '$planned'),
        Icons.psychology_rounded,
        AppColors.warning,
      ));
    }

    // Weekly activity (real completed revisions this week)
    if (thisWeek > 0) {
      insights.add(InsightItem(
        'weeklyActivity'.tr,
        'revisionsOfDone'.tr.replaceAll('{n}', '$thisWeek'),
        Icons.local_fire_department_rounded,
        const Color(0xFFFF6B35),
      ));
    }

    // Streak
    if (streak > 1) {
      insights.add(InsightItem(
        'dayStreak'.tr.replaceAll('{n}', '$streak'),
        'keepMomentum'.tr,
        Icons.local_fire_department_rounded,
        const Color(0xFFFF6B35),
      ));
    }

    if (insights.isEmpty) {
      return StatisticsEmptyState(title: 'noInsightsYet'.tr, subtitle: 'insightsEmptySub'.tr, d: d);
    }

    return Column(
      children: insights.map((insight) {
        return Container(
          margin: EdgeInsets.only(bottom: S.md),
          padding: EdgeInsets.all(S.base),
          decoration: BoxDecoration(
            color: AppColors.surface(d),
            borderRadius: BorderRadius.circular(S.radiusLg),
            border: Border.all(color: AppColors.border(d)),
            boxShadow: S.shadowSm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(S.sm),
                decoration: BoxDecoration(
                  color: insight.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(S.radiusMd),
                ),
                child: Icon(insight.icon, color: insight.color, size: S.iconMd),
              ),
              SizedBox(width: S.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.title,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.textPrimary(d),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      insight.description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted(d),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

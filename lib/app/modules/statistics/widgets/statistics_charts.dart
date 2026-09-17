import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import '../../../core/constants/responsive.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';
import 'statistics_streak_card.dart';

/// Real revision-weighted progress per subject card: e.g. "1/30 revisions
/// • 5 topics" with the % computed from actual completed revisions.
class SubjectProgressList extends StatelessWidget {
  final bool d;
  final List data;
  const SubjectProgressList({super.key, required this.d, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return StatisticsEmptyState(title: 'noSubjectsProgress'.tr, subtitle: 'addSubjectsProgress'.tr, d: d);
    }
    return Column(
      children: data.map((item) {
        final subject = item['subject'];
        final total = item['total'] as int;
        final revDone = item['revisionsDone'] as int;
        final revPlanned = item['revisionsPlanned'] as int;
        final progress = item['progress'] as double;
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
            children: [
              // Subject color circle
              Container(
                width: S.avatarSize,
                height: S.avatarSize,
                decoration: BoxDecoration(
                  color: subject.color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  IconData(subject.iconCodePoint, fontFamily: 'MaterialIcons'),
                  color: subject.color,
                  size: S.iconMd,
                ),
              ),
              SizedBox(width: S.md),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.textPrimary(d),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    // Real revision counts: "1/30 revisions • 5 topics"
                    Text(
                      '$revDone/$revPlanned ${'revisionsLabel'.tr} • ${'topicsLabel'.tr.replaceAll('{n}', '$total')}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted(d),
                      ),
                    ),
                    SizedBox(height: S.sm),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(S.radiusFull),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: AppColors.border(d),
                        valueColor: AlwaysStoppedAnimation(subject.color),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: S.md),
              // Percentage
              Container(
                padding: EdgeInsets.symmetric(horizontal: S.sm, vertical: S.xs),
                decoration: BoxDecoration(
                  color: subject.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(S.radiusSm),
                ),
                child: Text(
                  '${(progress * 100).round()}%',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: subject.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class WeeklyActivityChart extends StatelessWidget {
  final bool d;
  final List<int> activity;
  const WeeklyActivityChart({super.key, required this.d, required this.activity});

  @override
  Widget build(BuildContext context) {
    // REAL data: completed revisions per weekday (Mon→Sun) this week.
    final today = DateTime.now().weekday - 1;
    final maxY = <int>[3, ...activity].reduce((a, b) => a > b ? a : b).toDouble();
    final spots = List.generate(7, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: activity[i].toDouble(),
            color: i <= today
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.3),
            width: Responsive.isTablet ? 28 : 20,
            borderRadius: BorderRadius.vertical(top: Radius.circular(S.radiusSm)),
          ),
        ],
      );
    });

    return Container(
      height: S.chartHeight,
      padding: EdgeInsets.all(S.base),
      decoration: BoxDecoration(
        color: AppColors.surface(d),
        borderRadius: BorderRadius.circular(S.radiusLg),
        border: Border.all(color: AppColors.border(d)),
        boxShadow: S.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: S.sm),
              Text(
                'thisWeek'.tr,
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textMuted(d),
                ),
              ),
            ],
          ),
          SizedBox(height: S.md),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                        final idx = v.toInt() % 7;
                        final isToday = idx == today;
                        return Text(
                          days[idx],
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isToday
                                ? AppColors.primary
                                : AppColors.textMuted(d),
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: AppColors.border(d).withOpacity(0.5),
                    strokeWidth: 1,
                  ),
                ),
                barGroups: spots,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

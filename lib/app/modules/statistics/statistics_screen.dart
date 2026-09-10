import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/responsive.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';
import 'statistics_controller.dart';

class HistoryScreen extends GetView<HistoryController> {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text('history'.tr, style: AppTextStyles.headlineMedium),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppColors.textMuted(d)),
            onPressed: controller.load,
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return _shimmerLoader(d);
        }
        return RefreshIndicator(
          onRefresh: controller.load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: EdgeInsets.all(S.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _streakCard(d),
                SizedBox(height: S.xl),
                _sectionTitle('overview'.tr, d),
                SizedBox(height: S.base),
                _statsGrid(d),
                SizedBox(height: S.xxl),
                _sectionTitle('subjectProgress'.tr, d),
                SizedBox(height: S.base),
                _subjectProgressList(d),
                SizedBox(height: S.xxl),
                _sectionTitle('weeklyActivity'.tr, d),
                SizedBox(height: S.base),
                _weeklyChart(d),
                SizedBox(height: S.xxl),
                _sectionTitle('performanceInsights'.tr, d),
                SizedBox(height: S.base),
                _insights(d),
                SizedBox(height: S.xxxl),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ─── SHIMMER LOADER ──────────────────────────────────────────
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
            // Streak card shimmer
            Container(width: double.infinity, height: S.streakCardHeight,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusXl))),
            SizedBox(height: S.xl),
            // Overview title
            Container(height: 18, width: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9))),
            SizedBox(height: S.base),
            // Stats grid shimmer
            GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, crossAxisSpacing: S.gridSpacing, mainAxisSpacing: S.gridSpacing,
              childAspectRatio: S.statCardAspectRatio,
              children: List.generate(4, (_) => Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusLg))))),
            SizedBox(height: S.xxl),
            // Subject Progress title
            Container(height: 18, width: 130, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9))),
            SizedBox(height: S.base),
            // Subject progress shimmer items
            ...List.generate(3, (_) => Container(
              margin: EdgeInsets.only(bottom: S.md), height: 72, width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusLg)))),
            SizedBox(height: S.xxl),
            // Mastery title
            Container(height: 18, width: 140, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9))),
            SizedBox(height: S.base),
            // Mastery chart shimmer
            Container(width: double.infinity, height: S.chartHeight + S.xxxl,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusLg))),
            SizedBox(height: S.xxl),
            // Weekly title
            Container(height: 18, width: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9))),
            SizedBox(height: S.base),
            // Weekly chart shimmer
            Container(width: double.infinity, height: S.chartHeight,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusLg))),
            SizedBox(height: S.xxl),
            // Insights title
            Container(height: 18, width: 150, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9))),
            SizedBox(height: S.base),
            // Insight items shimmer
            ...List.generate(3, (_) => Container(
              margin: EdgeInsets.only(bottom: S.md), height: 64, width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusLg)))),
          ],
        ),
      ),
    );
  }

  // ─── STREAK CARD ──────────────────────────────────────────────
  Widget _streakCard(bool d) {
    final streak = controller.streakDays.value;
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

  // ─── SECTION TITLE ────────────────────────────────────────────
  Widget _sectionTitle(String title, bool d) {
    return Text(
      title,
      style: AppTextStyles.headlineSmall.copyWith(
        color: AppColors.textPrimary(d),
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // ─── STATS GRID ───────────────────────────────────────────────
  // All values are REAL: revision-weighted completion (X of Y), completed
  // revision count, topics and subjects straight from the database.
  Widget _statsGrid(bool d) {
    final done = controller.revisionsDone.value;
    final planned = controller.revisionsTotal.value;
    final items = [
      _StatItem('statCompletion'.tr,
          planned == 0 ? '0%' : '${(controller.completionFraction * 100).round()}%',
          Icons.check_circle_rounded, AppColors.success,
          subtitle: 'doneOfTotal'.tr
              .replaceAll('{done}', '$done')
              .replaceAll('{total}', '$planned')),
      _StatItem('revisionsDone'.tr, '$done',
          Icons.done_all_rounded, AppColors.primary,
          subtitle: '$done/$planned'),
      _StatItem('statTotalTopics'.tr, '${controller.totalTopics.value}',
          Icons.topic_rounded, AppColors.info,
          subtitle: '${controller.completedTopics.value}/${controller.totalTopics.value}'),
      _StatItem('statSubjects'.tr, '${controller.totalSubjects.value}',
          Icons.book_rounded, AppColors.warning),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: S.gridSpacing,
      mainAxisSpacing: S.gridSpacing,
      // Fixed taller extent so localized text + subtitles never overflow.
      mainAxisExtent: S.statCardMinHeight + 24,
      children: items
          .map((item) => StatCard(
                title: item.title,
                value: item.value,
                icon: item.icon,
                color: item.color,
                subtitle: item.subtitle,
              ))
          .toList(),
    );
  }

  // ─── SUBJECT PROGRESS ─────────────────────────────────────────
  // Real revision-weighted progress per subject card: e.g. "1/30 revisions
  // • 5 topics" with the % computed from actual completed revisions.
  Widget _subjectProgressList(bool d) {
    final data = controller.subjectProgress;
    if (data.isEmpty) {
      return _emptyState('noSubjectsProgress'.tr, 'addSubjectsProgress'.tr, d);
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

  // ─── WEEKLY CHART ─────────────────────────────────────────────
  Widget _weeklyChart(bool d) {
    // REAL data: completed revisions per weekday (Mon→Sun) this week.
    final activity = controller.weeklyActivity.toList();
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

  // ─── INSIGHTS ─────────────────────────────────────────────────
  // All insights are computed from REAL revision-weighted data.
  Widget _insights(bool d) {
    final rate = controller.completionFraction;
    final totalRevisions = controller.revisionsDone.value;
    final planned = controller.revisionsTotal.value;
    final thisWeek = controller.weeklyActivity.fold<int>(0, (a, b) => a + b);
    final streak = controller.streakDays.value;

    final insights = <_InsightItem>[];

    // Performance rating
    if (rate >= 0.8) {
      insights.add(_InsightItem(
        'keepMomentum'.tr,
        'doneOfTotal'.tr.replaceAll('{done}', '$totalRevisions').replaceAll('{total}', '$planned') +
            ' — ${(rate * 100).round()}%',
        Icons.emoji_events_rounded,
        AppColors.success,
      ));
    } else if (rate >= 0.5) {
      insights.add(_InsightItem(
        'statCompletion'.tr,
        'doneOfTotal'.tr.replaceAll('{done}', '$totalRevisions').replaceAll('{total}', '$planned') +
            ' — ${(rate * 100).round()}%',
        Icons.trending_up_rounded,
        AppColors.info,
      ));
    } else {
      insights.add(_InsightItem(
        'startYourStreak'.tr,
        'doneOfTotal'.tr.replaceAll('{done}', '$totalRevisions').replaceAll('{total}', '$planned'),
        Icons.psychology_rounded,
        AppColors.warning,
      ));
    }

    // Weekly activity (real completed revisions this week)
    if (thisWeek > 0) {
      insights.add(_InsightItem(
        'weeklyActivity'.tr,
        'revisionsOfDone'.tr.replaceAll('{n}', '$thisWeek'),
        Icons.local_fire_department_rounded,
        const Color(0xFFFF6B35),
      ));
    }

    // Streak
    if (streak > 1) {
      insights.add(_InsightItem(
        'dayStreak'.tr.replaceAll('{n}', '$streak'),
        'keepMomentum'.tr,
        Icons.local_fire_department_rounded,
        const Color(0xFFFF6B35),
      ));
    }

    if (insights.isEmpty) {
      return _emptyState('noInsightsYet'.tr, 'insightsEmptySub'.tr, d);
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

  // ─── EMPTY STATE ──────────────────────────────────────────────
  Widget _emptyState(String title, String subtitle, bool d) {
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

// ─── DATA MODELS ────────────────────────────────────────────────

class _StatItem {
  final String title, value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  _StatItem(this.title, this.value, this.icon, this.color, {this.subtitle});
}

class _InsightItem {
  final String title, description;
  final IconData icon;
  final Color color;
  _InsightItem(this.title, this.description, this.icon, this.color);
}

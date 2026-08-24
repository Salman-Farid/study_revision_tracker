import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
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
        title: Text('History', style: AppTextStyles.headlineMedium),
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
                _sectionTitle('Overview', d),
                SizedBox(height: S.base),
                _statsGrid(d),
                SizedBox(height: S.xxl),
                _sectionTitle('Subject Progress', d),
                SizedBox(height: S.base),
                _subjectProgressList(d),
                SizedBox(height: S.xxl),
                _sectionTitle('Mastery Breakdown', d),
                SizedBox(height: S.base),
                _masteryChart(d),
                SizedBox(height: S.xxl),
                _sectionTitle('Weekly Activity', d),
                SizedBox(height: S.base),
                _weeklyChart(d),
                SizedBox(height: S.xxl),
                _sectionTitle('Performance Insights', d),
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
            Container(width: double.infinity, height: 110,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusXl))),
            SizedBox(height: S.xl),
            // Overview title
            Container(height: 18, width: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9))),
            SizedBox(height: S.base),
            // Stats grid shimmer
            GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, crossAxisSpacing: S.gridSpacing, mainAxisSpacing: S.gridSpacing, childAspectRatio: 1.3,
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
            Container(width: double.infinity, height: 250,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(S.radiusLg))),
            SizedBox(height: S.xxl),
            // Weekly title
            Container(height: 18, width: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9))),
            SizedBox(height: S.base),
            // Weekly chart shimmer
            Container(width: double.infinity, height: 220,
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: streak > 0
              ? [const Color(0xFFFF6B35), const Color(0xFFFF8E53)]
              : [AppColors.primary, AppColors.primary.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(S.radiusXl),
        boxShadow: [
          BoxShadow(
            color: (streak > 0 ? const Color(0xFFFF6B35) : AppColors.primary).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Flame icon
          Container(
            padding: EdgeInsets.all(S.md),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(S.radiusLg),
            ),
            child: Text(
              streak > 0 ? '🔥' : '📚',
              style: TextStyle(fontSize: S.iconXxl),
            ),
          ),
          SizedBox(width: S.lg),
          // Streak info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  streak > 0 ? '$streak Day Streak!' : 'Start Your Streak',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: S.xs),
                Text(
                  streak > 0
                      ? 'Keep the momentum going!'
                      : 'Revise today to build consistency',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
          // Streak number
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$streak',
                style: AppTextStyles.headlineLarge.copyWith(
                  color: Colors.white,
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
  Widget _statsGrid(bool d) {
    final rate = (controller.stats['completion_rate'] as num?)?.toDouble() ?? 0;
    final items = [
      _StatItem('Completion', '${(rate * 100).round()}%', Icons.check_circle_rounded, AppColors.success),
      _StatItem('Completed', '${controller.completedTopics.value}', Icons.done_all_rounded, AppColors.primary),
      _StatItem('Total Topics', '${controller.totalTopics.value}', Icons.topic_rounded, AppColors.info),
      _StatItem('Subjects', '${controller.totalSubjects.value}', Icons.book_rounded, AppColors.warning),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: S.gridSpacing,
      mainAxisSpacing: S.gridSpacing,
      childAspectRatio: 1.3,
      children: items
          .map((item) => StatCard(
                title: item.title,
                value: item.value,
                icon: item.icon,
                color: item.color,
              ))
          .toList(),
    );
  }

  // ─── SUBJECT PROGRESS ─────────────────────────────────────────
  Widget _subjectProgressList(bool d) {
    final data = controller.subjectProgress;
    if (data.isEmpty) {
      return _emptyState('No subjects yet', 'Add subjects to see progress', d);
    }
    return Column(
      children: data.take(5).map((item) {
        final subject = item['subject'];
        final total = item['total'] as int;
        final completed = item['completed'] as int;
        final mastery = item['mastery'] as double;
        final progress = total > 0 ? completed / total : 0.0;
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
                width: 48,
                height: 48,
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
                    Text(
                      '$completed/$total topics · ${(mastery * 100).round()}% mastery',
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

  // ─── MASTERY CHART ────────────────────────────────────────────
  Widget _masteryChart(bool d) {
    final dist = controller.masteryDistribution;
    final total = dist.values.fold(0, (a, b) => a + b);

    if (total == 0) {
      return _emptyState('No data yet', 'Complete revisions to see mastery breakdown', d);
    }

    final colors = [
      AppColors.error, // Novice
      AppColors.warning, // Learning
      AppColors.info, // Familiar
      AppColors.success, // Mastered
    ];
    final labels = ['Novice', 'Learning', 'Familiar', 'Mastered'];
    final values = [dist['Novice']!, dist['Learning']!, dist['Familiar']!, dist['Mastered']!];

    return Container(
      padding: EdgeInsets.all(S.lg),
      decoration: BoxDecoration(
        color: AppColors.surface(d),
        borderRadius: BorderRadius.circular(S.radiusLg),
        border: Border.all(color: AppColors.border(d)),
        boxShadow: S.shadowSm,
      ),
      child: Column(
        children: [
          // Pie chart
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: List.generate(4, (i) {
                  final pct = total > 0 ? values[i] / total : 0.0;
                  return PieChartSectionData(
                    value: values[i].toDouble(),
                    color: colors[i],
                    radius: pct > 0 ? 30 : 0,
                    title: pct > 0.05 ? '${(pct * 100).round()}%' : '',
                    titleStyle: AppTextStyles.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }),
              ),
            ),
          ),
          SizedBox(height: S.md),
          // Legend
          Wrap(
            spacing: S.base,
            runSpacing: S.sm,
            children: List.generate(4, (i) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[i],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  SizedBox(width: S.xs),
                  Text(
                    '${labels[i]} (${values[i]})',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary(d),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─── WEEKLY CHART ─────────────────────────────────────────────
  Widget _weeklyChart(bool d) {
    final spots = List.generate(7, (i) {
      final val = (3 + (i * 1.7) % 8).toDouble();
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: val,
            color: i < DateTime.now().weekday
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.3),
            width: 20,
            borderRadius: BorderRadius.vertical(top: Radius.circular(S.radiusSm)),
          ),
        ],
      );
    });

    return Container(
      height: 220,
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
                'This Week',
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
                maxY: 10,
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
                        final isToday = idx == DateTime.now().weekday - 1;
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
  Widget _insights(bool d) {
    final rate = (controller.stats['completion_rate'] as num?)?.toDouble() ?? 0;
    final avgMastery = controller.avgMastery.value;
    final totalRevisions = controller.stats['total_completed'] ?? 0;
    final thisWeek = controller.stats['sessions_this_week'] ?? 0;

    final insights = <_InsightItem>[];

    // Performance rating
    if (rate >= 0.8) {
      insights.add(_InsightItem(
        'Excellent Progress',
        'You have a ${(rate * 100).round()}% completion rate. Outstanding work!',
        Icons.emoji_events_rounded,
        AppColors.success,
      ));
    } else if (rate >= 0.5) {
      insights.add(_InsightItem(
        'Good Momentum',
        'You are at ${(rate * 100).round()}% completion. Keep pushing forward!',
        Icons.trending_up_rounded,
        AppColors.info,
      ));
    } else {
      insights.add(_InsightItem(
        'Building Habits',
        'You have started ${controller.totalTopics.value} topics. Consistency is key!',
        Icons.psychology_rounded,
        AppColors.warning,
      ));
    }

    // Weekly activity
    if (thisWeek > 0) {
      insights.add(_InsightItem(
        'Active This Week',
        'You have completed $thisWeek revision${thisWeek > 1 ? 's' : ''} this week.',
        Icons.local_fire_department_rounded,
        const Color(0xFFFF6B35),
      ));
    }

    // Mastery
    if (avgMastery > 0) {
      insights.add(_InsightItem(
        'Average Mastery',
        'Your topics are at ${(avgMastery * 100).round()}% average mastery level.',
        Icons.school_rounded,
        AppColors.primary,
      ));
    }

    // Total revisions
    if (totalRevisions > 0) {
      insights.add(_InsightItem(
        'Total Revisions',
        'You have completed $totalRevisions revision${totalRevisions > 1 ? 's' : ''} in total.',
        Icons.auto_stories_rounded,
        AppColors.secondary,
      ));
    }

    if (insights.isEmpty) {
      return _emptyState('No insights yet', 'Start revising to see your progress insights', d);
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
  final IconData icon;
  final Color color;
  _StatItem(this.title, this.value, this.icon, this.color);
}

class _InsightItem {
  final String title, description;
  final IconData icon;
  final Color color;
  _InsightItem(this.title, this.description, this.icon, this.color);
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';
import 'statistics_controller.dart';
import 'widgets/statistics_charts.dart';
import 'widgets/statistics_insights.dart';
import 'widgets/statistics_shimmer.dart';
import 'widgets/statistics_streak_card.dart';

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
            onPressed: () => controller.load(),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.topics.isEmpty) {
          return StatisticsShimmerLoader(d: d);
        }
        return RefreshIndicator(
          onRefresh: () => controller.load(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: EdgeInsets.all(S.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StreakCard(d: d, streak: controller.streakDays.value),
                SizedBox(height: S.xl),
                _sectionTitle('overview'.tr, d),
                SizedBox(height: S.base),
                _statsGrid(d),
                SizedBox(height: S.xxl),
                _sectionTitle('subjectProgress'.tr, d),
                SizedBox(height: S.base),
                SubjectProgressList(d: d, data: controller.subjectProgress),
                SizedBox(height: S.xxl),
                _sectionTitle('weeklyActivity'.tr, d),
                SizedBox(height: S.base),
                WeeklyActivityChart(d: d, activity: controller.weeklyActivity.toList()),
                SizedBox(height: S.xxl),
                _sectionTitle('performanceInsights'.tr, d),
                SizedBox(height: S.base),
                StatisticsInsights(
                  d: d,
                  rate: controller.completionFraction,
                  totalRevisions: controller.revisionsDone.value,
                  planned: controller.revisionsTotal.value,
                  thisWeek: controller.weeklyActivity.fold<int>(0, (a, b) => a + b),
                  streak: controller.streakDays.value,
                ),
                SizedBox(height: S.xxxl),
              ],
            ),
          ),
        );
      }),
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
}

// ─── DATA MODELS ────────────────────────────────────────────────

class _StatItem {
  final String title, value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  _StatItem(this.title, this.value, this.icon, this.color, {this.subtitle});
}

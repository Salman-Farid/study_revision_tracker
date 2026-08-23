import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';
import 'statistics_controller.dart';

class StatisticsScreen extends GetView<StatisticsController> {
  const StatisticsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(appBar: AppBar(title: Text('Statistics', style: AppTextStyles.headlineMedium)),
      body: Obx(() {
        if (controller.isLoading.value) return const Center(child: CircularProgressIndicator());
        final rate = (controller.stats['completion_rate'] as num?)?.toDouble() ?? 0;
        return SingleChildScrollView(physics: const BouncingScrollPhysics(), padding: EdgeInsets.all(S.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Overview', style: AppTextStyles.headlineMedium.copyWith(color: AppColors.textPrimary(d))),
            SizedBox(height: S.base),
            GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, crossAxisSpacing: S.gridSpacing, mainAxisSpacing: S.gridSpacing, childAspectRatio: 1.4,
              children: [
                StatCard(title: 'Completion', value: '${(rate * 100).round()}%', icon: Icons.check_circle_rounded, color: AppColors.success),
                StatCard(title: 'Completed', value: '${controller.stats['total_completed'] ?? 0}', icon: Icons.done_all_rounded, color: AppColors.primary),
                StatCard(title: 'This Week', value: '${controller.stats['sessions_this_week'] ?? 0}', icon: Icons.calendar_view_week_rounded, color: AppColors.info),
                StatCard(title: 'Scheduled', value: '${controller.stats['total_schedules'] ?? 0}', icon: Icons.schedule_rounded, color: AppColors.warning),
              ]),
            SizedBox(height: S.xxxl),
            Text('Weekly Trend', style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimary(d))),
            SizedBox(height: S.base),
            Container(height: 200, padding: EdgeInsets.all(S.base),
              decoration: BoxDecoration(color: AppColors.surface(d), borderRadius: BorderRadius.circular(S.radiusLg),
                border: Border.all(color: AppColors.border(d))),
              child: BarChart(BarChartData(alignment: BarChartAlignment.spaceAround, maxY: 10,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(leftTitles: const AxisTitles(), rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                    getTitlesWidget: (v, _) => Text(['M','T','W','T','F','S','S'][v.toInt() % 7],
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted(d)))))),
                borderData: FlBorderData(show: false), gridData: const FlGridData(show: false),
                barGroups: List.generate(7, (i) => BarChartGroupData(x: i, barRods: [
                  BarChartRodData(toY: (3 + (i * 1.2) % 7).toDouble(), color: AppColors.primary,
                    width: 16, borderRadius: BorderRadius.circular(4)),
                ]))))),
            SizedBox(height: S.xxxl),
          ]));
      }));
  }
}

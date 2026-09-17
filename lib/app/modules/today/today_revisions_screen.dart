import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import 'today_controller.dart';
import 'widgets/today_filter_chips.dart';
import 'widgets/today_revision_tile.dart';

class TodayRevisionsScreen extends GetView<TodayController> {
  const TodayRevisionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text('todaysRevisions'.tr)),
      body: Column(
        children: [
          Obx(() {
            final selected = controller.selectedTab.value;
            final items = [
              (0, 'statToday'.tr, controller.today.length, AppColors.primary),
              (1, 'missed'.tr, controller.overdue.length, AppColors.error),
              (2, 'statUpcoming'.tr, controller.upcoming.length, AppColors.info),
            ];
            return TodayFilterChips(
              d: d,
              selectedTab: selected,
              items: items,
              onSelect: (i) => controller.selectedTab.value = i,
            );
          }),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final tab = controller.selectedTab.value;
              final list = tab == 0
                  ? controller.today
                  : tab == 1
                      ? controller.overdue
                      : controller.upcoming;

              if (list.isEmpty) {
                return RefreshIndicator(
                  onRefresh: controller.load,
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: EmptyState(
                          icon: tab == 1
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_rounded,
                          title: tab == 0
                              ? 'allCaughtUpTitle'.tr
                              : tab == 1
                                  ? 'missed'.tr
                                  : 'statUpcoming'.tr,
                          subtitle: tab == 0
                              ? 'allCaughtUpSub'.tr
                              : tab == 1
                                  ? 'noPendingRevisions'.tr
                                  : 'noRevisionsThisDay'.tr,
                        ),
                      ),
                    ),
                  ),
                );
              }

              final accent = tab == 0
                  ? AppColors.primary
                  : tab == 1
                      ? AppColors.error
                      : AppColors.info;

              return RefreshIndicator(
                onRefresh: controller.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  padding: EdgeInsets.all(S.base),
                  children: [
                    if (tab != 2) ...[
                      // Completing a missed/today revision → completed.
                      ...list.map((s) => TodayRevisionTile(
                            s: s,
                            col: accent,
                            onDismiss: () => controller.markDone(s.id),
                            d: d,
                            isOverdue: tab == 1,
                          )),
                    ] else
                      ...list.map((s) => TodayRevisionTile(
                            s: s,
                            col: accent,
                            onDismiss: () => controller.markDone(s.id),
                            d: d,
                            isOverdue: false,
                          )),
                    SizedBox(height: S.xxxl),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

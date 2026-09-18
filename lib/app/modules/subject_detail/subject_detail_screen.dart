import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/responsive.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import 'subject_detail_controller.dart';
import 'widgets/subject_filter_chips.dart';
import 'widgets/topic_first_read_card.dart';
import 'widgets/topic_revision_card.dart';

class SubjectDetailScreen extends GetView<SubjectDetailController> {
  const SubjectDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text(controller.subject.name)),
        actions: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: controller.openVoiceAssistant,
              icon: Icon(Icons.mic_rounded, color: AppConstants.primaryColor),
              tooltip: 'studyRoutine'.tr,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: controller.showAddSheet,
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          SubjectFilterChips(controller: controller, d: d),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.topics.isEmpty) {
                return EmptyState(
                  icon: Icons.topic_rounded,
                  title: 'noTopicsYet'.tr,
                  subtitle: 'Add topics to "${controller.subject.name}"',
                  actionLabel: 'addTopic'.tr,
                  onAction: controller.showAddSheet,
                );
              }
              final filtered = controller.filteredTopics;
              if (filtered.isEmpty) {
                return EmptyState(
                  icon: Icons.filter_list_off_rounded,
                  title: 'noTopicsYet'.tr,
                  subtitle: 'No topics match this filter',
                );
              }
              return _list(d, filtered);
            }),
          ),
        ],
      ),
    );
  }

  Widget _list(bool d, List topics) {
    // Cap width on desktop/tablet so cards stay compact and actions
    // (Complete / bin / reorder) stay grouped instead of spanning a huge pane.
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: Responsive.useNavRail ? 680 : double.infinity,
        ),
        child: ReorderableListView.builder(
          padding: EdgeInsets.fromLTRB(S.base, S.sm, S.base, 96),
          itemCount: topics.length,
          // Flutter 3.44+: onReorderItem supplies an already-adjusted newIndex.
          // Children MUST carry keys — ReorderableListView does child.key! and
          // unkeyed items crash the list into a grey ErrorWidget in release.
          onReorderItem: controller.reorderTopics,
          // Explicit handle only — no default trailing grips overlapping the bin.
          buildDefaultDragHandles: false,
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (_, __) => Material(
                color: Colors.transparent,
                elevation: 0,
                borderRadius: BorderRadius.circular(S.radiusLg),
                child: child,
              ),
            );
          },
          itemBuilder: (_, i) {
            final t = topics[i];
            final isFirstRead = !t.firstReadCompleted;
            final isCompleted = t.totalRevisions >= 6;

            if (isFirstRead) {
              return TopicFirstReadCard(
                key: ValueKey('fr_${t.id}'),
                d: d,
                t: t,
                index: i,
                onComplete: () => _confirmFirstRead(d, t),
                onDelete: () {
                  controller.deleteTopic(t.id);
                  Get.back();
                },
              );
            } else {
              return TopicRevisionCard(
                key: ValueKey('rev_${t.id}'),
                d: d,
                t: t,
                isCompleted: isCompleted,
                index: i,
                schedules: controller.getSchedules(t.id),
                onConfirmRevision: (dayLabel) => _confirmRevision(d, t, dayLabel),
                onDelete: () {
                  controller.deleteTopic(t.id);
                  Get.back();
                },
              );
            }
          },
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  DIALOGS
  // ══════════════════════════════════════════════════════════════
  void _confirmFirstRead(bool d, dynamic t) {
    Get.defaultDialog(
      title: 'firstRead'.tr,
      middleText: 'Mark "${t.name}" as first read completed?',
      textConfirm: 'ok'.tr,
      textCancel: 'cancel'.tr,
      confirmTextColor: Colors.white,
      buttonColor: AppColors.primary,
      onConfirm: () {
        Get.back();
        controller.markFirstRead(t.id);
      },
    );
  }

  void _confirmRevision(bool d, dynamic t, String dayLabel) {
    final dayNumber = int.parse(dayLabel);
    Get.defaultDialog(
      title: 'markDone'.tr,
      middleText: 'Mark Day $dayNumber revision for "${t.name}" as done?',
      textConfirm: 'ok'.tr,
      textCancel: 'cancel'.tr,
      confirmTextColor: Colors.white,
      buttonColor: AppColors.primary,
      onConfirm: () {
        Get.back();
        controller.markRevisionComplete(t.id, dayNumber);
      },
    );
  }
}

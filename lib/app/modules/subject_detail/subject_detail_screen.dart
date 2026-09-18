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
import 'widgets/topic_parent_card.dart';
import 'widgets/topic_revision_card.dart';

class SubjectDetailScreen extends GetView<SubjectDetailController> {
  const SubjectDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        leading: Obx(() {
          // listVersion ticks when entering/leaving subtopic mode.
          final _ = controller.listVersion.value;
          if (!controller.isSubtopicMode) {
            return const SizedBox.shrink();
          }
          return IconButton(
            tooltip: 'Back to topics',
            onPressed: controller.exitSubtopics,
            icon: const Icon(Icons.arrow_back_rounded),
          );
        }),
        title: Obx(() {
          final _ = controller.listVersion.value;
          final title = controller.screenTitle;
          if (!controller.isSubtopicMode) {
            return Center(child: Text(title));
          }
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${controller.subject.name} · Subtopics',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted(d),
                  ),
                ),
              ],
            ),
          );
        }),
        actions: [
          Container(
            height: 44,
            width: 44,
            margin: const EdgeInsets.only(right: 8),
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
          Padding(
            padding: EdgeInsets.fromLTRB(S.base, 0, S.base, S.sm),
            child: TextField(
              onChanged: controller.setTopicSearch,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary(d),
              ),
              cursorColor: AppConstants.primaryColor,
              decoration: InputDecoration(
                hintText: controller.isSubtopicMode
                    ? 'Search subtopics…'
                    : 'Search topics…',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted(d),
                  size: 20,
                ),
                suffixIcon: Obx(() {
                  if (controller.topicSearch.value.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    tooltip: 'Clear',
                    onPressed: controller.clearTopicSearch,
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.textMuted(d),
                      size: 18,
                    ),
                  );
                }),
                isDense: true,
                filled: true,
                fillColor: AppColors.surface(d),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border(d)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border(d)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppConstants.primaryColor,
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              final _ = controller.listVersion.value;
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.topics.isEmpty) {
                return EmptyState(
                  icon: Icons.topic_rounded,
                  title: 'noTopicsYet'.tr,
                  subtitle: controller.isSubtopicMode
                      ? 'Add subtopics under "${controller.screenTitle}"'
                      : 'Add topics to "${controller.subject.name}"',
                  actionLabel: 'addTopic'.tr,
                  onAction: controller.showAddSheet,
                );
              }
              final filtered = controller.filteredTopics;
              if (filtered.isEmpty) {
                final q = controller.topicSearch.value;
                return EmptyState(
                  icon: q.isEmpty
                      ? Icons.filter_list_off_rounded
                      : Icons.search_off_rounded,
                  title: 'noTopicsYet'.tr,
                  subtitle: q.isEmpty
                      ? 'No topics match this filter'
                      : 'No topics match "$q"',
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
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: Responsive.useNavRail ? 680 : double.infinity,
        ),
        child: ReorderableListView.builder(
          padding: EdgeInsets.fromLTRB(S.base, S.sm, S.base, 96),
          itemCount: topics.length,
          onReorderItem: controller.reorderTopics,
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
            Widget wrapDrag(Widget child) => ReorderableDelayedDragStartListener(
                  index: i,
                  child: child,
                );

            if (t.hasSubtopics && !controller.isSubtopicMode) {
              final progress = controller.parentRingFor(t);
              final done = controller.parentIsDoneFor(t);
              return KeyedSubtree(
                key: ValueKey('parent_${t.id}'),
                child: wrapDrag(
                  TopicParentCard(
                    d: d,
                    topic: t,
                    ringProgress: progress,
                    isDone: done,
                    onOpen: () => controller.openSubtopics(t),
                  ),
                ),
              );
            }

            final isFirstRead = !t.firstReadCompleted;
            final isCompleted = t.firstReadCompleted && t.totalRevisions >= 6;
            // ONLY first-read, top-level topics can open the subtopic screen
            // (to add subtopics). Once a topic is in revision / done — expand only.
            final VoidCallback? openSubs = (!controller.isSubtopicMode && isFirstRead)
                ? () => controller.openSubtopics(t)
                : null;

            if (isFirstRead) {
              return KeyedSubtree(
                key: ValueKey('fr_${t.id}'),
                child: wrapDrag(
                  TopicFirstReadCard(
                    d: d,
                    t: t,
                    index: i,
                    onTap: openSubs,
                    showOpenChevron: openSubs != null,
                    onComplete: () => _confirmFirstRead(d, t),
                    onDelete: () {
                      controller.deleteTopic(t.id);
                      Get.back();
                    },
                  ),
                ),
              );
            }
            return KeyedSubtree(
              key: ValueKey('rev_${t.id}'),
              child: wrapDrag(
                TopicRevisionCard(
                  d: d,
                  t: t,
                  isCompleted: isCompleted,
                  index: i,
                  schedules: controller.getSchedules(t.id),
                  // Body tap → subtopics (top-level only); expand arrow stays.
                  onOpenSubtopics: openSubs,
                  onConfirmRevision: (dayLabel) => _confirmRevision(d, t, dayLabel),
                  onDelete: () {
                    controller.deleteTopic(t.id);
                    Get.back();
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

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

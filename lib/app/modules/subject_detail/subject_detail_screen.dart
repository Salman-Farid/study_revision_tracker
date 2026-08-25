import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import 'subject_detail_controller.dart';

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
              icon: Icon(
                Icons.mic_rounded,
                color: AppConstants.primaryColor,
              ),
              tooltip: 'Voice Assistant',
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.showAddSheet,
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value)
                return const Center(child: CircularProgressIndicator());
              if (controller.topics.isEmpty) {
                return EmptyState(
                  icon: Icons.topic_rounded,
                  title: 'No Topics Yet',
                  subtitle: 'Add topics to "${controller.subject.name}"',
                  actionLabel: 'Add Topic',
                  onAction: controller.showAddSheet,
                );
              }
              return _list(d);
            }),
          ),
        ],
      ),
    );
  }

  Widget _list(bool d) => ReorderableListView.builder(
    padding: EdgeInsets.all(S.base),
    itemCount: controller.topics.length,
    onReorder: controller.reorderTopics,
    proxyDecorator: (child, index, animation) {
      return AnimatedBuilder(
        animation: animation,
        builder: (_, __) => Material(
          color: Colors.transparent,
          elevation: 0,
          child: child,
        ),
      );
    },
    itemBuilder: (_, i) {
      final t = controller.topics[i];
      return Container(
        key: Key(t.id),
        margin: EdgeInsets.only(bottom: S.md),
        child: GestureDetector(
          onTap: () => Get.toNamed(
            '/topic/${t.id}',
            arguments: {'topic': t, 'subject': controller.subject},
          ),
          child: Container(
            padding: EdgeInsets.all(S.base),
            decoration: BoxDecoration(
              color: AppColors.surface(d),
              borderRadius: BorderRadius.circular(S.radiusLg),
              border: Border.all(color: AppColors.border(d)),
              boxShadow: S.shadowSm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.drag_handle_rounded,
                  color: AppColors.textMuted(d),
                  size: 20,
                ),

                SizedBox(width: S.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.name,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.textPrimary(d),
                        ),
                      ),
                      SizedBox(height: S.xs),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: S.sm,
                              vertical: S.xs,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (t.masteryLevel >= 0.75
                                          ? AppColors.success
                                          : AppColors.warning)
                                      .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(S.radiusSm),
                            ),
                            child: Text(
                              '${(t.masteryLevel * 100).round()}%',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: t.masteryLevel >= 0.75
                                    ? AppColors.success
                                    : AppColors.warning,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: S.sm),
                          Text(
                            '${t.totalRevisions} revisions',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textMuted(d),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Get.defaultDialog(
                    title: 'Delete?',
                    middleText: 'Delete "${t.name}"?',
                    textConfirm: 'Delete',
                    textCancel: 'Cancel',
                    confirmTextColor: Colors.white,
                    buttonColor: AppColors.error,
                    onConfirm: () {
                      controller.deleteTopic(t.id);
                      Get.back();
                    },
                  ),
                  child: Container(
                    padding: EdgeInsets.all(S.sm),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(S.radiusSm),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                  ),
                ),
                SizedBox(width: S.sm),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted(d),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

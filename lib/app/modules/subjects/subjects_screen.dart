import 'package:flutter/material.dart';
import 'package:flutter_reorderable_grid_view/widgets/widgets.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/size_constants.dart';
import '../../data/models/subject_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton_loader.dart';
import 'subjects_controller.dart';

class SubjectsScreen extends GetView<SubjectsController> {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text('Subjects', style: AppTextStyles.headlineMedium), actions: [
        IconButton(onPressed: controller.showAddSheet,
          icon: Icon(Icons.add_rounded, color: AppConstants.primaryColor),
          tooltip: 'Add Subject'),
        IconButton(onPressed: controller.toggleChat, icon: Obx(() => Icon(
          controller.showChat.value ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
          color: controller.showChat.value ? AppColors.primary : null))),
      ]),
      floatingActionButton: FloatingActionButton(
        key: controller.studyAssistantButtonKey,
        onPressed: controller.openStudyAssistantDialogue,
        backgroundColor: AppConstants.primaryColor,
        child: const Icon(Icons.mic_rounded, color: Colors.white),
      ),
      body: Column(children: [
        Obx(() => controller.showChat.value ? _voiceChat(d) : const SizedBox.shrink()),
        Expanded(child: Obx(() {
          if (controller.isLoading.value) return const SkeletonGrid();
          if (controller.subjects.isEmpty) return EmptyState(icon: Icons.menu_book_rounded,
            title: 'No Subjects Yet', subtitle: 'Add your first subject to start tracking',
            actionLabel: 'Add Subject', onAction: controller.showAddSheet);
          return _grid(d);
        })),
      ]));
  }

  Widget _grid(bool d) {
    final scrollController = ScrollController();
    final generatedChildren = List.generate(
      controller.subjects.length,
      (index) {
        final sub = controller.subjects[index];
        return Container(
          key: Key(sub.id),
          child: GestureDetector(
            onTap: () => Get.toNamed('/subject/${sub.id}', arguments: sub),
            child: Container(
              padding: EdgeInsets.all(S.base),
              decoration: BoxDecoration(
                color: AppColors.surface(d),
                borderRadius: BorderRadius.circular(S.radiusLg),
                border: Border.all(color: AppColors.border(d)),
                boxShadow: S.shadowSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.all(S.md),
                        decoration: BoxDecoration(
                          color: sub.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(S.radiusMd),
                        ),
                        child: Icon(
                          IconData(sub.iconCodePoint, fontFamily: 'MaterialIcons'),
                          color: sub.color,
                          size: S.iconLg,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Get.defaultDialog(
                          title: 'Delete?',
                          middleText: 'Delete "${sub.name}" and all its topics?',
                          textConfirm: 'Delete',
                          textCancel: 'Cancel',
                          confirmTextColor: Colors.white,
                          buttonColor: AppColors.error,
                          onConfirm: () {
                            controller.deleteSubject(sub.id);
                            Get.back();
                          },
                        ),
                        child: Container(
                          padding: EdgeInsets.all(S.sm),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(S.radiusSm),
                          ),
                          child: Icon(Icons.delete_outline_rounded,
                              color: AppColors.error, size: 20),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sub.name,
                          style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.textPrimary(d)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      SizedBox(height: S.xs),
                      Text('${sub.totalTopics} topics',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted(d))),
                      SizedBox(height: S.sm),
                      LinearProgressIndicator(
                        value: sub.progressPercent,
                        backgroundColor: sub.color.withOpacity(0.12),
                        valueColor: AlwaysStoppedAnimation(sub.color),
                        borderRadius: BorderRadius.circular(S.radiusFull),
                        minHeight: 4,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return ReorderableBuilder(
      children: generatedChildren,
      scrollController: scrollController,
      onReorder: (ReorderedListFunction reorderedListFunction) {
        final reordered = reorderedListFunction(controller.subjects.toList()).cast<SubjectModel>();
        controller.subjects.assignAll(reordered);
      },
      builder: (children) {
        return GridView(
          controller: scrollController,
          padding: EdgeInsets.all(S.base),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: S.gridCrossAxisCount,
            crossAxisSpacing: S.gridSpacing,
            mainAxisSpacing: S.gridSpacing,
            childAspectRatio: S.gridChildAspectRatio,
          ),
          children: children,
        );
      },
    );
  }

  Widget _voiceChat(bool d) => AnimatedSize(duration: AppConstants.mediumDuration, curve: Curves.easeInOut,
    child: Container(height: 300, margin: EdgeInsets.all(S.md), decoration: BoxDecoration(
      color: AppColors.surface(d), borderRadius: BorderRadius.circular(S.radiusLg),
      border: Border.all(color: AppColors.border(d))),
      child: Column(children: [
        Expanded(child: Obx(() => ListView.builder(padding: EdgeInsets.all(S.md),
          itemCount: controller.chatMessages.length, itemBuilder: (_, i) {
            final m = controller.chatMessages[i];
            return Align(alignment: m['u'] ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(constraints: BoxConstraints(maxWidth: MediaQuery.of(Get.context!).size.width * 0.7),
                margin: EdgeInsets.symmetric(vertical: S.xs), padding: EdgeInsets.symmetric(horizontal: S.base, vertical: S.sm),
                decoration: BoxDecoration(color: m['u'] ? AppColors.primary : (d ? const Color(0xFF232730) : AppColors.bgLight),
                  borderRadius: BorderRadius.circular(S.radiusMd)),
                child: Text(m['t'], style: AppTextStyles.bodySmall.copyWith(
                  color: m['u'] ? Colors.white : AppColors.textPrimary(d)))));
          }))),
        Padding(padding: EdgeInsets.all(S.md), child: Obx(() => GestureDetector(
          onTap: controller.isListening.value ? controller.stopListening : controller.startListening,
          child: AnimatedContainer(duration: AppConstants.shortDuration, padding: EdgeInsets.all(S.base),
            decoration: BoxDecoration(color: controller.isListening.value ? AppColors.error : AppColors.primary,
              shape: BoxShape.circle, boxShadow: controller.isListening.value
                ? [BoxShadow(color: AppColors.error.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)] : []),
            child: Icon(controller.isListening.value ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white, size: S.iconLg))))),
      ])));
}

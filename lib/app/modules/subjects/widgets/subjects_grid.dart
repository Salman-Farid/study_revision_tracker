import 'package:flutter/material.dart';
import 'package:flutter_reorderable_grid_view/widgets/widgets.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/size_constants.dart';
import '../../../data/models/subject_model.dart';
import '../../../theme/app_theme.dart';
import '../subjects_controller.dart';

class SubjectsGrid extends StatelessWidget {
  final bool d;
  final SubjectsController controller;
  const SubjectsGrid({super.key, required this.d, required this.controller});

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();
    final generatedChildren = List.generate(
      controller.subjects.length,
      (index) {
        final sub = controller.subjects[index];
        final hasImage = sub.imageUrl != null && sub.imageUrl!.isNotEmpty;
        return Container(
          key: Key(sub.id),
          child: GestureDetector(
            onTap: () => controller.openSubject(sub),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(S.radiusLg),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasImage) ...[
                    Container(color: AppColors.surface(d)),
                    Image.network(sub.imageUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return Shimmer.fromColors(
                          baseColor: d ? const Color(0xFF232730) : Colors.grey[300]!,
                          highlightColor: d ? const Color(0xFF2A2F3A) : Colors.grey[100]!,
                          child: Container(color: d ? const Color(0xFF232730) : Colors.grey[300]),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(color: AppColors.surface(d))),
                  ],
                  Container(
                    padding: EdgeInsets.all(S.base),
                    color: hasImage ? null : AppColors.surface(d),
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
                          color: hasImage ? Colors.white24 : sub.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(S.radiusMd),
                        ),
                        child: Icon(
                          IconData(sub.iconCodePoint, fontFamily: 'MaterialIcons'),
                          color: hasImage ? Colors.white : sub.color,
                          size: S.iconLg,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Get.defaultDialog(
                          title: 'deleteQ'.tr,
                          middleText: 'deleteSubjectBody'.tr.replaceAll('{name}', sub.name),
                          textConfirm: 'delete'.tr,
                          textCancel: 'cancel'.tr,
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
                            color: hasImage ? Colors.white30 : AppColors.error.withOpacity(0.1),
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
                              color: hasImage ? Colors.white : AppColors.textPrimary(d)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      SizedBox(height: S.xs),
                      // REAL topic names from the topics table.
                      Obx(() {
                        final count = controller.topicCountFor(sub);
                        return Text(
                          count == 1 ? 'topicSingular'.tr : 'topicsCount'.tr.replaceAll('{n}', '$count'),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: hasImage ? Colors.white70 : AppColors.textMuted(d),
                          ),
                        );
                      }),
                      SizedBox(height: S.sm),
                      // REAL revision-weighted progress (was hardcoded to 0).
                      Obx(() {
                        final p = controller.progressFor(sub.id);
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          LinearProgressIndicator(
                            value: p,
                            backgroundColor: hasImage ? Colors.white30 : sub.color.withOpacity(0.12),
                            valueColor: AlwaysStoppedAnimation(hasImage ? Colors.white : sub.color),
                            borderRadius: BorderRadius.circular(S.radiusFull),
                            minHeight: 4,
                          ),
                          SizedBox(height: S.xs),
                          Text('${(p * 100).round()}%',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: hasImage ? Colors.white : sub.color,
                              fontWeight: FontWeight.w700)),
                        ]);
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
      },
    );

    return ReorderableBuilderWrap(
      children: generatedChildren,
      scrollController: scrollController,
      controller: controller,
    );
  }
}

class ReorderableBuilderWrap extends StatelessWidget {
  final List<Widget> children;
  final ScrollController scrollController;
  final SubjectsController controller;
  const ReorderableBuilderWrap({
    super.key,
    required this.children,
    required this.scrollController,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ReorderableBuilder(
      children: children,
      scrollController: scrollController,
      onDragStarted: (_) => controller.isDragging.value = true,
      onDragEnd: (_) => controller.isDragging.value = false,
      onReorder: (ReorderedListFunction reorderedListFunction) {
        final reordered = reorderedListFunction(controller.subjects.toList()).cast<SubjectModel>();
        controller.subjects.assignAll(reordered);
      },
      builder: (children) {
        return LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          // Density follows the pane, not the window — avoids sparse grids
          // inside web/desktop side panels.
          final cols = w >= 720 ? 3 : 2;
          final aspect = w >= 720 ? 1.15 : (w >= 400 ? 1.0 : 0.9);
          return GridView(
            controller: scrollController,
            padding: EdgeInsets.all(S.base),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: S.gridSpacing,
              mainAxisSpacing: S.gridSpacing,
              childAspectRatio: aspect,
            ),
            children: children,
          );
        });
      },
    );
  }
}

class SubjectsVoiceChatPanel extends StatelessWidget {
  final bool d;
  final SubjectsController controller;
  const SubjectsVoiceChatPanel({super.key, required this.d, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(duration: AppConstants.mediumDuration, curve: Curves.easeInOut,
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
}

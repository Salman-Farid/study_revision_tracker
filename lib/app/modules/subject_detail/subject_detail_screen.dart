import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/size_constants.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import 'subject_detail_controller.dart';

class SubjectDetailScreen extends GetView<SubjectDetailController> {
  const SubjectDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Obx(() => Text(controller.subject.name, style: AppTextStyles.headlineMedium)), actions: [
        IconButton(onPressed: controller.toggleChat,
          icon: Obx(() => Icon(controller.showChat.value ? Icons.mic_rounded : Icons.mic_none_rounded,
            color: controller.showChat.value ? AppColors.primary : null))),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: controller.showAddSheet, child: const Icon(Icons.add_rounded)),
      body: Column(children: [
        Obx(() => controller.showChat.value ? _voiceChat(d) : const SizedBox.shrink()),
        Expanded(child: Obx(() {
          if (controller.isLoading.value) return const Center(child: CircularProgressIndicator());
          if (controller.topics.isEmpty) return EmptyState(icon: Icons.topic_rounded,
            title: 'No Topics Yet', subtitle: 'Add topics to "${controller.subject.name}"',
            actionLabel: 'Add Topic', onAction: controller.showAddSheet);
          return _list(d);
        })),
      ]));
  }

  Widget _list(bool d) => ListView.builder(padding: EdgeInsets.all(S.base), itemCount: controller.topics.length,
    itemBuilder: (_, i) {
      final t = controller.topics[i];
      return GestureDetector(
        onTap: () => Get.toNamed('/topic/${t.id}', arguments: {'topic': t, 'subject': controller.subject}),
        child: Container(margin: EdgeInsets.only(bottom: S.md), padding: EdgeInsets.all(S.base),
          decoration: BoxDecoration(color: AppColors.surface(d), borderRadius: BorderRadius.circular(S.radiusLg),
            border: Border.all(color: AppColors.border(d)), boxShadow: S.shadowSm),
          child: Row(children: [
            Container(width: S.avatarSize, height: S.avatarSize, decoration: BoxDecoration(
              color: controller.subject.color.withOpacity(0.12), borderRadius: BorderRadius.circular(S.radiusMd)),
              child: Center(child: Text(t.name.isNotEmpty ? t.name[0].toUpperCase() : '?',
                style: AppTextStyles.headlineSmall.copyWith(color: controller.subject.color)))),
            SizedBox(width: S.md),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.name, style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary(d))),
              SizedBox(height: S.xs),
              Row(children: [
                Container(padding: EdgeInsets.symmetric(horizontal: S.sm, vertical: S.xs),
                  decoration: BoxDecoration(color: (t.masteryLevel >= 0.75 ? AppColors.success : AppColors.warning).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(S.radiusSm)),
                  child: Text('${(t.masteryLevel * 100).round()}%',
                    style: AppTextStyles.labelSmall.copyWith(color: t.masteryLevel >= 0.75 ? AppColors.success : AppColors.warning, fontWeight: FontWeight.w700))),
                SizedBox(width: S.sm),
                Text('${t.totalRevisions} revisions', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted(d))),
              ]),
            ])),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted(d)),
          ]))));
    });

  Widget _voiceChat(bool d) => AnimatedSize(duration: AppConstants.mediumDuration, curve: Curves.easeInOut,
    child: Container(height: 260, margin: EdgeInsets.all(S.md), decoration: BoxDecoration(
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
                child: Text(m['t'], style: AppTextStyles.bodySmall.copyWith(color: m['u'] ? Colors.white : AppColors.textPrimary(d)))));
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

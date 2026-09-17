import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';
import '../settings_controller.dart';

class SettingsProfileHeader extends StatelessWidget {
  final SettingsController c;
  const SettingsProfileHeader({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(S.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF9D97FF)]),
        borderRadius: BorderRadius.circular(S.radiusLg),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3),
          blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        // Avatar with initial
        Obx(() => Container(
          width: S.avatarSize * 1.6,
          height: S.avatarSize * 1.6,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white70, width: 2)),
          child: Text(c.avatarInitial,
            style: AppTextStyles.headlineLarge.copyWith(
              color: Colors.white, fontWeight: FontWeight.w900,
              fontSize: S.iconLg)))),
        SizedBox(width: S.base),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Obx(() => Text(
            c.displayName.value.isEmpty ? 'guestUser'.tr : c.displayName.value,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleLarge.copyWith(
              color: Colors.white, fontWeight: FontWeight.w800))),
          SizedBox(height: S.xs),
          Obx(() => Text(
            c.email.value.isEmpty ? 'notSignedIn'.tr : c.email.value,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(color: Colors.white70))),
          SizedBox(height: S.xs),
          Obx(() => Text(
            '${'memberSince'.tr} ${c.formatMemberSince()}',
            style: AppTextStyles.labelSmall.copyWith(color: Colors.white70))),
        ])),
      ]),
    );
  }
}

class SettingsStatsRow extends StatelessWidget {
  final SettingsController c;
  const SettingsStatsRow({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Obx(() => MiniStat(label: 'navSubjects'.tr, value: '${c.subjectCount.value}',
          icon: Icons.menu_book_rounded, color: AppColors.primary))),
      SizedBox(width: S.md),
      Expanded(child: Obx(() => MiniStat(label: 'navToday'.tr, value: '${c.topicCount.value}',
          icon: Icons.topic_rounded, color: AppColors.info))),
      SizedBox(width: S.md),
      Expanded(child: Obx(() => MiniStat(label: 'revisionsDone'.tr,
          value: '${c.revisionsDone.value}/${c.revisionsPlanned.value}',
          icon: Icons.done_all_rounded, color: AppColors.success))),
    ]);
  }
}

class MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const MiniStat({super.key, required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final d = Get.isDarkMode;
    return Container(
      padding: EdgeInsets.all(S.md),
      decoration: BoxDecoration(
        color: AppColors.surface(d),
        borderRadius: BorderRadius.circular(S.radiusLg),
        border: Border.all(color: AppColors.border(d)),
        boxShadow: S.shadowSm),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: S.iconMd),
        SizedBox(height: S.sm),
        FittedBox(fit: BoxFit.scaleDown,
          child: Text(value, maxLines: 1, style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimary(d), fontWeight: FontWeight.w800))),
        SizedBox(height: S.xs),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted(d))),
      ]),
    );
  }
}

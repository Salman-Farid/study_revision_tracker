import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';

String formatTopicDate(DateTime date) {
  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class TopicBadge extends StatelessWidget {
  final bool d;
  final String label;
  final Color color;
  const TopicBadge({super.key, required this.d, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(S.radiusSm),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

class TopicStatusBadge extends StatelessWidget {
  final bool d;
  final dynamic t;
  final List<String> dayLabels;
  const TopicStatusBadge({super.key, required this.d, required this.t, required this.dayLabels});

  @override
  Widget build(BuildContext context) {
    if (!t.firstReadCompleted) {
      return TopicBadge(d: d, label: 'firstRead'.tr, color: AppColors.primary);
    } else if (t.totalRevisions >= 6) {
      return TopicBadge(d: d, label: 'statCompleted'.tr, color: AppColors.success);
    } else {
      return TopicBadge(d: d, label: 'Day ${dayLabels[t.totalRevisions]} • ${t.totalRevisions + 1}/6', color: AppColors.primary);
    }
  }
}

class TopicDeleteButton extends StatelessWidget {
  final bool d;
  final dynamic t;
  final VoidCallback onDelete;
  const TopicDeleteButton({super.key, required this.d, required this.t, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(S.radiusSm),
        onTap: () => Get.defaultDialog(
          title: 'deleteQ'.tr,
          middleText: 'Delete "${t.name}"?',
          textConfirm: 'delete'.tr,
          textCancel: 'cancel'.tr,
          confirmTextColor: Colors.white,
          buttonColor: AppColors.error,
          onConfirm: onDelete,
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
        ),
      ),
    );
  }
}

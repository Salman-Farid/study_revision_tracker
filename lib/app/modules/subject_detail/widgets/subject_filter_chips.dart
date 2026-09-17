import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';
import '../subject_detail_controller.dart';

class SubjectFilterChips extends StatelessWidget {
  final SubjectDetailController controller;
  final bool d;
  const SubjectFilterChips({super.key, required this.controller, required this.d});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: S.base, vertical: S.sm),
      child: Obx(() {
        final selected = controller.selectedFilter.value;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChipBadge(
                d: d,
                label: 'all'.tr,
                count: controller.topics.length,
                isSelected: selected == 'all',
                onTap: () {
                  controller.selectedFilter.value = 'all';
                },
              ),
              SizedBox(width: S.sm),
              FilterChipBadge(
                d: d,
                label: 'firstRead'.tr,
                count: controller.firstReadCount,
                isSelected: selected == 'firstRead',
                onTap: () {
                  controller.selectedFilter.value = 'firstRead';
                },
              ),
              SizedBox(width: S.sm),
              FilterChipBadge(
                d: d,
                label: 'inRevision'.tr,
                count: controller.inRevisionCount,
                isSelected: selected == 'inRevision',
                onTap: () {
                  controller.selectedFilter.value = 'inRevision';
                },
              ),
              SizedBox(width: S.sm),
              FilterChipBadge(
                d: d,
                label: 'done'.tr,
                count: controller.completedCount,
                isSelected: selected == 'completed',
                onTap: () {
                  controller.selectedFilter.value = 'completed';
                },
              ),
            ],
          ),
        );
      }),
    );
  }
}

class FilterChipBadge extends StatelessWidget {
  final bool d;
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  const FilterChipBadge({
    super.key,
    required this.d,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface(d),
          borderRadius: BorderRadius.circular(S.radiusFull),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border(d),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary(d),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (count > 0) ...[
              SizedBox(width: S.xs),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.textMuted(d).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(S.radiusFull),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isSelected ? Colors.white : AppColors.textMuted(d),
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

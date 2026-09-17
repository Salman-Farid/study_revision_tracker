import 'package:flutter/material.dart';
import '../core/constants/size_constants.dart';
import '../theme/app_theme.dart';

/// Shared filter chip (label + optional count badge).
///
/// Used by Today tabs and Subject-detail filters. Keep metrics here so
/// all chips stay consistent.
class FilterChipBadge extends StatelessWidget {
  final bool d;
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? selectedColor;

  const FilterChipBadge({
    super.key,
    required this.d,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = selectedColor ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(vertical: S.sm, horizontal: S.xs),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.12)
              : AppColors.surface(d),
          borderRadius: BorderRadius.circular(S.radiusFull),
          border: Border.all(
            color: isSelected ? accent : AppColors.border(d),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelMedium.copyWith(
                  color: isSelected ? accent : AppColors.textSecondary(d),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent
                      : AppColors.textMuted(d).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(S.radiusFull),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isSelected ? Colors.white : AppColors.textMuted(d),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
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

import 'package:flutter/material.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';

class TodayFilterChips extends StatelessWidget {
  final bool d;
  final int selectedTab;
  final List<(int, String, int, Color)> items;
  final ValueChanged<int> onSelect;
  const TodayFilterChips({
    super.key,
    required this.d,
    required this.selectedTab,
    required this.items,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(S.base, S.sm, S.base, S.sm),
      child: Row(
        children: [
          for (final it in items) ...[
            Expanded(
              child: TodayChip(
                d: d,
                label: it.$2,
                count: it.$3,
                col: it.$4,
                selected: selectedTab == it.$1,
                onTap: () => onSelect(it.$1),
              ),
            ),
            if (it.$1 != 2) SizedBox(width: S.sm),
          ],
        ],
      ),
    );
  }
}

class TodayChip extends StatelessWidget {
  final bool d;
  final String label;
  final int count;
  final Color col;
  final bool selected;
  final VoidCallback onTap;
  const TodayChip({
    super.key,
    required this.d,
    required this.label,
    required this.count,
    required this.col,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(vertical: S.sm, horizontal: S.xs),
        decoration: BoxDecoration(
          color: selected ? col.withValues(alpha: 0.12) : AppColors.surface(d),
          borderRadius: BorderRadius.circular(S.radiusFull),
          border: Border.all(
            color: selected ? col : AppColors.border(d),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected ? col : AppColors.textSecondary(d),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (count > 0) ...[
              SizedBox(width: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? col : AppColors.textMuted(d).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(S.radiusFull),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: selected ? Colors.white : AppColors.textMuted(d),
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

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class SidebarHeader extends StatelessWidget {
  final bool d;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  const SidebarHeader({super.key, required this.d, required this.expanded, required this.onToggleExpanded});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(expanded ? 16 : 12, 16, expanded ? 12 : 12, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(12),
                          ),
            child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 22),
          ),
          if (expanded) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Revision',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.textPrimary(d),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Tracker',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted(d),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Collapse/expand lives only in the footer (bottom), not the header.
        ],
      ),
    );
  }
}

class SidebarItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool d;
  final bool expanded;
  final bool selected;
  final ValueChanged<int> onSelect;
  const SidebarItem({
    super.key,
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.d,
    required this.expanded,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? AppColors.primary.withValues(alpha: 0.14)
        : Colors.transparent;
    final fg = selected ? AppColors.primary : AppColors.textSecondary(d);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onSelect(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? 12 : 0,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.25)
                    : Colors.transparent,
              ),
            ),
            child: expanded
                ? Row(
                    children: [
                      Icon(selected ? activeIcon : icon, color: fg, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleSmall.copyWith(
                            color: selected
                                ? AppColors.primary
                                : AppColors.textPrimary(d),
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (selected)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  )
                : Center(
                    child: Icon(
                      selected ? activeIcon : icon,
                      color: fg,
                      size: 24,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class SidebarFooter extends StatelessWidget {
  final bool d;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  const SidebarFooter({super.key, required this.d, required this.expanded, required this.onToggleExpanded});

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: IconButton(
          onPressed: onToggleExpanded,
          tooltip: 'Expand',
          icon: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted(d)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.psychology_rounded, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Voice assistant ready',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary(d),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Collapse control — bottom only (never in the header).
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onToggleExpanded,
              icon: Icon(Icons.menu_open_rounded, size: 18, color: AppColors.textMuted(d)),
              label: Text(
                'Collapse',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted(d)),
              ),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

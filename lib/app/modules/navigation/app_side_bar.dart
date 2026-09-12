import 'package:flutter/material.dart';

import '../../core/constants/responsive.dart';
import '../../theme/app_theme.dart';

/// Card-styled desktop/tablet sidebar with expand / collapse.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
    required this.expanded,
    required this.onToggleExpanded,
  });

  /// Rail index: 0 Dashboard, 1 Subjects, 2 Today, 3 Routine, 4 Settings.
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  static const double expandedWidth = 248;
  static const double collapsedWidth = 76;

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    final w = expanded ? expandedWidth : collapsedWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: w,
      decoration: BoxDecoration(
        color: AppColors.surface(d),
        border: Border(right: BorderSide(color: AppColors.border(d))),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(d),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 10),
                children: [
                  _item(0, Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard', d),
                  _item(1, Icons.menu_book_outlined, Icons.menu_book_rounded, 'Subjects', d),
                  _item(2, Icons.today_outlined, Icons.today_rounded, 'Today', d),
                  _item(3, Icons.event_note_outlined, Icons.event_note_rounded, 'Routine', d),
                  // Calendar lives inside the Today pane — not a sidebar tab.
                  _item(4, Icons.settings_outlined, Icons.settings_rounded, 'Settings', d),
                ],
              ),
            ),
            _footer(d),
          ],
        ),
      ),
    );
  }

  Widget _header(bool d) {
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
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
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
          IconButton(
            onPressed: onToggleExpanded,
            tooltip: expanded ? 'Collapse' : 'Expand',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              expanded ? Icons.menu_open_rounded : Icons.menu_rounded,
              color: AppColors.textMuted(d),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(int index, IconData icon, IconData activeIcon, String label, bool d) {
    final selected = selectedIndex == index;
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

  Widget _footer(bool d) {
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
      child: Container(
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
    );
  }
}

/// Compact helper so callers don't import Responsive just for the default.
bool sidebarDefaultExpanded() => Responsive.width >= 1180;

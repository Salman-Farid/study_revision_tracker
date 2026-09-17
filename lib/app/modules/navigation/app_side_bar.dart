import 'package:flutter/material.dart';

import '../../core/constants/responsive.dart';
import '../../theme/app_theme.dart';
import 'widgets/sidebar_parts.dart';

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
            SidebarHeader(d: d, expanded: expanded, onToggleExpanded: onToggleExpanded),
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
            SidebarFooter(d: d, expanded: expanded, onToggleExpanded: onToggleExpanded),
          ],
        ),
      ),
    );
  }

  Widget _item(int index, IconData icon, IconData activeIcon, String label, bool d) {
    return SidebarItem(
      index: index,
      icon: icon,
      activeIcon: activeIcon,
      label: label,
      d: d,
      expanded: expanded,
      selected: selectedIndex == index,
      onSelect: onSelect,
    );
  }
}

/// Compact helper so callers don't import Responsive just for the default.
bool sidebarDefaultExpanded() => Responsive.width >= 1180;

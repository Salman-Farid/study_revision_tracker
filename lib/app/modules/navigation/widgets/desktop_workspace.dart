import 'package:flutter/material.dart';
import '../../../core/constants/responsive.dart';
import '../../../theme/app_theme.dart';
import '../../settings/about_this_app_panel.dart';
import '../../settings/settings_screen.dart';
import 'nav_panes.dart';

/// Desktop tablet workspace: side-by-side panes with card chrome.
class DesktopWorkspace extends StatelessWidget {
  final int primary;
  final bool d;
  final List<Widget> Function(int primary) panesFor;
  const DesktopWorkspace({
    super.key,
    required this.primary,
    required this.d,
    required this.panesFor,
  });

  @override
  Widget build(BuildContext context) {
    final panes = panesFor(primary);
    final d = Theme.of(context).brightness == Brightness.dark;
    final edge = Color.lerp(
      AppColors.border(d),
      AppColors.textMuted(d),
      d ? 0.45 : 0.40,
    )!;

    if (panes.length == 1) {
      return Padding(
        padding: const EdgeInsets.all(12),
        // Always frame the pane — no elevation; border keeps it a distinct screen.
        child: PaneFrame(showBorder: true, child: panes.first),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Responsive.workspaceMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < panes.length; i++) ...[
                if (i > 0) ...[
                  const SizedBox(width: 10),
                  // Explicit divider between split screens (flat, no shadow).
                  Container(width: 1, color: edge),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: i == 0 ? 5 : 6,
                  child: PaneFrame(showBorder: true, child: panes[i]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsSplitWorkspace extends StatelessWidget {
  const SettingsSplitWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    final edge = Color.lerp(
      AppColors.border(d),
      AppColors.textMuted(d),
      d ? 0.45 : 0.40,
    )!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: PaneFrame(
              showBorder: true,
              child: const SettingsScreen(),
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, color: edge),
          const SizedBox(width: 10),
          Expanded(
            flex: 6,
            child: PaneFrame(
              showBorder: true,
              child: const AboutThisAppPanel(),
            ),
          ),
        ],
      ),
    );
  }
}

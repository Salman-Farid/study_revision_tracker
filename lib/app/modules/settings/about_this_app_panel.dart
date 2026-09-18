import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'widgets/about_intro_cards.dart';
import 'widgets/about_putu_panel.dart';
import 'widgets/about_sections.dart';
import 'widgets/about_shared.dart';

class AboutThisAppPanel extends StatefulWidget {
  const AboutThisAppPanel({super.key});

  @override
  State<AboutThisAppPanel> createState() => _AboutThisAppPanelState();
}

class _AboutThisAppPanelState extends State<AboutThisAppPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Animation<double> _fade(int index) {
    final start = (index * 0.06).clamp(0.0, 0.75);
    return CurvedAnimation(
      parent: _ctrl,
      curve: Interval(start, (start + 0.3).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: AppColors.bg(d),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        children: [
          Text(
            'About Us',
            style: AppTextStyles.headlineMedium.copyWith(
              color: AppColors.textPrimary(d),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _stagger(0, AboutHero(d: d)),
          const SizedBox(height: 14),
          _stagger(1, AboutProblemCard(d: d)),
          const SizedBox(height: 10),
          _stagger(2, AboutSolveCard(d: d)),
          const SizedBox(height: 18),

          // ── AI is the headline feature ──
          _stagger(3, AboutPutuHeader(d: d)),
          const SizedBox(height: 10),
          _stagger(4, AboutPutuCapabilityPanel(d: d)),
          const SizedBox(height: 18),

          _stagger(5, AboutSectionTitle(text: 'Beyond revisions', d: d)),
          const SizedBox(height: 10),
          _stagger(6, AboutBeyondGrid(d: d)),
          const SizedBox(height: 18),
          _stagger(7, AboutSectionTitle(text: 'Where to go (manual)', d: d)),
          const SizedBox(height: 10),
          _stagger(8, AboutManualList(d: d)),
          const SizedBox(height: 18),
          _stagger(9, AboutSpacedCard(d: d)),
          const SizedBox(height: 12),
          _stagger(10, AboutFooter(d: d)),
        ],
      ),
    );
  }

  Widget _stagger(int i, Widget child) {
    return FadeTransition(
      opacity: _fade(i),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
            .animate(_fade(i)),
        child: child,
      ),
    );
  }
}

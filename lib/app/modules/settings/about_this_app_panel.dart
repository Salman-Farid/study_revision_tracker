import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Soft-tint helper: ~1–4% brand color over white/dark surface.
Color _tint(Color brand, bool dark, {double amount = 0.04}) {
  final base = dark ? const Color(0xFF1A1D26) : Colors.white;
  return Color.lerp(base, brand, dark ? amount + 0.06 : amount)!;
}

class AboutThisAppPanel extends StatefulWidget {
  const AboutThisAppPanel({super.key});

  @override
  State<AboutThisAppPanel> createState() => _AboutThisAppPanelState();
}

class _AboutThisAppPanelState extends State<AboutThisAppPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const _putuPurple = Color(0xFF9B7BFF);
  static const _putuTeal = Color(0xFF00897B);
  static const _putuBlue = Color(0xFF5B8DEF);
  static const _putuGreen = Color(0xFF4CAF7A);
  static const _putuOrange = Color(0xFFEF6C00);
  static const _putuRose = Color(0xFFEF6B8A);

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
          _stagger(0, _hero(d)),
          const SizedBox(height: 14),
          _stagger(1, _problemCard(d)),
          const SizedBox(height: 10),
          _stagger(2, _solveCard(d)),
          const SizedBox(height: 18),

          // ── AI is the headline feature ──
          _stagger(3, _putuHeader(d)),
          const SizedBox(height: 10),
          _stagger(4, _putuCapabilityPanel(d)),
          const SizedBox(height: 18),

          _stagger(5, _sectionTitle('Beyond revisions', d)),
          const SizedBox(height: 10),
          _stagger(6, _beyondGrid(d)),
          const SizedBox(height: 18),
          _stagger(7, _sectionTitle('Where to go (manual)', d)),
          const SizedBox(height: 10),
          _stagger(8, _manualList(d)),
          const SizedBox(height: 18),
          _stagger(9, _spacedCard(d)),
          const SizedBox(height: 12),
          _stagger(10, _footer(d)),
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

  Widget _sectionTitle(String text, bool d) => Text(
        text,
        style: AppTextStyles.titleMedium.copyWith(
          color: AppColors.textPrimary(d),
          fontWeight: FontWeight.w700,
        ),
      );

  Widget _card({
    required bool d,
    required Widget child,
    Color? tint,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint ?? AppColors.surface(d),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(d).withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: d ? 0.2 : 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _iconBubble(Color color, IconData icon, bool d, {double size = 40}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _tint(color, d, amount: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }

  Widget _hero(bool d) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          SizedBox(
            height: 160,
            width: double.infinity,
            child: Image.asset(
              'assets/images/auth_study.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => ColoredBox(
                color: _tint(AppColors.primary, d, amount: 0.08),
                child: const Center(
                  child: Icon(Icons.menu_book_rounded, size: 56, color: Colors.white70),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Revision Tracker',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Revision · Routines · Widgets · Voice AI (Putu)',
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _problemCard(bool d) {
    return _card(
      d: d,
      tint: _tint(_putuRose, d, amount: 0.03),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBubble(_putuRose, Icons.warning_amber_rounded, d, size: 32),
              const SizedBox(width: 10),
              Text(
                'The Problem',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.textPrimary(d),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _bullet('Study once → forget in hours or days (no structured review)', d),
          _bullet('No clear record of when / which subject / which topic you studied', d),
          _bullet('Plans scattered: paper, notes, calendars, many apps', d),
          _bullet('Class routine and personal study plan live apart from revisions', d),
          _bullet('Hard to see what’s done, what’s left, and what to study next', d),
          _bullet('Little progress tracking by subject & topic', d),
          _bullet('Energy wasted planning instead of studying', d),
          _bullet('Worse for competitive exams (BCS, NEET, JEE, UPSC, …) with huge syllabi', d),
        ],
      ),
    );
  }

  Widget _solveCard(bool d) {
    return _card(
      d: d,
      tint: _tint(_putuGreen, d, amount: 0.03),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBubble(_putuGreen, Icons.check_circle_rounded, d, size: 32),
              const SizedBox(width: 10),
              Text(
                'The Solve',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.textPrimary(d),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _bullet('One workspace for subjects, topics, and first-read tracking', d),
          _bullet('Auto spaced revisions: Day 1 · 3 · 7 · 14 · 30 · 90', d),
          _bullet('Today · Missed · Coming Up — always know the next step', d),
          _bullet('Class + daily routines in the same place as revisions', d),
          _bullet('Completed vs remaining, history, streaks, completion stats', d),
          _bullet('Reminders for revisions, classes & the current daily block', d),
          _bullet('Android widgets — see what to do without opening the app', d),
          _bullet('Putu (voice) — add, complete, plan, delete without typing', d),
        ],
      ),
    );
  }

  Widget _bullet(String text, bool d) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted(d),
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary(d),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PUTU (major feature) ─────────────────────────────────────

  Widget _putuHeader(bool d) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_putuPurple, AppColors.primary],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Putu — your voice study AI',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary(d),
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Major feature · hands-free control of your study data',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _putuCapabilityPanel(bool d) {
    final caps = <_Capability>[
      _Capability(
        Icons.add_circle_outline_rounded,
        'Add subjects & topics',
        'Say “Add Biology” or “Add topic Photosynthesis under Biology” — rows appear in the DB instantly.',
        _putuPurple,
      ),
      _Capability(
        Icons.check_circle_outline_rounded,
        'Mark work completed',
        '“Mark first read done for Algorithm” or “complete Day 3 revision of Geometry” — schedules unlock automatically.',
        _putuGreen,
      ),
      _Capability(
        Icons.quiz_outlined,
        'Tell you what’s due when',
        '“Which topics need revision this week?” Putu reads your real schedules and answers with dates.',
        _putuBlue,
      ),
      _Capability(
        Icons.insights_rounded,
        'Study performance & situation',
        'Ask for progress, overdue load, or how you’re doing — Putu summarizes counts from your live data, not guesses.',
        _putuTeal,
      ),
      _Capability(
        Icons.auto_awesome_motion_rounded,
        'Build a full daily routine',
        '“Plan my day” — creates a comprehensive schedule from your existing subjects/topics, auto-fills today’s classes, and inserts today’s revisions.',
        _putuOrange,
      ),
      _Capability(
        Icons.event_note_rounded,
        'Add class routines by voice',
        '“I have Physics at 10 for 90 minutes in Room 204 on Mon/Wed” — class timetable updates without forms.',
        _putuBlue,
      ),
      _Capability(
        Icons.delete_outline_rounded,
        'Delete anything safely',
        'Remove a subject, topic, or routine with your voice — Putu asks before destructive actions.',
        _putuRose,
      ),
      _Capability(
        Icons.record_voice_over_rounded,
        'True voice-first loop',
        'Speak while your hands stay on the book. Gemini Live streams audio; tools write the same Supabase tables the UI uses.',
        AppColors.primary,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(d),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(d).withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: _putuPurple.withValues(alpha: d ? 0.15 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(
              'What Putu can do — just by talking',
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.textPrimary(d),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Long scrollable capability list inside the About panel.
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: caps.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = caps[i];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _tint(c.color, d, amount: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: c.color.withValues(alpha: d ? 0.2 : 0.12),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _iconBubble(c.color, c.icon, d, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.title,
                            style: AppTextStyles.titleSmall.copyWith(
                              color: AppColors.textPrimary(d),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c.desc,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary(d),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Beyond revisions ─────────────────────────────────────────

  Widget _beyondGrid(bool d) {
    final items = [
      (Icons.event_available_rounded, 'Class routines', 'Recurring timetable with duration & room', _putuTeal),
      (Icons.schedule_rounded, 'Daily routines', 'Study, break, meal, nap blocks for today', _putuOrange),
      (Icons.widgets_rounded, 'Home widgets', 'Revision 3-tab · Class list · Daily countdown', _putuBlue),
      (Icons.notifications_active_rounded, 'Auto reminders', 'Alarms for the current daily block & classes', _putuRose),
      (Icons.menu_book_rounded, 'Subjects & topics', 'Progress bars, reorder, first-read state', AppColors.primary),
      (Icons.calendar_month_rounded, 'Calendar & history', 'Month view, streaks, completion analytics', _putuGreen),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth > 520 ? 2 : 1;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: cols == 2 ? 2.15 : 2.7,
        children: [
          for (final it in items)
            _card(
              d: d,
              tint: _tint(it.$4, d, amount: 0.028),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _iconBubble(it.$4, it.$1, d, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleSmall.copyWith(
                            color: AppColors.textPrimary(d),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          it.$3,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted(d),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    });
  }

  // ── Manual ───────────────────────────────────────────────────

  Widget _manualList(bool d) {
    final rows = [
      ('Dashboard', Icons.dashboard_rounded, 'Counts, overdue, Start Revising shortcut'),
      ('Subjects', Icons.menu_book_rounded, 'Add subjects → open one for topics & revisions'),
      ('Today', Icons.today_rounded, 'Due / Missed / Upcoming — swipe left to complete'),
      ('Routine', Icons.event_note_rounded, 'Class timetable + daily blocks (side-by-side on desktop)'),
      ('Calendar', Icons.calendar_month_rounded, 'See every scheduled revision on the month grid'),
      ('Settings', Icons.settings_rounded, 'Language, theme, reminders, account, this About guide'),
      ('Mic / Putu', Icons.graphic_eq_rounded, 'Open the assistant from Subjects, Routine, or subject detail'),
    ];
    return _card(
      d: d,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.border(d)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _tint(AppColors.primary, d, amount: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(rows[i].$2, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rows[i].$1,
                          style: AppTextStyles.titleSmall.copyWith(
                            color: AppColors.textPrimary(d),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rows[i].$3,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textMuted(d),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _spacedCard(bool d) {
    const days = ['1', '3', '7', '14', '30', '90'];
    const colors = [
      Color(0xFF5B8DEF),
      Color(0xFF4CAF7A),
      Color(0xFF9B7BFF),
      Color(0xFFE8A33D),
      Color(0xFFEF6B8A),
      Color(0xFF3DB8C9),
    ];
    return _card(
      d: d,
      tint: _tint(AppColors.info, d, amount: 0.025),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spaced revision days',
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.textPrimary(d),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Created only after First Read — never on mere add.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _tint(colors[i], d, amount: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Day',
                          style: TextStyle(
                            fontSize: 10,
                            color: colors[i],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          days[i],
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: colors[i],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _footer(bool d) {
    return Center(
      child: Text(
        'One companion: revise smarter · plan the day · speak instead of type.',
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.textMuted(d),
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _Capability {
  const _Capability(this.icon, this.title, this.desc, this.color);
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
}

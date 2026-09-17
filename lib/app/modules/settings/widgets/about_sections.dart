import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'about_shared.dart';

class AboutBeyondGrid extends StatelessWidget {
  final bool d;
  const AboutBeyondGrid({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    const putuTeal = Color(0xFF00897B);
    const putuBlue = Color(0xFF5B8DEF);
    const putuGreen = Color(0xFF4CAF7A);
    const putuOrange = Color(0xFFEF6C00);
    const putuRose = Color(0xFFEF6B8A);

    final items = [
      (Icons.event_available_rounded, 'Class routines', 'Recurring timetable with duration & room', putuTeal),
      (Icons.schedule_rounded, 'Daily routines', 'Study, break, meal, nap blocks for today', putuOrange),
      (Icons.widgets_rounded, 'Home widgets', 'Revision 3-tab · Class list · Daily countdown', putuBlue),
      (Icons.notifications_active_rounded, 'Auto reminders', 'Alarms for the current daily block & classes', putuRose),
      (Icons.menu_book_rounded, 'Subjects & topics', 'Progress bars, reorder, first-read state', AppColors.primary),
      (Icons.calendar_month_rounded, 'Calendar & history', 'Month view, streaks, completion analytics', putuGreen),
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
            AboutCard(
              d: d,
              tint: aboutTint(it.$4, d, amount: 0.028),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  AboutIconBubble(color: it.$4, icon: it.$1, d: d, size: 36),
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
}

class AboutManualList extends StatelessWidget {
  final bool d;
  const AboutManualList({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Dashboard', Icons.dashboard_rounded, 'Counts, overdue, Start Revising shortcut'),
      ('Subjects', Icons.menu_book_rounded, 'Add subjects → open one for topics & revisions'),
      ('Today', Icons.today_rounded, 'Due / Missed / Upcoming — swipe left to complete'),
      ('Routine', Icons.event_note_rounded, 'Class timetable + daily blocks (side-by-side on desktop)'),
      ('Calendar', Icons.calendar_month_rounded, 'See every scheduled revision on the month grid'),
      ('Settings', Icons.settings_rounded, 'Language, theme, reminders, account, this About guide'),
      ('Mic / Putu', Icons.graphic_eq_rounded, 'Open the assistant from Subjects, Routine, or subject detail'),
    ];
    return AboutCard(
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
                      color: aboutTint(AppColors.primary, d, amount: 0.07),
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
}

class AboutSpacedCard extends StatelessWidget {
  final bool d;
  const AboutSpacedCard({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    const days = ['1', '3', '7', '14', '30', '90'];
    const colors = [
      Color(0xFF5B8DEF),
      Color(0xFF4CAF7A),
      Color(0xFF9B7BFF),
      Color(0xFFE8A33D),
      Color(0xFFEF6B8A),
      Color(0xFF3DB8C9),
    ];
    return AboutCard(
      d: d,
      tint: aboutTint(AppColors.info, d, amount: 0.025),
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
                      color: aboutTint(colors[i], d, amount: 0.10),
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
}

class AboutFooter extends StatelessWidget {
  final bool d;
  const AboutFooter({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
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

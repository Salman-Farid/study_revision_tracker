import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'about_shared.dart';

class AboutPutuHeader extends StatelessWidget {
  final bool d;
  const AboutPutuHeader({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    const putuPurple = Color(0xFF9B7BFF);
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [putuPurple, AppColors.primary],
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
}

class _Capability {
  const _Capability(this.icon, this.title, this.desc, this.color);
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
}

class AboutPutuCapabilityPanel extends StatelessWidget {
  final bool d;
  const AboutPutuCapabilityPanel({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    const putuPurple = Color(0xFF9B7BFF);
    const putuTeal = Color(0xFF00897B);
    const putuBlue = Color(0xFF5B8DEF);
    const putuGreen = Color(0xFF4CAF7A);
    const putuOrange = Color(0xFFEF6C00);
    const putuRose = Color(0xFFEF6B8A);

    final caps = <_Capability>[
      _Capability(
        Icons.add_circle_outline_rounded,
        'Add subjects & topics',
        'Say “Add Biology” or “Add topic Photosynthesis under Biology” — rows appear in the DB instantly.',
        putuPurple,
      ),
      _Capability(
        Icons.check_circle_outline_rounded,
        'Mark work completed',
        '“Mark first read done for Algorithm” or “complete Day 3 revision of Geometry” — schedules unlock automatically.',
        putuGreen,
      ),
      _Capability(
        Icons.quiz_outlined,
        'Tell you what’s due when',
        '“Which topics need revision this week?” Putu reads your real schedules and answers with dates.',
        putuBlue,
      ),
      _Capability(
        Icons.insights_rounded,
        'Study performance & situation',
        'Ask for progress, overdue load, or how you’re doing — Putu summarizes counts from your live data, not guesses.',
        putuTeal,
      ),
      _Capability(
        Icons.auto_awesome_motion_rounded,
        'Build a full daily routine',
        '“Plan my day” — creates a comprehensive schedule from your existing subjects/topics, auto-fills today’s classes, and inserts today’s revisions.',
        putuOrange,
      ),
      _Capability(
        Icons.event_note_rounded,
        'Add class routines by voice',
        '“I have Physics at 10 for 90 minutes in Room 204 on Mon/Wed” — class timetable updates without forms.',
        putuBlue,
      ),
      _Capability(
        Icons.delete_outline_rounded,
        'Delete anything safely',
        'Remove a subject, topic, or routine with your voice — Putu asks before destructive actions.',
        putuRose,
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
            color: putuPurple.withValues(alpha: d ? 0.15 : 0.08),
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
                  color: aboutTint(c.color, d, amount: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: c.color.withValues(alpha: d ? 0.2 : 0.12),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AboutIconBubble(color: c.color, icon: c.icon, d: d, size: 36),
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
}

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import 'about_shared.dart';

class AboutHero extends StatelessWidget {
  final bool d;
  const AboutHero({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
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
                color: aboutTint(AppColors.primary, d, amount: 0.08),
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
}

class AboutProblemCard extends StatelessWidget {
  final bool d;
  const AboutProblemCard({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    const putuRose = Color(0xFFEF6B8A);
    return AboutCard(
      d: d,
      tint: aboutTint(putuRose, d, amount: 0.03),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AboutIconBubble(color: putuRose, icon: Icons.warning_amber_rounded, d: d, size: 32),
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
          AboutBullet(text: 'Study once → forget in hours or days (no structured review)', d: d),
          AboutBullet(text: 'No clear record of when / which subject / which topic you studied', d: d),
          AboutBullet(text: 'Plans scattered: paper, notes, calendars, many apps', d: d),
          AboutBullet(text: 'Class routine and personal study plan live apart from revisions', d: d),
          AboutBullet(text: 'Hard to see what’s done, what’s left, and what to study next', d: d),
          AboutBullet(text: 'Little progress tracking by subject & topic', d: d),
          AboutBullet(text: 'Energy wasted planning instead of studying', d: d),
          AboutBullet(text: 'Worse for competitive exams (BCS, NEET, JEE, UPSC, …) with huge syllabi', d: d),
        ],
      ),
    );
  }
}

class AboutSolveCard extends StatelessWidget {
  final bool d;
  const AboutSolveCard({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    const putuGreen = Color(0xFF4CAF7A);
    return AboutCard(
      d: d,
      tint: aboutTint(putuGreen, d, amount: 0.03),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AboutIconBubble(color: putuGreen, icon: Icons.check_circle_rounded, d: d, size: 32),
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
          AboutBullet(text: 'One workspace for subjects, topics, and first-read tracking', d: d),
          AboutBullet(text: 'Auto spaced revisions: Day 1 · 3 · 7 · 14 · 30 · 90', d: d),
          AboutBullet(text: 'Today · Missed · Coming Up — always know the next step', d: d),
          AboutBullet(text: 'Class + daily routines in the same place as revisions', d: d),
          AboutBullet(text: 'Completed vs remaining, history, streaks, completion stats', d: d),
          AboutBullet(text: 'Reminders for revisions, classes & the current daily block', d: d),
          AboutBullet(text: 'Android widgets — see what to do without opening the app', d: d),
          AboutBullet(text: 'Putu (voice) — add, complete, plan, delete without typing', d: d),
        ],
      ),
    );
  }
}

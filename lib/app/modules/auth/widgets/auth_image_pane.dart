import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class AuthImagePane extends StatelessWidget {
  final bool d;
  const AuthImagePane({super.key, required this.d});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        border: Border(
          right: BorderSide(color: AppColors.border(d)),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/auth_study.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackArt(d),
          ),
          // Soft wash toward the form side so fields stay the focus.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  AppColors.bg(d).withValues(alpha: 0.4),
                ],
              ),
            ),
          ),
          Positioned(
            left: 28,
            right: 28,
            bottom: 36,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Revision Tracker',
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Spaced revisions · Daily & class routines · Voice assistant',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackArt(bool d) {
    return ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.12),
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 120,
          color: AppColors.primary.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

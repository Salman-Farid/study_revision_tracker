import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Soft-tint helper: ~1–4% brand color over white/dark surface.
Color aboutTint(Color brand, bool dark, {double amount = 0.04}) {
  final base = dark ? const Color(0xFF1A1D26) : Colors.white;
  return Color.lerp(base, brand, dark ? amount + 0.06 : amount)!;
}

class AboutIconBubble extends StatelessWidget {
  final Color color;
  final IconData icon;
  final bool d;
  final double size;
  const AboutIconBubble({super.key, required this.color, required this.icon, required this.d, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: aboutTint(color, d, amount: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

class AboutCard extends StatelessWidget {
  final bool d;
  final Widget child;
  final Color? tint;
  final EdgeInsetsGeometry? padding;
  const AboutCard({super.key, required this.d, required this.child, this.tint, this.padding});

  @override
  Widget build(BuildContext context) {
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
}

class AboutBullet extends StatelessWidget {
  final String text;
  final bool d;
  const AboutBullet({super.key, required this.text, required this.d});

  @override
  Widget build(BuildContext context) {
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
}

class AboutSectionTitle extends StatelessWidget {
  final String text;
  final bool d;
  const AboutSectionTitle({super.key, required this.text, required this.d});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.titleMedium.copyWith(
        color: AppColors.textPrimary(d),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

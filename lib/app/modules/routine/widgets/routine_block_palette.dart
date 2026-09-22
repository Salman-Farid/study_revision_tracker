import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../theme/app_theme.dart';

/// Shared soft-block colors — Routine tab tiles and Dashboard live card
/// must look identical (99% white, ~1% type tint + matching accent).
class RoutineBlockPalette {
  const RoutineBlockPalette._();

  /// Soft background color per block type (99% white, 1% tint)
  static Color bg(String type) {
    switch (type) {
      case 'class':
        return const Color(0xFFF8FAFF); // barely-there blue
      case 'study':
      case 'first_read':
      case 'revision':
        return const Color(0xFFF7FBF7); // barely-there green
      case 'break':
        return const Color(0xFFFEFCF6); // barely-there amber
      case 'meal':
        return const Color(0xFFFEF8FA); // barely-there pink
      case 'nap':
        return const Color(0xFFFBF8FE); // barely-there purple
      case 'freshen_up':
        return const Color(0xFFF3FBFA); // barely-there teal
      case 'recall':
        return const Color(0xFFF6FDFE); // barely-there cyan
      case 'question_practice':
        return const Color(0xFFFEFAF5); // barely-there orange
      case 'review':
        return const Color(0xFFF6FDF8); // barely-there teal
      default:
        return AppColors.surfaceLight;
    }
  }

  /// Accent color for icon / strip / badges
  static Color accent(String type) {
    switch (type) {
      case 'class':
        return const Color(0xFF5B8DEF); // blue
      case 'study':
      case 'first_read':
      case 'revision':
        return const Color(0xFF4CAF50); // green
      case 'break':
        return const Color(0xFFFFB74D); // amber
      case 'meal':
        return const Color(0xFFEC407A); // pink
      case 'nap':
        return const Color(0xFFAB7EFF); // purple
      case 'freshen_up':
        return const Color(0xFF26A69A); // teal
      case 'recall':
        return const Color(0xFF26C6DA); // cyan
      case 'question_practice':
        return const Color(0xFFFF9800); // orange
      case 'review':
        return const Color(0xFF66BB6A); // teal
      default:
        return AppConstants.primaryColor;
    }
  }

  static IconData icon(String type) {
    switch (type) {
      case 'class':
        return Icons.school_rounded;
      case 'break':
        return Icons.coffee_rounded;
      case 'meal':
        return Icons.restaurant_rounded;
      case 'nap':
        return Icons.bedtime_rounded;
      case 'freshen_up':
        return Icons.shower_rounded;
      case 'recall':
        return Icons.psychology_rounded;
      case 'question_practice':
        return Icons.quiz_rounded;
      case 'review':
        return Icons.replay_rounded;
      case 'study':
      case 'first_read':
      case 'revision':
      default:
        return Icons.menu_book_rounded;
    }
  }
}

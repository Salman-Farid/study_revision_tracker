import 'package:flutter/material.dart';

/// Resolves stored subject `icon_code_point` values to **const** [IconData].
///
/// Flutter can tree-shake MaterialIcons only when icons are compile-time
/// constants. Dynamic `IconData(codePoint)` forces the full 1.6 MB font into
/// every release APK. Map DB values through this table instead.
class SubjectIcons {
  const SubjectIcons._();

  /// Default when a subject has no icon (matches `icon_code_point` default).
  static const IconData fallback = Icons.menu_book_rounded;

  /// Code-point → const icon. Keep in sync with any UI that lets users pick icons.
  static const Map<int, IconData> byCodePoint = {
    0xe8a1: Icons.menu_book_rounded, // material "menu_book" (default)
    0xe80c: Icons.school_rounded,
    0xe80d: Icons.school_outlined,
    0xe8b0: Icons.psychology_rounded,
    0xe3af: Icons.calculate_rounded,
    0xe3a9: Icons.science_rounded,
    0xe30d: Icons.computer_rounded,
    0xe559: Icons.language_rounded,
    0xe3c9: Icons.history_edu_rounded,
    0xe3e5: Icons.biotech_rounded,
    0xe0c3: Icons.auto_stories_rounded,
    0xe567: Icons.lightbulb_rounded,
    0xe8f4: Icons.edit_note_rounded,
  };

  /// Safe lookup — unknown codes fall back to [fallback].
  static IconData forCodePoint(int? codePoint) {
    if (codePoint == null) return fallback;
    return byCodePoint[codePoint] ?? fallback;
  }
}

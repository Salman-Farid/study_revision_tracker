/// Pure helpers for matching a class-routine row to a calendar day.
/// No Flutter / Supabase — unit-testable.
class ClassDayMatcher {
  /// True if [dates] / [recurringDays] apply on [day].
  ///
  /// Tolerates ISO timestamps, weekday names (full or 3-letter), numeric
  /// weekdays stored as strings, and a missing `recurring` flag when
  /// `recurringDays` is set.
  static bool matchesDay({
    required List<String> dates,
    required List<int> recurringDays,
    required DateTime day,
  }) {
    final dateStr =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    const weekdayNames = [
      '', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday',
    ];
    const weekdayShort = ['', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final dayName = weekdayNames[day.weekday];
    final dayShort = weekdayShort[day.weekday];

    for (final raw in dates) {
      final d = raw.trim();
      if (d.isEmpty) continue;
      if (d == dateStr || d.startsWith(dateStr)) return true;
      final lower = d.toLowerCase();
      if (lower == dayName || lower == dayShort) return true;
      final asInt = int.tryParse(d);
      if (asInt != null && asInt == day.weekday) return true;
    }
    return recurringDays.contains(day.weekday);
  }
}

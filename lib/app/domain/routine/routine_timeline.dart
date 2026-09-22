/// Pure timeline helpers for daily-routine blocks.
/// No Flutter / Supabase / GetX — fully unit-testable.
import 'routine_time_utils.dart';
import '../../modules/routine/widgets/routine_meal_taglines.dart';

class RoutineTimelineItem {
  final String subject;
  final String topic;
  final String type;
  final String timeText;
  final String endTimeText;
  final String sortKey;
  final DateTime start;
  final DateTime end;
  final String? notes;

  const RoutineTimelineItem({
    required this.subject,
    required this.topic,
    required this.type,
    required this.timeText,
    required this.endTimeText,
    required this.sortKey,
    required this.start,
    required this.end,
    this.notes,
  });

  bool contains(DateTime now) => !now.isBefore(start) && now.isBefore(end);

  bool isAfter(DateTime now) => start.isAfter(now);

  String get displayTitle {
    switch (type) {
      case 'break':
        return 'Break';
      case 'meal':
        return subject.isNotEmpty ? subject : 'Meal';
      case 'nap':
        return 'Power Nap';
      case 'freshen_up':
        return subject.isNotEmpty ? subject : 'Freshen Up';
      case 'recall':
        return 'Active Recall';
      case 'question_practice':
        return 'Question Practice';
      case 'review':
        return 'Quick Review';
      default:
        return subject;
    }
  }

  /// Short tip under the title (meal food tips, break lines, nap note).
  String? get tagline {
    switch (type) {
      case 'break':
        final n = notes?.trim();
        if (n != null && n.isNotEmpty && n != 'After study session') return n;
        return null;
      case 'meal':
        // Never treat a time-range note as a tagline — always a food/brain tip.
        return RoutineMealTaglines.pickFor(
          '$sortKey|$subject|$type|$timeText',
          subject.isEmpty ? 'Meal' : subject,
        );
      case 'nap':
        return 'Power nap for memory consolidation';
      case 'freshen_up':
        final n = notes?.trim();
        return (n != null && n.isNotEmpty) ? n : 'Wash up, brush your teeth, get ready for the day.';
      case 'question_practice':
        return 'Solve problems, don\'t just read';
      default:
        return null;
    }
  }
}

class RoutineTimeline {
  /// Convert "HH:mm" 24h to "h:mm AM/PM".
  static String to12Hour(int hour, int minute) => formatHm12(hour, minute);

  /// Parse "HH:mm" (tolerant of missing parts).
  static (int, int) parseTime(String time) {
    final parts = time.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return (h, m);
  }

  static DateTime startOfDay(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Build sorted items for [day] from raw `{time, subject, topic, type, durationMinutes}` maps.
  static List<RoutineTimelineItem> buildDayItems({
    required DateTime day,
    required List<Map<String, dynamic>> rawItems,
  }) {
    final today = startOfDay(day);
    final items = <RoutineTimelineItem>[];
    for (final item in rawItems) {
      final time = (item['time'] as String?) ?? '';
      final subject = (item['subject'] as String?) ?? '';
      final topic = (item['topic'] as String?) ?? '';
      final type = (item['type'] as String?) ?? 'study';
      final durationMinutes = (item['duration_minutes'] as num?)?.toInt() ?? 45;
      final (h, m) = parseTime(time);
      final start = DateTime(today.year, today.month, today.day, h, m);
      final end = start.add(Duration(minutes: durationMinutes));
      items.add(RoutineTimelineItem(
        subject: subject,
        topic: topic,
        type: type,
        timeText: to12Hour(h, m),
        endTimeText: to12Hour(end.hour, end.minute),
        sortKey: time,
        start: start,
        end: end,
        notes: (item['notes'] as String?)?.trim().isEmpty == false
            ? (item['notes'] as String).trim()
            : null,
      ));
    }
    items.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return items;
  }

  /// Active block at [now], or null.
  static RoutineTimelineItem? currentOf(
    List<RoutineTimelineItem> items,
    DateTime now,
  ) {
    for (final it in items) {
      if (it.contains(now)) return it;
    }
    return null;
  }

  /// Active block at [now], or the next block that still has time left.
  /// Never returns an already-finished block — avoids "+mm:ss" count-up.
  static RoutineTimelineItem? activeOrNext(
    List<RoutineTimelineItem> items,
    DateTime now,
  ) {
    for (final it in items) {
      if (it.contains(now)) return it;
    }
    for (final it in items) {
      if (it.end.isAfter(now)) return it;
    }
    return null;
  }

  /// Blocks starting after [now].
  static List<RoutineTimelineItem> upcomingOf(
    List<RoutineTimelineItem> items,
    DateTime now,
  ) =>
      items.where((it) => it.isAfter(now)).toList(growable: false);

  /// Consecutive-day streak ending at [today] given completed-day set.
  static int streakDays(Set<DateTime> completedDays, DateTime today) {
    return activityStreak(completedDays, today);
  }

  /// Study streak: consecutive days with activity.
  /// - Counts days ending **today**, or **yesterday** if the user has not
  ///   studied yet today (so the streak does not collapse to 0 every morning).
  /// - [activityDays] = any local calendar day with completed work.
  static int activityStreak(Set<DateTime> activityDays, DateTime today) {
    if (activityDays.isEmpty) return 0;
    final t = startOfDay(today);
    var anchor = t;
    if (!activityDays.contains(anchor)) {
      final yesterday = t.subtract(const Duration(days: 1));
      if (!activityDays.contains(yesterday)) return 0;
      anchor = yesterday;
    }
    int streak = 0;
    var check = anchor;
    while (activityDays.contains(check)) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Local calendar day for streak counting (avoids UTC day-shift bugs).
  static DateTime activityDay(DateTime localOrUtc) =>
      DateTime(localOrUtc.year, localOrUtc.month, localOrUtc.day);
}

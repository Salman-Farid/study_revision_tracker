/// Pure timeline helpers for daily-routine blocks.
/// No Flutter / Supabase / GetX — fully unit-testable.
import 'routine_time_utils.dart';

class RoutineTimelineItem {
  final String subject;
  final String topic;
  final String type;
  final String timeText;
  final String endTimeText;
  final String sortKey;
  final DateTime start;
  final DateTime end;

  const RoutineTimelineItem({
    required this.subject,
    required this.topic,
    required this.type,
    required this.timeText,
    required this.endTimeText,
    required this.sortKey,
    required this.start,
    required this.end,
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

  /// Blocks starting after [now].
  static List<RoutineTimelineItem> upcomingOf(
    List<RoutineTimelineItem> items,
    DateTime now,
  ) =>
      items.where((it) => it.isAfter(now)).toList(growable: false);

  /// Consecutive-day streak ending at [today] given completed-day set.
  static int streakDays(Set<DateTime> completedDays, DateTime today) {
    final t = startOfDay(today);
    int streak = 0;
    var checkDate = t;
    while (completedDays.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

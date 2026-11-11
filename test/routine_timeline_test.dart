import 'package:flutter_test/flutter_test.dart';
import 'package:study_revision_tracker/app/domain/routine/routine_time_utils.dart';
import 'package:study_revision_tracker/app/domain/routine/routine_timeline.dart';

void main() {
  group('formatHm12', () {
    test('formats midnight, noon, afternoon', () {
      expect(formatHm12(0, 5), '12:05 AM');
      expect(formatHm12(12, 0), '12:00 PM');
      expect(formatHm12(14, 30), '2:30 PM');
    });
  });

  group('RoutineTimeline.to12Hour', () {
    test('formats midnight as 12 AM', () {
      expect(RoutineTimeline.to12Hour(0, 5), '12:05 AM');
    });
    test('formats noon as 12 PM', () {
      expect(RoutineTimeline.to12Hour(12, 0), '12:00 PM');
    });
    test('formats afternoon', () {
      expect(RoutineTimeline.to12Hour(14, 30), '2:30 PM');
    });
  });

  group('RoutineTimeline.parseTime', () {
    test('parses HH:mm', () {
      expect(RoutineTimeline.parseTime('09:15'), (9, 15));
    });
    test('tolerates missing minutes', () {
      expect(RoutineTimeline.parseTime('08'), (8, 0));
    });
    test('tolerates empty', () {
      expect(RoutineTimeline.parseTime(''), (0, 0));
    });
  });

  group('RoutineTimeline.buildDayItems', () {
    test('sorts by time and computes end times', () {
      final items = RoutineTimeline.buildDayItems(
        day: DateTime(2026, 9, 17),
        rawItems: [
          {'time': '10:00', 'subject': 'Math', 'duration_minutes': 50},
          {'time': '09:00', 'subject': 'Physics', 'duration_minutes': 45},
        ],
      );
      expect(items.first.subject, 'Physics');
      expect(items.last.subject, 'Math');
      expect(items.first.endTimeText, '9:45 AM');
      expect(items.last.endTimeText, '10:50 AM');
    });
  });

  group('RoutineTimeline.current/upcoming', () {
    final day = DateTime(2026, 9, 17);
    final items = RoutineTimeline.buildDayItems(
      day: day,
      rawItems: [
        {'time': '09:00', 'subject': 'A', 'duration_minutes': 60},
        {'time': '10:00', 'subject': 'B', 'duration_minutes': 60},
        {'time': '11:00', 'subject': 'C', 'duration_minutes': 60},
      ],
    );

    test('detects current block', () {
      final now = DateTime(2026, 9, 17, 10, 15);
      expect(RoutineTimeline.currentOf(items, now)?.subject, 'B');
      expect(RoutineTimeline.upcomingOf(items, now).map((e) => e.subject),
          ['C']);
    });

    test('no current after last block', () {
      final now = DateTime(2026, 9, 17, 13, 0);
      expect(RoutineTimeline.currentOf(items, now), isNull);
      expect(RoutineTimeline.upcomingOf(items, now), isEmpty);
    });
  });

  group('RoutineTimeline.streakDays', () {
    test('counts consecutive completed days', () {
      final today = DateTime(2026, 9, 17);
      final completed = {
        DateTime(2026, 9, 17),
        DateTime(2026, 9, 16),
        DateTime(2026, 9, 15),
        DateTime(2026, 9, 13), // gap — must stop
      };
      expect(RoutineTimeline.streakDays(completed, today), 3);
    });

    test('counts yesterday when today not completed (no morning reset)', () {
      final today = DateTime(2026, 9, 17);
      expect(RoutineTimeline.streakDays({DateTime(2026, 9, 16)}, today), 1);
    });

    test('zero when neither today nor yesterday completed', () {
      final today = DateTime(2026, 9, 17);
      expect(RoutineTimeline.streakDays({DateTime(2026, 9, 15)}, today), 0);
    });
  });

  group('displayTitle', () {
    RoutineTimelineItem item(String type, {String subject = ''}) =>
        RoutineTimelineItem(
          subject: subject,
          topic: '',
          type: type,
          timeText: '',
          endTimeText: '',
          sortKey: '',
          start: DateTime(2026, 9, 17, 9),
          end: DateTime(2026, 9, 17, 10),
        );

    test('maps special types', () {
      expect(item('break').displayTitle, 'Break');
      expect(item('nap').displayTitle, 'Power Nap');
      expect(item('recall').displayTitle, 'Active Recall');
      expect(item('meal', subject: 'Lunch').displayTitle, 'Lunch');
      expect(item('study', subject: 'Math').displayTitle, 'Math');
    });
  });
}

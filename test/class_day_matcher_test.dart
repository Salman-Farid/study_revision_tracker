import 'package:flutter_test/flutter_test.dart';
import 'package:study_revision_tracker/app/domain/routine/class_day_matcher.dart';

void main() {
  // 2026-09-17 is a Thursday (weekday 4).
  final thursday = DateTime(2026, 9, 17);

  test('matches exact date string', () {
    expect(
      ClassDayMatcher.matchesDay(
        dates: ['2026-09-17'],
        recurringDays: const [],
        day: thursday,
      ),
      isTrue,
    );
  });

  test('matches ISO datetime prefix', () {
    expect(
      ClassDayMatcher.matchesDay(
        dates: ['2026-09-17T09:00:00.000Z'],
        recurringDays: const [],
        day: thursday,
      ),
      isTrue,
    );
  });

  test('matches weekday name and short name', () {
    expect(
      ClassDayMatcher.matchesDay(
        dates: const ['Thursday'],
        recurringDays: const [],
        day: thursday,
      ),
      isTrue,
    );
    expect(
      ClassDayMatcher.matchesDay(
        dates: const ['thu'],
        recurringDays: const [],
        day: thursday,
      ),
      isTrue,
    );
  });

  test('matches numeric weekday stored as string', () {
    expect(
      ClassDayMatcher.matchesDay(
        dates: const ['4'],
        recurringDays: const [],
        day: thursday,
      ),
      isTrue,
    );
  });

  test('matches recurringDays list', () {
    expect(
      ClassDayMatcher.matchesDay(
        dates: const [],
        recurringDays: const [4, 1],
        day: thursday,
      ),
      isTrue,
    );
    expect(
      ClassDayMatcher.matchesDay(
        dates: const [],
        recurringDays: const [1, 3],
        day: thursday,
      ),
      isFalse,
    );
  });
}

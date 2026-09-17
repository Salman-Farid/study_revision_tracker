# Domain (`lib/app/domain`)

Pure Dart — no Flutter widgets, no Supabase, no GetX.
Easiest place to unit-test. See `test/`.

| File | Purpose |
|------|---------|
| `routine/routine_timeline.dart` | Build day items, current/upcoming block, streak count |
| `routine/class_day_matcher.dart` | Does a class routine apply on this weekday/date? |
| `routine/routine_time_utils.dart` | 12-hour formatting, same-calendar-day |

UI code should call these helpers instead of duplicating date math.

/// Pure time-formatting helpers for routine display.
/// No Flutter / GetX / Supabase — fully unit-testable.

/// Convert "14:30" → "2:30 PM".
String formatTime12Hour(String time24) {
  final parts = time24.split(':');
  if (parts.length != 2) return time24;
  var h = int.tryParse(parts[0]) ?? 0;
  final m = parts[1];
  final period = h >= 12 ? 'PM' : 'AM';
  if (h == 0) h = 12;
  else if (h > 12) h -= 12;
  return '$h:$m $period';
}

/// End time text for a block starting at [start] lasting [durMin] minutes.
String formatEndTimeText(DateTime start, int durMin) {
  final end = start.add(Duration(minutes: durMin));
  var h = end.hour;
  final m = end.minute.toString().padLeft(2, '0');
  final period = h >= 12 ? 'PM' : 'AM';
  if (h == 0) h = 12;
  else if (h > 12) h -= 12;
  return '$h:$m $period';
}

/// True when [a] and [b] fall on the same calendar day.
bool isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Canonical "h:mm AM/PM" formatter from 24h parts.
/// Prefer this over private copies in services/widgets.
String formatHm12(int hour, int minute) {
  final period = hour >= 12 ? 'PM' : 'AM';
  var h = hour;
  if (h == 0) {
    h = 12;
  } else if (h > 12) {
    h -= 12;
  }
  return '$h:${minute.toString().padLeft(2, '0')} $period';
}

/// Parse tolerant "HH:mm" → (hour, minute). Empty/invalid → (0, 0).
(int, int) parseClockParts(String time) {
  final parts = time.split(':');
  final h = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
  final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
  return (h, m);
}

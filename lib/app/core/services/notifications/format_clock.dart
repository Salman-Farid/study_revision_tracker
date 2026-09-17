part of '../notification_service.dart';

/// Parse "HH:mm" → `[hour, minute]`, or null if invalid.
List<int>? parseClock(String raw) {
  final parts = raw.trim().split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  return [h, m];
}

/// Convert 24h clock to "h:mm AM/PM".
String formatTime12(int hour, int minute) {
  final period = hour >= 12 ? 'PM' : 'AM';
  var h = hour;
  if (h == 0) {
    h = 12;
  } else if (h > 12) {
    h -= 12;
  }
  return '$h:${minute.toString().padLeft(2, '0')} $period';
}

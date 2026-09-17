part of '../notification_service.dart';

/// Deterministic notification id helpers.
int _revisionNotifId(String scheduleId) =>
    scheduleId.hashCode & 0x7FFFFFFF;

int _classNotifId(String routineId, DateTime date) {
  final dayOfYear = date.difference(DateTime(date.year)).inDays;
  return (routineId.hashCode ^ (dayOfYear << 16)) & 0x7FFFFFFF;
}

int _dailyNotifId(String routineId, int itemIndex, DateTime date) {
  final dayOfYear = date.difference(DateTime(date.year)).inDays;
  return (routineId.hashCode ^ (itemIndex << 8) ^ (dayOfYear << 20)) &
      0x7FFFFFFF;
}

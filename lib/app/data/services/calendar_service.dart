import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class CalendarService {
  final DeviceCalendarPlugin _calendarPlugin = DeviceCalendarPlugin();
  tz.Location? _currentLocation;
  bool _timezoneInitialized = false;

  /// Initialize timezone for calendar events
  Future<void> initializeTimezone() async {
    if (_timezoneInitialized) return;
    try {
      tz_data.initializeTimeZones();
      _currentLocation = tz.local;
      _timezoneInitialized = true;
    } catch (e) {
      // Fallback to UTC if timezone detection fails
      _currentLocation = tz.getLocation('Etc/UTC');
    }
  }

  /// Request calendar permissions
  Future<bool> requestPermission() async {
    final permission = await _calendarPlugin.requestPermissions();
    return permission.isSuccess;
  }

  /// Get list of available calendars
  Future<List<Calendar>> getCalendars() async {
    final calendarsResult = await _calendarPlugin.retrieveCalendars();
    return calendarsResult.data ?? [];
  }

  /// Create a revision event in device calendar
  Future<bool> createRevisionEvent({
    required String subjectName,
    required String topicName,
    required DateTime scheduledDate,
    required int dayNumber,
    String? notes,
  }) async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return false;

      final calendars = await getCalendars();
      if (calendars.isEmpty) return false;

      // Use first writable calendar
      final calendar = calendars.firstWhere(
        (c) => c.isReadOnly == false,
        orElse: () => calendars.first,
      );

      final eventTitle = 'Revision: $topicName (Day $dayNumber)';
      final eventDescription = [
        'Subject: $subjectName',
        'Topic: $topicName',
        'Revision Day: $dayNumber',
        if (notes != null) 'Notes: $notes',
      ].join('\n');

      // Create 1-hour event at 9 AM
      final startTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        9,
        0,
      );
      final endTime = startTime.add(const Duration(hours: 1));

      // Convert to TZDateTime
      final location = _currentLocation ?? tz.local;
      final tzStartTime = tz.TZDateTime.from(startTime, location);
      final tzEndTime = tz.TZDateTime.from(endTime, location);

      final event = Event(
        calendar.id,
        title: eventTitle,
        description: eventDescription,
        start: tzStartTime,
        end: tzEndTime,
        allDay: false,
      );

      final result = await _calendarPlugin.createOrUpdateEvent(event);
      return result?.isSuccess ?? false;
    } catch (e) {
      debugPrint('Failed to create calendar event: $e');
      return false;
    }
  }

  /// Create multiple revision events for a topic
  Future<int> createRevisionEvents({
    required String subjectName,
    required String topicName,
    required List<DateTime> scheduledDates,
    String? notes,
  }) async {
    // Ensure timezone is initialized
    await initializeTimezone();

    int created = 0;
    for (int i = 0; i < scheduledDates.length; i++) {
      final success = await createRevisionEvent(
        subjectName: subjectName,
        topicName: topicName,
        scheduledDate: scheduledDates[i],
        dayNumber: i + 1,
        notes: notes,
      );
      if (success) created++;
    }
    return created;
  }

  /// Delete an event by ID
  Future<bool> deleteEvent(String eventId, String calendarId) async {
    try {
      final result = await _calendarPlugin.deleteEvent(calendarId, eventId);
      return result.isSuccess;
    } catch (e) {
      debugPrint('Failed to delete calendar event: $e');
      return false;
    }
  }

  /// Format date for display
  String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(date);
  }
}

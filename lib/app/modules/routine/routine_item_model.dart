import 'package:flutter/material.dart';

/// Status of a routine item.
enum RoutineItemStatus {
  /// Already done.
  completed,

  /// Due right now / today.
  due,

  /// Future / scheduled but not yet due.
  upcoming,

  /// Pending — generic fallback.
  pending,
}

/// Visual / structural kind of a routine item.
enum RoutineItemType {
  /// First-time reading of a brand new topic.
  firstRead,

  /// A revision of a previously read topic.
  revision,

  /// A "class routine" / study session block the user asked Gemini to plan.
  studyBlock,
}

/// A single line item inside a daily-routine plan.
///
/// These items are rendered by `FirstReadCard` and `RevisionCard`. They are
/// pure-data — created by the routine controller when assembling the plan
/// the AI voice assistant builds for the user.
class RoutineItemModel {
  /// Stable id (used by ListView keys, animations).
  final String id;

  /// Display kind of this entry.
  final RoutineItemType type;

  /// Subject display name (e.g. "Physics").
  final String subjectName;

  /// Topic display name (e.g. "Newton's Laws").
  final String topicName;

  /// Revision stage label, e.g. "Day 1", "Day 3". Empty for first-reads.
  final String revisionStageLabel;

  /// Pretty "Day N" label used by the revision card's day badge.
  final String dayNumberLabel;

  /// Optional session number shown in the corner of the card (e.g. "S1", "S2").
  final String? sessionNumber;

  /// Optional time slot for the entry, e.g. "09:00 – 09:45".
  final String? timeSlot;

  /// Optional study / technique hint shown as a callout box.
  final String? technique;

  /// Optional free-form note (e.g. "bring textbook", "review formula sheet").
  final String? notes;

  /// Current completion state.
  final RoutineItemStatus status;

  /// Underlying schedule id (if this item came from a `RevisionScheduleModel`).
  final String? scheduleId;

  /// Underlying topic id (so we can navigate or mutate it).
  final String? topicId;

  /// Underlying subject id.
  final String? subjectId;

  /// The planned date this entry belongs to (used for grouping by day).
  final DateTime date;

  /// Optional icon for the "session type" badge inside the revision card
  /// (e.g. flashcard, problem-solving, mixed drill).
  final IconData? sessionTypeIcon;

  /// Optional label for the "session type" badge (e.g. "Recall drill",
  /// "Problem solving").
  final String? sessionTypeLabel;

  /// Optional block length in minutes — drives the "45 min" badge in the
  /// revision card.
  final int? durationMinutes;

  /// 1-based revision number (1 → Day 1, 2 → Day 3 …). Drives the
  /// coloured "revision strategy" block in the revision card.
  final int? revisionNumber;

  const RoutineItemModel({
    required this.id,
    required this.type,
    required this.subjectName,
    required this.topicName,
    required this.date,
    this.revisionStageLabel = '',
    this.dayNumberLabel = '',
    this.sessionNumber,
    this.timeSlot,
    this.technique,
    this.notes,
    this.status = RoutineItemStatus.upcoming,
    this.scheduleId,
    this.topicId,
    this.subjectId,
    this.sessionTypeIcon,
    this.sessionTypeLabel,
    this.durationMinutes,
    this.revisionNumber,
  });

  /// Type icon shown in the left status circle.
  IconData get typeIcon {
    switch (type) {
      case RoutineItemType.firstRead:
        return Icons.menu_book_rounded;
      case RoutineItemType.revision:
        return Icons.replay_rounded;
      case RoutineItemType.studyBlock:
        return Icons.access_time_rounded;
    }
  }

  /// "Daily routine" grouping key — YYYY-MM-DD.
  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  RoutineItemModel copyWith({
    RoutineItemType? type,
    String? subjectName,
    String? topicName,
    String? revisionStageLabel,
    String? dayNumberLabel,
    String? sessionNumber,
    String? timeSlot,
    String? technique,
    String? notes,
    RoutineItemStatus? status,
    String? scheduleId,
    String? topicId,
    String? subjectId,
    DateTime? date,
    IconData? sessionTypeIcon,
    String? sessionTypeLabel,
    int? durationMinutes,
    int? revisionNumber,
  }) {
    return RoutineItemModel(
      id: id,
      type: type ?? this.type,
      subjectName: subjectName ?? this.subjectName,
      topicName: topicName ?? this.topicName,
      revisionStageLabel: revisionStageLabel ?? this.revisionStageLabel,
      dayNumberLabel: dayNumberLabel ?? this.dayNumberLabel,
      sessionNumber: sessionNumber ?? this.sessionNumber,
      timeSlot: timeSlot ?? this.timeSlot,
      technique: technique ?? this.technique,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      scheduleId: scheduleId ?? this.scheduleId,
      topicId: topicId ?? this.topicId,
      subjectId: subjectId ?? this.subjectId,
      date: date ?? this.date,
      sessionTypeIcon: sessionTypeIcon ?? this.sessionTypeIcon,
      sessionTypeLabel: sessionTypeLabel ?? this.sessionTypeLabel,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      revisionNumber: revisionNumber ?? this.revisionNumber,
    );
  }
}

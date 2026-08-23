class RevisionScheduleModel {
  final String id, userId, topicId, subjectId, status;
  final DateTime scheduledDate;
  final int dayNumber;
  final String? rescheduledTo;
  final DateTime createdAt, updatedAt;

  RevisionScheduleModel({
    required this.id, required this.userId, required this.topicId, required this.subjectId,
    required this.scheduledDate, required this.dayNumber, this.status = 'pending',
    this.rescheduledTo, required this.createdAt, required this.updatedAt,
  });

  factory RevisionScheduleModel.fromJson(Map<String, dynamic> j) => RevisionScheduleModel(
    id: j['id'], userId: j['user_id'], topicId: j['topic_id'], subjectId: j['subject_id'],
    scheduledDate: DateTime.parse(j['scheduled_date']), dayNumber: j['day_number'],
    status: j['status'] ?? 'pending', rescheduledTo: j['rescheduled_to'],
    createdAt: DateTime.parse(j['created_at']), updatedAt: DateTime.parse(j['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'user_id': userId, 'topic_id': topicId, 'subject_id': subjectId,
    'scheduled_date': scheduledDate.toIso8601String(), 'day_number': dayNumber,
    'status': status, 'rescheduled_to': rescheduledTo,
    'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String(),
  };

  RevisionScheduleModel copyWith({String? status, String? rescheduledTo}) =>
    RevisionScheduleModel(id: id, userId: userId, topicId: topicId, subjectId: subjectId,
      scheduledDate: scheduledDate, dayNumber: dayNumber, status: status ?? this.status,
      rescheduledTo: rescheduledTo ?? this.rescheduledTo,
      createdAt: createdAt, updatedAt: DateTime.now());
}

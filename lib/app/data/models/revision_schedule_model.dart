class RevisionScheduleModel {
  final String id, userId, topicId, subjectId, status;
  final DateTime scheduledDate;
  final int dayNumber;
  final String? rescheduledTo;
  final DateTime createdAt, updatedAt;

  // Enriched names (populated after fetch, not persisted)
  final String? topicName;
  final String? subjectName;
  /// When topic is a subtopic — name of its parent topic.
  final String? parentTopicName;

  RevisionScheduleModel({
    required this.id, required this.userId, required this.topicId, required this.subjectId,
    required this.scheduledDate, required this.dayNumber, this.status = 'pending',
    this.rescheduledTo, required this.createdAt, required this.updatedAt,
    this.topicName, this.subjectName, this.parentTopicName,
  });

  factory RevisionScheduleModel.fromJson(Map<String, dynamic> j) => RevisionScheduleModel(
    id: j['id'], userId: j['user_id'], topicId: j['topic_id'], subjectId: j['subject_id'],
    scheduledDate: DateTime.parse(j['scheduled_date']), dayNumber: j['day_number'],
    status: j['status'] ?? 'pending', rescheduledTo: j['rescheduled_to'],
    createdAt: DateTime.parse(j['created_at']), updatedAt: DateTime.parse(j['updated_at']),
    topicName: j['topic_name'], subjectName: j['subject_name'],
    parentTopicName: j['parent_topic_name'],
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'user_id': userId, 'topic_id': topicId, 'subject_id': subjectId,
    'scheduled_date': scheduledDate.toIso8601String(), 'day_number': dayNumber,
    'status': status, 'rescheduled_to': rescheduledTo,
    'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String(),
  };

  RevisionScheduleModel copyWith({String? status, String? rescheduledTo,
    String? topicName, String? subjectName, String? parentTopicName}) =>
    RevisionScheduleModel(id: id, userId: userId, topicId: topicId, subjectId: subjectId,
      scheduledDate: scheduledDate, dayNumber: dayNumber, status: status ?? this.status,
      rescheduledTo: rescheduledTo ?? this.rescheduledTo,
      createdAt: createdAt, updatedAt: DateTime.now(),
      topicName: topicName ?? this.topicName,
      subjectName: subjectName ?? this.subjectName,
      parentTopicName: parentTopicName ?? this.parentTopicName);

  /// Subject · Topic or Subject · ParentTopic · Subtopic
  String get hierarchyLabel {
    final sub = subjectName ?? 'Subject';
    final topic = topicName ?? 'Topic';
    final parent = parentTopicName;
    if (parent != null && parent.isNotEmpty) {
      return '$sub · $parent · $topic';
    }
    return '$sub · $topic';
  }
}

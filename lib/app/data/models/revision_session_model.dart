class RevisionSessionModel {
  final String id, userId, topicId;
  final String? scheduleId, recallRating, notes;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;
  final double confidence;
  final DateTime createdAt;

  RevisionSessionModel({
    required this.id, required this.userId, required this.topicId, this.scheduleId,
    required this.startedAt, this.endedAt, this.durationSeconds = 0,
    this.recallRating, this.confidence = 0.0, this.notes, required this.createdAt,
  });

  factory RevisionSessionModel.fromJson(Map<String, dynamic> j) => RevisionSessionModel(
    id: j['id'], userId: j['user_id'], topicId: j['topic_id'],
    scheduleId: j['schedule_id'], startedAt: DateTime.parse(j['started_at']),
    endedAt: j['ended_at'] != null ? DateTime.parse(j['ended_at']) : null,
    durationSeconds: j['duration_seconds'] ?? 0,
    recallRating: j['recall_rating'], confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
    notes: j['notes'], createdAt: DateTime.parse(j['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'user_id': userId, 'topic_id': topicId, 'schedule_id': scheduleId,
    'started_at': startedAt.toIso8601String(), 'ended_at': endedAt?.toIso8601String(),
    'duration_seconds': durationSeconds, 'recall_rating': recallRating,
    'confidence': confidence, 'notes': notes, 'created_at': createdAt.toIso8601String(),
  };

  String get durationFormatted {
    final m = durationSeconds ~/ 60, s = durationSeconds % 60;
    return '${m}m ${s}s';
  }
}

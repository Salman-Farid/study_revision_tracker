class TopicModel {
  final String id, userId, subjectId, name;
  final String? notes, referenceAnswer;
  final DateTime? firstReadDate, lastRevisedAt;
  final bool firstReadCompleted;
  final int totalRevisions;
  final DateTime createdAt, updatedAt;

  TopicModel({
    required this.id, required this.userId, required this.subjectId, required this.name,
    this.notes, this.referenceAnswer, this.firstReadDate,
    this.firstReadCompleted = false,
    this.totalRevisions = 0,
    this.lastRevisedAt, required this.createdAt, required this.updatedAt,
  });

  factory TopicModel.fromJson(Map<String, dynamic> j) => TopicModel(
    id: j['id'], userId: j['user_id'], subjectId: j['subject_id'], name: j['name'],
    notes: j['notes'] as String?, referenceAnswer: j['reference_answer'] as String?,
    firstReadDate: j['first_read_date'] != null ? DateTime.parse(j['first_read_date']) : null,
    firstReadCompleted: j['first_read_completed'] ?? false,
    totalRevisions: j['total_revisions'] ?? 0,
    lastRevisedAt: j['last_revised_at'] != null ? DateTime.parse(j['last_revised_at']) : null,
    createdAt: DateTime.parse(j['created_at']), updatedAt: DateTime.parse(j['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'user_id': userId, 'subject_id': subjectId, 'name': name,
    'notes': notes, 'reference_answer': referenceAnswer,
    'first_read_date': firstReadDate?.toIso8601String(),
    'first_read_completed': firstReadCompleted,
    'total_revisions': totalRevisions, 'last_revised_at': lastRevisedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String(),
  };

  TopicModel copyWith({String? name, String? notes, String? referenceAnswer,
    DateTime? firstReadDate, bool? firstReadCompleted,
    int? totalRevisions, DateTime? lastRevisedAt}) {
    return TopicModel(id: id, userId: userId, subjectId: subjectId,
      name: name ?? this.name, notes: notes ?? this.notes,
      referenceAnswer: referenceAnswer ?? this.referenceAnswer,
      firstReadDate: firstReadDate ?? this.firstReadDate,
      firstReadCompleted: firstReadCompleted ?? this.firstReadCompleted,
      totalRevisions: totalRevisions ?? this.totalRevisions,
      lastRevisedAt: lastRevisedAt ?? this.lastRevisedAt,
      createdAt: createdAt, updatedAt: DateTime.now());
  }

  bool get isCompleted => totalRevisions >= 6;
}

class TopicModel {
  final String id, userId, subjectId, name;
  final String? parentTopicId;
  final String? notes, referenceAnswer;
  final DateTime? firstReadDate, lastRevisedAt;
  final bool firstReadCompleted;
  final int totalRevisions;
  final DateTime createdAt, updatedAt;

  /// Filled by UI/controller when children are known (not always from JSON).
  final int subtopicCount;
  final int subtopicsFullyDone;

  TopicModel({
    required this.id, required this.userId, required this.subjectId, required this.name,
    this.parentTopicId,
    this.notes, this.referenceAnswer, this.firstReadDate,
    this.firstReadCompleted = false,
    this.totalRevisions = 0,
    this.lastRevisedAt, required this.createdAt, required this.updatedAt,
    this.subtopicCount = 0,
    this.subtopicsFullyDone = 0,
  });

  factory TopicModel.fromJson(Map<String, dynamic> j) => TopicModel(
    id: j['id'], userId: j['user_id'], subjectId: j['subject_id'], name: j['name'],
    parentTopicId: j['parent_topic_id'] as String?,
    notes: j['notes'] as String?, referenceAnswer: j['reference_answer'] as String?,
    firstReadDate: j['first_read_date'] != null ? DateTime.parse(j['first_read_date']) : null,
    firstReadCompleted: j['first_read_completed'] ?? false,
    totalRevisions: j['total_revisions'] ?? 0,
    lastRevisedAt: j['last_revised_at'] != null ? DateTime.parse(j['last_revised_at']) : null,
    createdAt: DateTime.parse(j['created_at']), updatedAt: DateTime.parse(j['updated_at']),
    subtopicCount: (j['subtopic_count'] as num?)?.toInt() ?? 0,
    subtopicsFullyDone: (j['subtopics_fully_done'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'user_id': userId, 'subject_id': subjectId, 'name': name,
    'parent_topic_id': parentTopicId,
    'notes': notes, 'reference_answer': referenceAnswer,
    'first_read_date': firstReadDate?.toIso8601String(),
    'first_read_completed': firstReadCompleted,
    'total_revisions': totalRevisions,
    'last_revised_at': lastRevisedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String(),
  };

  TopicModel copyWith({String? name, String? notes, String? referenceAnswer,
    DateTime? firstReadDate, bool? firstReadCompleted,
    int? totalRevisions, DateTime? lastRevisedAt,
    String? parentTopicId, int? subtopicCount, int? subtopicsFullyDone}) {
    return TopicModel(id: id, userId: userId, subjectId: subjectId, name: name ?? this.name,
      parentTopicId: parentTopicId ?? this.parentTopicId,
      notes: notes ?? this.notes, referenceAnswer: referenceAnswer ?? this.referenceAnswer,
      firstReadDate: firstReadDate ?? this.firstReadDate,
      firstReadCompleted: firstReadCompleted ?? this.firstReadCompleted,
      totalRevisions: totalRevisions ?? this.totalRevisions,
      lastRevisedAt: lastRevisedAt ?? this.lastRevisedAt,
      createdAt: createdAt, updatedAt: DateTime.now(),
      subtopicCount: subtopicCount ?? this.subtopicCount,
      subtopicsFullyDone: subtopicsFullyDone ?? this.subtopicsFullyDone);
  }

  bool get isSubtopic => parentTopicId != null;
  bool get hasSubtopics => subtopicCount > 0;

  /// Leaf completion (regular process: first-read + all 6 revisions).
  bool get isCompleted => totalRevisions >= 6;

  /// Subtopic fully done = first-read + all 6 revisions.
  bool get isFullyDone => firstReadCompleted && totalRevisions >= 6;

  /// 0..1 completion for one subtopic (0 before first-read).
  double get subtopicCompletion {
    if (!firstReadCompleted) return 0;
    return totalRevisions.clamp(0, 6) / 6.0;
  }

  /// Parent Done only when every subtopic finished first-read + all revisions.
  bool get parentIsDone => subtopicCount > 0 && subtopicsFullyDone >= subtopicCount;

  /// Average subtopic completion 0..1 for the parent ring (center %).
  double get parentRingProgress {
    if (subtopicCount <= 0) return 0;
    return subtopicsFullyDone / subtopicCount;
  }
}

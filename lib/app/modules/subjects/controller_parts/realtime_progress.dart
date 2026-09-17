part of '../subjects_controller.dart';

/// Realtime stream wiring and per-subject progress computation.
extension SubjectsRealtimeProgress on SubjectsController {
  void _subscribeRealtime() {
    _realtimeSub = _repo.stream.listen((list) {
      subjects.assignAll(list);
      isLoading.value = false;
      _recomputeProgress();
    });
    _topicsSub = _topicRepo.stream.listen((_) => _recomputeProgress());
  }

  /// Computes REAL revision-weighted progress per subject from the DB:
  /// revisionsDone = Σ topic.totalRevisions, revisionsPlanned = 6 × topic count.
  Future<void> _recomputeProgress() async {
    final map = <String, Map<String, int>>{};
    final namesMap = <String, List<String>>{};
    await Future.wait(subjects.map((s) async {
      try {
        final topics = await _topicRepo.getBySubject(s.id)
            .timeout(const Duration(seconds: 5));
        final done = topics.fold<int>(0, (sum, t) => sum + t.totalRevisions.clamp(0, 6));
        map[s.id] = {
          'topics': topics.length,
          'revisionsDone': done,
          'revisionsPlanned': topics.length * 6,
        };
        namesMap[s.id] = topics.map((t) => t.name).toList();
        debugPrint('[Subjects] Progress ${s.name}: ${topics.length} topics, $done revisions done');
      } catch (e) {
        debugPrint('[Subjects] Progress error for ${s.name}: $e');
        map[s.id] = {'topics': s.totalTopics, 'revisionsDone': 0, 'revisionsPlanned': s.totalTopics * 6};
        namesMap[s.id] = [];
      }
    }));
    topicsProgress.assignAll(map);
    topicNames.assignAll(namesMap);
  }

  /// Real completion fraction (0..1) for a subject card's progress bar.
  double progressFor(String subjectId) {
    final p = topicsProgress[subjectId];
    if (p == null || (p['revisionsPlanned'] ?? 0) == 0) return 0;
    return (p['revisionsDone'] ?? 0) / (p['revisionsPlanned'] ?? 1);
  }

  /// Real topic count for a subject card (falls back to the DB column).
  int topicCountFor(SubjectModel subject) =>
      topicsProgress[subject.id]?['topics'] ?? subject.totalTopics;

  /// Topic names for a subject card.
  List<String> topicNamesFor(SubjectModel subject) =>
      topicNames[subject.id] ?? [];
}

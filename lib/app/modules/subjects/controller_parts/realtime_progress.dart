part of '../subjects_controller.dart';

/// Realtime stream wiring and per-subject progress computation.
extension SubjectsRealtimeProgress on SubjectsController {
  void _subscribeRealtime() {
    _realtimeSub = _repo.stream.listen((list) async {
      subjects.assignAll(await _orderSubjects(list));
      isLoading.value = false;
      _recomputeProgress();
    });
    _topicsSub = _topicRepo.stream.listen((_) => _recomputeProgress());
  }

  /// Revision-weighted progress including leaf topics AND subtopics.
  /// Planned units = 6 × (leaf topics + subtopics).
  Future<void> _recomputeProgress() async {
    final map = <String, Map<String, int>>{};
    final namesMap = <String, List<String>>{};
    await Future.wait(subjects.map((s) async {
      try {
        final topics = await _topicRepo.getBySubject(s.id)
            .timeout(const Duration(seconds: 5));
        // Work units: every row that can hold revisions (leaf + subtopic).
        // Parent rows with children are rollups only — not extra planned work.
        final workUnits = topics.where((t) => !t.hasSubtopics).length;
        final done = topics.fold<int>(
            0, (sum, t) => t.hasSubtopics ? sum : sum + t.totalRevisions.clamp(0, 6));
        map[s.id] = {
          'topics': topics.where((t) => t.parentTopicId == null || t.parentTopicId!.isEmpty).length,
          'subtopics': topics.where((t) => t.isSubtopic).length,
          'revisionsDone': done,
          'revisionsPlanned': workUnits * 6,
        };
        namesMap[s.id] = topics
            .where((t) => t.parentTopicId == null || t.parentTopicId!.isEmpty)
            .map((t) => t.name)
            .toList();
        debugPrint('[Subjects] Progress ${s.name}: $workUnits work units, $done done');
      } catch (e) {
        debugPrint('[Subjects] Progress error for ${s.name}: $e');
        map[s.id] = {
          'topics': s.totalTopics,
          'subtopics': 0,
          'revisionsDone': 0,
          'revisionsPlanned': s.totalTopics * 6,
        };
        namesMap[s.id] = [];
      }
    }));
    topicsProgress.assignAll(map);
    topicNames.assignAll(namesMap);
  }

  double progressFor(String subjectId) {
    final p = topicsProgress[subjectId];
    if (p == null || (p['revisionsPlanned'] ?? 0) == 0) return 0;
    return (p['revisionsDone'] ?? 0) / (p['revisionsPlanned'] ?? 1);
  }

  int topicCountFor(SubjectModel subject) =>
      topicsProgress[subject.id]?['topics'] ?? subject.totalTopics;

  List<String> topicNamesFor(SubjectModel subject) =>
      topicNames[subject.id] ?? [];
}

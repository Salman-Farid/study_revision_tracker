part of '../supabase_service.dart';

/// Topics CRUD + revision-progress helpers for [SupabaseService].
extension SupabaseTopicsApi on SupabaseService {
  Future<List<TopicModel>> fetchTopics(String subjectId) async {
    final r = await client.from('topics').select()
        .eq('subject_id', subjectId).order('created_at', ascending: false);
    final all = (r as List).map((j) => TopicModel.fromJson(j)).toList();
    return _decorateParents(all);
  }

  /// Children of a single topic (subtopics).
  Future<List<TopicModel>> fetchSubtopics(String parentTopicId) async {
    final r = await client.from('topics').select()
        .eq('parent_topic_id', parentTopicId)
        .order('created_at', ascending: false);
    return (r as List).map((j) => TopicModel.fromJson(j)).toList();
  }

  /// Attach subtopicCount / subtopicsFullyDone onto parent rows.
  List<TopicModel> _decorateParents(List<TopicModel> all) {
    final childrenOf = <String, List<TopicModel>>{};
    for (final t in all) {
      final p = t.parentTopicId;
      if (p == null || p.isEmpty) continue;
      childrenOf.putIfAbsent(p, () => []).add(t);
    }
    if (childrenOf.isEmpty) return all;
    return all.map((t) {
      if (t.isSubtopic) return t;
      final kids = childrenOf[t.id];
      if (kids == null || kids.isEmpty) return t;
      final done = kids.where((k) => k.isFullyDone).length;
      return t.copyWith(subtopicCount: kids.length, subtopicsFullyDone: done);
    }).toList();
  }

  Future<TopicModel> createTopic({
    required String subjectId,
    required String name,
    String? parentTopicId,
    String? notes,
    String? referenceAnswer,
    DateTime? firstReadDate,
  }) async {
    final data = {
      'id': _uuid.v4(),
      'user_id': userId,
      'subject_id': subjectId,
      if (parentTopicId != null && parentTopicId.isNotEmpty)
        'parent_topic_id': parentTopicId,
      'name': name,
      'notes': notes,
      'reference_answer': referenceAnswer,
      'first_read_date': (firstReadDate ?? DateTime.now()).toIso8601String(),
    };
    final r = await client.from('topics').insert(data).select().single();
    // Only count top-level topics in subjects.total_topics (legacy column).
    if (parentTopicId == null || parentTopicId.isEmpty) {
      unawaited(() async {
        try {
          final sub = await client
              .from('subjects')
              .select('total_topics')
              .eq('id', subjectId)
              .single();
          await client.from('subjects').update({
            'total_topics': ((sub['total_topics'] as int?) ?? 0) + 1,
          }).eq('id', subjectId);
        } catch (_) {}
      }());
    }
    return TopicModel.fromJson(r);
  }

  Future<void> updateTopic(String id, Map<String, dynamic> u) =>
      client.from('topics').update(u).eq('id', id);

  Future<void> markFirstReadCompleted(String topicId) =>
      client.from('topics').update({'first_read_completed': true}).eq('id', topicId);

  Future<Map<String, dynamic>> getTopicFullStatus(String topicId) async {
    final results = await Future.wait([
      client.from('topics').select().eq('id', topicId).single(),
      client.from('revision_schedules').select()
          .eq('topic_id', topicId).order('day_number', ascending: true),
    ]);
    final topicRow = results[0];
    final schedules = results[1];
    final scheduleList = (schedules as List)
        .map((j) => RevisionScheduleModel.fromJson(j))
        .toList();
    final topic = TopicModel.fromJson(topicRow as Map<String, dynamic>);

    final completedSchedules =
        scheduleList.where((s) => s.status == 'completed').toList();
    final pendingSchedules =
        scheduleList.where((s) => s.status == 'pending').toList();
    final completedDays = completedSchedules.map((s) => s.dayNumber).toSet();
    final allDays = AppConstants.revisionDays;

    int nextPendingRevisionIndex = -1;
    for (int i = 0; i < allDays.length; i++) {
      if (!completedDays.contains(allDays[i])) {
        nextPendingRevisionIndex = i;
        break;
      }
    }

    final pendingBeforeNext = <int>[];
    if (nextPendingRevisionIndex > 0) {
      for (int i = 0; i < nextPendingRevisionIndex; i++) {
        if (!completedDays.contains(allDays[i])) {
          pendingBeforeNext.add(allDays[i]);
        }
      }
    }

    return {
      'topic': topic,
      'schedules': scheduleList,
      'totalRevisions': allDays.length,
      'completedRevisionCount': completedSchedules.length,
      'nextPendingRevisionIndex': nextPendingRevisionIndex,
      'nextPendingRevisionDay': nextPendingRevisionIndex >= 0
          ? allDays[nextPendingRevisionIndex]
          : null,
      'pendingBeforeNext': pendingBeforeNext,
      'completedDays': completedDays.toList()..sort(),
      'pendingDays': pendingSchedules.map((s) => s.dayNumber).toList()..sort(),
    };
  }

  Future<void> markNextRevisionCompleted(String topicId) async {
    final status = await getTopicFullStatus(topicId);
    final nextIndex = status['nextPendingRevisionIndex'] as int;
    if (nextIndex < 0) return;

    final allDays = AppConstants.revisionDays;
    final nextDay = allDays[nextIndex];
    final schedules = status['schedules'] as List<RevisionScheduleModel>;
    final nextSchedule = schedules.firstWhere((s) => s.dayNumber == nextDay);

    await updateScheduleStatus(nextSchedule.id, 'completed');
    await updateTopic(topicId, {
      'total_revisions': (status['completedRevisionCount'] as int) + 1,
      'last_revised_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteTopic(String id, {String? subjectId}) async {
    final row = await client.from('topics').select('parent_topic_id')
        .eq('id', id).maybeSingle();
    await client.from('topics').delete().eq('id', id);
    final isSub = row != null &&
        (row['parent_topic_id'] as String?)?.isNotEmpty == true;
    if (subjectId != null && !isSub) {
      try {
        final sub = await client
            .from('subjects')
            .select('total_topics')
            .eq('id', subjectId)
            .single();
        final current = (sub['total_topics'] as int?) ?? 0;
        if (current > 0) {
          await client
              .from('subjects')
              .update({'total_topics': current - 1}).eq('id', subjectId);
        }
      } catch (_) {}
    }
  }
}

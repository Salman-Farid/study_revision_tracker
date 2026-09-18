part of '../supabase_service.dart';

/// Revision schedules for [SupabaseService].
extension SupabaseSchedulesApi on SupabaseService {
  Future<List<RevisionScheduleModel>> fetchSchedules({
    String? topicId,
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var q = client.from('revision_schedules').select().eq('user_id', userId);
    if (topicId != null) q = q.eq('topic_id', topicId);
    if (status != null) q = q.eq('status', status);
    if (fromDate != null) q = q.gte('scheduled_date', fromDate.toIso8601String());
    if (toDate != null) q = q.lte('scheduled_date', toDate.toIso8601String());
    final r = await q.order('scheduled_date', ascending: true);
    final schedules =
        (r as List).map((j) => RevisionScheduleModel.fromJson(j)).toList();
    return _enrichSchedules(schedules);
  }

  Future<List<RevisionScheduleModel>> _enrichSchedules(
    List<RevisionScheduleModel> schedules,
  ) async {
    if (schedules.isEmpty) return schedules;
    final topicIds = schedules.map((s) => s.topicId).toSet();
    final subjectIds = schedules.map((s) => s.subjectId).toSet();

    final topicRows = await client
        .from('topics')
        .select('id, name, parent_topic_id')
        .inFilter('id', topicIds.toList());
    final subjectNames = await _fetchNames('subjects', subjectIds);

    final topicNames = <String, String>{};
    final parentIds = <String>{};
    final topicParent = <String, String?>{};
    for (final r in (topicRows as List)) {
      final id = r['id'] as String;
      topicNames[id] = r['name'] as String? ?? '';
      final pid = r['parent_topic_id'] as String?;
      topicParent[id] = pid;
      if (pid != null && pid.isNotEmpty) parentIds.add(pid);
    }
    final parentNames = <String, String>{};
    if (parentIds.isNotEmpty) {
      parentNames.addAll(await _fetchNames('topics', parentIds));
    }

    return schedules.map((s) {
      final pid = topicParent[s.topicId];
      return s.copyWith(
        topicName: topicNames[s.topicId],
        subjectName: subjectNames[s.subjectId],
        parentTopicName: pid == null ? null : parentNames[pid],
      );
    }).toList();
  }

  Future<Map<String, String>> _fetchNames(String table, Set<String> ids) async {
    if (ids.isEmpty) return {};
    final rows =
        await client.from(table).select('id, name').inFilter('id', ids.toList());
    return {for (final r in rows as List) r['id'] as String: r['name'] as String};
  }

  Future<List<RevisionScheduleModel>> createRevisionSchedules({
    required String topicId,
    required String subjectId,
    required DateTime firstReadDate,
  }) async {
    final rows = <Map<String, dynamic>>[];
    for (final d in AppConstants.revisionDays) {
      rows.add({
        'id': _uuid.v4(),
        'user_id': userId,
        'topic_id': topicId,
        'subject_id': subjectId,
        'scheduled_date':
            firstReadDate.add(Duration(days: d)).toIso8601String(),
        'day_number': d,
        'status': 'pending',
      });
    }
    final r = await client.from('revision_schedules').insert(rows).select();
    _debouncedNotificationUpdate(force: true);
    return (r as List).map((j) => RevisionScheduleModel.fromJson(j)).toList();
  }

  Future<void> updateScheduleStatus(String id, String st) =>
      client.from('revision_schedules').update({'status': st}).eq('id', id);

  /// Single source of truth: complete one revision day for a topic.
  Future<void> completeRevision({
    required String scheduleId,
    required String topicId,
  }) async {
    await client
        .from('revision_schedules')
        .update({'status': 'completed'}).eq('id', scheduleId);
    try {
      final topic = await client
          .from('topics')
          .select('total_revisions')
          .eq('id', topicId)
          .single();
      final next = ((topic['total_revisions'] as num?) ?? 0) + 1;
      await client.from('topics').update({
        'total_revisions': next,
        'last_revised_at': DateTime.now().toIso8601String(),
      }).eq('id', topicId);
    } catch (_) {}
    unawaited(_refreshSchedules());
    unawaited(_refreshTopics());
    _debouncedNotificationUpdate(force: true);
  }
}

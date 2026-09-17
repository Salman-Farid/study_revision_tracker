part of '../subject_detail_controller.dart';

/// Topic CRUD, first-read completion, and drag-reorder.
extension SubjectDetailActions on SubjectDetailController {
  Future<void> markRevisionComplete(String topicId, int dayNumber) async {
    try {
      final schedules = getSchedules(topicId);
      final schedule = schedules.firstWhereOrNull((s) => s.dayNumber == dayNumber);
      if (schedule == null) return;

      // Same path as Today tab — one source of truth.
      await _revRepo.completeRevision(
        scheduleId: schedule.id,
        topicId: topicId,
      );

      final updatedSchedules = await _revRepo.getSchedules(topicId: topicId);
      schedulesByTopic[topicId] = updatedSchedules;
      topics.assignAll(await _topicRepo.getBySubject(subject.id));

      Get.snackbar('Done', 'Revision marked as completed',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success.withValues(alpha: 0.1));
    } catch (e, st) {
      debugPrint('[SubjectDetail] markRevisionComplete FAILED: $e');
      debugPrint('[SubjectDetail] Stacktrace: $st');
      Get.snackbar('Error', 'Failed to mark revision');
    }
  }

  Future<void> createTopic({required String name, String? notes, String? refAnswer, DateTime? firstRead}) async {
    try {
      if (topics.any((t) => t.name.toLowerCase() == name.toLowerCase())) {
        Get.snackbar('Duplicate', '"$name" exists', snackPosition: SnackPosition.BOTTOM); return;
      }
      final rd = firstRead ?? DateTime.now();
      final t = await _topicRepo.create(subjectId: subject.id, name: name,
        notes: notes, referenceAnswer: refAnswer, firstReadDate: rd);
      // Revision schedules are created only after first-read is marked complete.
      topics.insert(0, t);
      _subjectRepo.refresh();
      Get.snackbar('Created', '"$name" added to first read', snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success.withOpacity(0.1));
    } catch (e) { Get.snackbar('error'.tr, e.toString()); }
  }

  Future<void> deleteTopic(String id) async {
    try {
      await _topicRepo.delete(id, subjectId: subject.id);
      topics.removeWhere((t) => t.id == id);
      _subjectRepo.refresh();
    } catch (e) { Get.snackbar('error'.tr, 'error'.tr); }
  }

  Future<void> markFirstRead(String topicId) async {
    try {
      await _topicRepo.markFirstReadCompleted(topicId);

      // Create revision schedules NOW that first read is complete.
      final topic = topics.firstWhereOrNull((t) => t.id == topicId);
      final subjectId = topic?.subjectId ?? subject.id;
      final existing = await _revRepo.getSchedules(topicId: topicId);
      if (existing.isEmpty) {
        final created = await _revRepo.createSchedules(
          topicId: topicId,
          subjectId: subjectId,
          firstReadDate: DateTime.now(),
        );
        // Schedule local notifications for each new revision.
        try {
          final notifications = Get.find<NotificationService>();
          for (final schedule in created) {
            await notifications.scheduleRevision(
              schedule: schedule,
              topicName: topic?.name ?? 'Topic',
              subjectName: subject.name,
            );
          }
        } catch (_) {}
      }

      _topicRepo.refresh();
      // Refresh topics
      topics.assignAll(await _topicRepo.getBySubject(subject.id));
      // Reload schedules for this topic
      final updatedSchedules = await _revRepo.getSchedules(topicId: topicId);
      schedulesByTopic[topicId] = updatedSchedules;

      Get.snackbar('save'.tr, 'firstReadDone'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success.withOpacity(0.1));
    } catch (e, st) {
      debugPrint('[SubjectDetail] markFirstRead FAILED: $e');
      debugPrint('[SubjectDetail] Stacktrace: $st');
      Get.snackbar('error'.tr, e.toString());
    }
  }

  /// Reorder the currently visible (filtered) list and persist the full order.
  void reorderTopics(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final visible = filteredTopics;
    if (oldIndex < 0 ||
        oldIndex >= visible.length ||
        newIndex < 0 ||
        newIndex >= visible.length) {
      return;
    }
    final moved = visible[oldIndex];
    // Rebuild the full topics list: remove moved id, insert at the
    // position of the neighbor it was dropped next to.
    final full = topics.toList()..removeWhere((t) => t.id == moved.id);
    final anchorId = newIndex < visible.length
        ? visible[newIndex].id
        : (visible.isNotEmpty ? visible.last.id : null);
    var insertAt = full.length;
    if (anchorId != null) {
      insertAt = full.indexWhere((t) => t.id == anchorId);
      if (insertAt < 0) insertAt = full.length;
    }
    full.insert(insertAt, moved);
    topics.assignAll(full);
    _lastReorderAt = DateTime.now();
    _ignoreNextRealtime = true;
    _persistOrder();
  }
}

part of '../subject_detail_controller.dart';

/// Realtime stream wiring for topics and revision schedules.
extension SubjectDetailRealtime on SubjectDetailController {
  void _subscribeRealtime() {
    _realtimeSub = _topicRepo.stream.listen((allTopics) async {
      // Don't clobber a drag-reorder the user just made.
      if (_ignoreNextRealtime ||
          (_lastReorderAt != null &&
              DateTime.now().difference(_lastReorderAt!) <
                  const Duration(seconds: 3))) {
        _ignoreNextRealtime = false;
        return;
      }
      final mine =
          allTopics.where((t) => t.subjectId == subject.id).toList();
      topics.assignAll(await _applySavedOrder(mine));
    });
    // Keep revision cards in sync when Today/Calendar mark a schedule done.
    _schedulesStreamSub = Get.find<SupabaseService>().schedulesStream.listen((_) {
      unawaited(_reloadSchedulesQuiet());
    });
  }

  Future<void> _reloadSchedulesQuiet() async {
    try {
      final ids = topics.map((t) => t.id).toList();
      if (ids.isEmpty) return;
      final results = await Future.wait(
        ids.map((id) async {
          try {
            return MapEntry(id, await _revRepo.getSchedules(topicId: id));
          } catch (_) {
            return MapEntry(id, <RevisionScheduleModel>[]);
          }
        }),
      );
      schedulesByTopic.addEntries(results);
    } catch (_) {}
  }
}

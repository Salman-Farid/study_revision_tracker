part of '../subject_detail_controller.dart';

/// Topic list loading, saved-order persistence, and schedule queries.
extension SubjectDetailLoading on SubjectDetailController {
  Future<void> load() async {
    try {
      isLoading.value = true;
      final raw = await _topicRepo.getBySubject(subject.id);
      topics.assignAll(await _applySavedOrder(raw));
      await _loadSchedules();
    } catch (e) {
      Get.snackbar('error'.tr, 'error'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<TopicModel>> _applySavedOrder(List<TopicModel> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final order = prefs.getStringList(_orderKey);
      if (order == null || order.isEmpty) return list;
      final index = {for (var i = 0; i < order.length; i++) order[i]: i};
      final sorted = list.toList()
        ..sort((a, b) {
          final ia = index[a.id] ?? 1 << 20;
          final ib = index[b.id] ?? 1 << 20;
          return ia.compareTo(ib);
        });
      return sorted;
    } catch (_) {
      return list;
    }
  }

  Future<void> _persistOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _orderKey, topics.map((t) => t.id).toList());
    } catch (_) {}
  }

  Future<void> _loadSchedules() async {
    if (topics.isEmpty) return;
    // Parallel fetch instead of sequential per-topic queries.
    final results = await Future.wait(
      topics.map((topic) async {
        try {
          final schedules = await _revRepo.getSchedules(topicId: topic.id);
          return MapEntry(topic.id, schedules);
        } catch (_) {
          return MapEntry(topic.id, <RevisionScheduleModel>[]);
        }
      }),
    );
    schedulesByTopic.addEntries(results);
  }

  List<RevisionScheduleModel> getSchedules(String topicId) {
    return schedulesByTopic[topicId] ?? [];
  }

  Set<int> getCompletedDays(String topicId) {
    final schedules = getSchedules(topicId);
    return schedules
        .where((s) => s.status == 'completed')
        .map((s) => s.dayNumber)
        .toSet();
  }
}

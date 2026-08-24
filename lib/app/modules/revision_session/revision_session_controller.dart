import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/topic_model.dart';
import '../../data/models/subject_model.dart';
import '../../data/models/revision_schedule_model.dart';
import '../../data/repositories/revision_repository.dart';
import '../../data/repositories/topic_repository.dart';

class RevisionSessionController extends GetxController {
  final _repo = Get.find<RevisionRepository>();
  late TopicModel topic;
  late SubjectModel subject;
  List<RevisionScheduleModel> schedules = [];
  final isRunning = false.obs, isPaused = false.obs, elapsedSeconds = 0.obs;
  final selectedRating = RxnString(), confidence = 0.5.obs;
  final notesCtrl = TextEditingController(), isSaving = false.obs;
  Timer? _timer; String? _sessionId;

  @override void onInit() {
    super.onInit();
    final a = Get.arguments as Map;
    topic = a['topic']; subject = a['subject'];
    schedules = a['schedules'] as List<RevisionScheduleModel>? ?? [];
  }

  void start() {
    if (isRunning.value) return;
    isRunning.value = true; isPaused.value = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => elapsedSeconds.value++);
    _startSession();
  }

  void pause() { isPaused.value = true; _timer?.cancel(); }
  void resume() { isPaused.value = false; _timer = Timer.periodic(const Duration(seconds: 1), (_) => elapsedSeconds.value++); }
  void stop() { _timer?.cancel(); isRunning.value = false; }

  Future<void> _startSession() async {
    try {
      final ps = schedules.where((s) => s.status == 'pending').firstOrNull;
      final sess = await _repo.startSession(topicId: topic.id, scheduleId: ps?.id);
      _sessionId = sess.id;
    } catch (_) {}
  }

  Future<void> complete() async {
    if (selectedRating.value == null) { Get.snackbar('Required', 'Select recall rating', snackPosition: SnackPosition.BOTTOM); return; }
    if (_sessionId == null) { Get.snackbar('Error', 'Session not started'); return; }
    try {
      isSaving.value = true; stop();
      await _repo.completeSession(_sessionId!, recallRating: selectedRating.value!,
        confidence: confidence.value, durationSeconds: elapsedSeconds.value,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim());
      final ps = schedules.where((s) => s.status == 'pending').firstOrNull;
      if (ps != null) await _repo.updateScheduleStatus(ps.id, 'completed');
      await _updateTopicStats();
      Get.back(result: true);
      Get.snackbar('Completed', 'Session saved', snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.1));
    } catch (e) { Get.snackbar('Error', 'Failed to save'); }
    finally { isSaving.value = false; }
  }

  Future<void> _updateTopicStats() async {
    try {
      final allSessions = await _repo.getSessions(topicId: topic.id);
      final completed = allSessions.where((s) => s.endedAt != null).toList();
      final count = completed.length;
      if (count == 0) return;

      double totalMastery = 0;
      double totalConfidence = 0;
      for (final s in completed) {
        totalConfidence += s.confidence;
        switch (s.recallRating) {
          case 'perfect': totalMastery += 1.0; break;
          case 'good': totalMastery += 0.75; break;
          case 'partial': totalMastery += 0.5; break;
          case 'forgot': totalMastery += 0.1; break;
          default: totalMastery += 0.5;
        }
      }

      final topicRepo = Get.find<TopicRepository>();
      await topicRepo.update(topic.id, {
        'mastery_level': totalMastery / count,
        'total_revisions': count,
        'confidence': totalConfidence / count,
        'last_revised_at': DateTime.now().toIso8601String(),
      });
      topicRepo.refresh();
    } catch (e) {
      debugPrint('Failed to update topic stats: $e');
    }
  }

  String get formattedTime {
    final h = elapsedSeconds.value ~/ 3600, m = (elapsedSeconds.value % 3600) ~/ 60, s = elapsedSeconds.value % 60;
    return h > 0 ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
      : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override void onClose() { _timer?.cancel(); notesCtrl.dispose(); super.onClose(); }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/subject_model.dart';
import '../../data/models/topic_model.dart';
import '../../data/models/revision_schedule_model.dart';
import '../../data/repositories/subject_repository.dart';
import '../../data/repositories/topic_repository.dart';
import '../../data/repositories/revision_repository.dart';
import '../../theme/app_theme.dart';
import '../../core/constants/size_constants.dart';
import '../../../gemini_3_flash_live_voice_chatbot/gemini_chatbot.dart';

class SubjectDetailController extends GetxController {
  final _subjectRepo = Get.find<SubjectRepository>();
  final _topicRepo = Get.find<TopicRepository>();
  final _revRepo = Get.find<RevisionRepository>();
  late SubjectModel subject;
  final topics = <TopicModel>[].obs;
  final schedulesByTopic = <String, List<RevisionScheduleModel>>{}.obs;
  final isLoading = true.obs;
  final selectedFilter = 'firstRead'.obs;
  StreamSubscription<List<TopicModel>>? _realtimeSub;

  List<TopicModel> get filteredTopics {
    switch (selectedFilter.value) {
      case 'firstRead':
        return topics.where((t) => !t.firstReadCompleted).toList();
      case 'inRevision':
        return topics.where((t) => t.firstReadCompleted && t.totalRevisions < 6).toList();
      case 'completed':
        return topics.where((t) => t.totalRevisions >= 6).toList();
      default:
        return topics;
    }
  }

  int get firstReadCount => topics.where((t) => !t.firstReadCompleted).length;
  int get inRevisionCount => topics.where((t) => t.firstReadCompleted && t.totalRevisions < 6).length;
  int get completedCount => topics.where((t) => t.totalRevisions >= 6).length;

  @override void onInit() {
    super.onInit();
    subject = Get.arguments as SubjectModel;
    load();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _realtimeSub = _topicRepo.stream.listen((allTopics) {
      // Filter topics belonging to this subject
      topics.assignAll(allTopics.where((t) => t.subjectId == subject.id));
    });
  }

  @override
  void onClose() {
    _realtimeSub?.cancel();
    super.onClose();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      topics.assignAll(await _topicRepo.getBySubject(subject.id));
      await _loadSchedules();
    } catch (e) {
      Get.snackbar('Error', 'Failed');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadSchedules() async {
    for (final topic in topics) {
      try {
        final schedules = await _revRepo.getSchedules(topicId: topic.id);
        schedulesByTopic[topic.id] = schedules;
      } catch (_) {}
    }
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

  Future<void> markRevisionComplete(String topicId, int dayNumber) async {
    try {
      final schedules = getSchedules(topicId);
      final schedule = schedules.firstWhereOrNull((s) => s.dayNumber == dayNumber);
      if (schedule == null) return;

      // Mark ONLY this specific day's schedule as completed
      await _revRepo.updateScheduleStatus(schedule.id, 'completed');

      // Increment total_revisions by 1 directly (don't use markNextRevisionCompleted — it marks the NEXT pending one too)
      final topic = topics.firstWhereOrNull((t) => t.id == topicId);
      if (topic != null) {
        await _topicRepo.update(topicId, {
          'total_revisions': topic.totalRevisions + 1,
          'last_revised_at': DateTime.now().toIso8601String(),
        });
      }
      _topicRepo.refresh();

      // Reload schedules for this topic
      final updatedSchedules = await _revRepo.getSchedules(topicId: topicId);
      schedulesByTopic[topicId] = updatedSchedules;

      // Refresh topics to get updated totalRevisions
      topics.assignAll(await _topicRepo.getBySubject(subject.id));

      Get.snackbar('Done', 'Revision marked as completed',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success.withValues(alpha: 0.1));
    } catch (e, st) {
      print('[SubjectDetail] markRevisionComplete FAILED: $e');
      print('[SubjectDetail] Stacktrace: $st');
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
      await _revRepo.createSchedules(topicId: t.id, subjectId: subject.id, firstReadDate: rd);
      topics.insert(0, t);
      _subjectRepo.refresh();
      Get.snackbar('Created', '"$name" with schedule', snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success.withOpacity(0.1));
    } catch (e) { Get.snackbar('Error', 'Failed: $e'); }
  }

  void showAddSheet() {
    final nc = TextEditingController(), nsc = TextEditingController(), rfc = TextEditingController();
    final sd = DateTime.now().obs, st = TimeOfDay.now().obs;
    Get.bottomSheet(Container(padding: EdgeInsets.all(S.xl),
      decoration: BoxDecoration(color: AppColors.surface(Get.isDarkMode),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(
            color: AppColors.textMuted(Get.isDarkMode), borderRadius: BorderRadius.circular(2)))),
          SizedBox(height: S.xl), Text('Add Topic', style: AppTextStyles.headlineSmall),
          SizedBox(height: S.sm), Text('Subject: ${subject.name}',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary)),
          SizedBox(height: S.xl),
          TextField(controller: nc, decoration: const InputDecoration(labelText: 'Topic Name *', prefixIcon: Icon(Icons.topic_rounded)), autofocus: true),
          SizedBox(height: S.base),
          Row(children: [
            Expanded(child: Obx(() => OutlinedButton.icon(onPressed: () async {
              final d = await showDatePicker(context: Get.context!, initialDate: sd.value,
                firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (d != null) sd.value = d;
            }, icon: const Icon(Icons.calendar_today_rounded, size: 16),
              label: Text('${sd.value.day}/${sd.value.month}/${sd.value.year}', style: AppTextStyles.labelMedium)))),
            SizedBox(width: S.sm),
            Expanded(child: Obx(() => OutlinedButton.icon(onPressed: () async {
              final t = await showTimePicker(context: Get.context!, initialTime: st.value);
              if (t != null) st.value = t;
            }, icon: const Icon(Icons.access_time_rounded, size: 16),
              label: Text(st.value.format(Get.context!), style: AppTextStyles.labelMedium)))),
          ]),
          SizedBox(height: S.base),
          TextField(controller: nsc, decoration: const InputDecoration(labelText: 'Notes (optional)', prefixIcon: Icon(Icons.note_rounded)), maxLines: 2),
          SizedBox(height: S.base),
          TextField(controller: rfc, decoration: const InputDecoration(labelText: 'Reference Answer (optional)', prefixIcon: Icon(Icons.article_rounded)), maxLines: 3),
          SizedBox(height: S.xl),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
            final n = nc.text.trim();
            if (n.isEmpty) { Get.snackbar('Required', 'Topic name needed'); return; }
            final dt = DateTime(sd.value.year, sd.value.month, sd.value.day, st.value.hour, st.value.minute);
            createTopic(name: n, notes: nsc.text.trim().isEmpty ? null : nsc.text.trim(),
              refAnswer: rfc.text.trim().isEmpty ? null : rfc.text.trim(), firstRead: dt);
            Get.back();
          }, child: const Text('Create Topic with Schedule'))),
          SizedBox(height: S.base),
        ]))), isScrollControlled: true);
  }

  Future<void> deleteTopic(String id) async {
    try {
      await _topicRepo.delete(id, subjectId: subject.id);
      topics.removeWhere((t) => t.id == id);
      _subjectRepo.refresh();
    } catch (e) { Get.snackbar('Error', 'Failed'); }
  }

  Future<void> markFirstRead(String topicId) async {
    try {
      await _topicRepo.markFirstReadCompleted(topicId);
      _topicRepo.refresh();
      // Refresh topics
      topics.assignAll(await _topicRepo.getBySubject(subject.id));
      // Reload schedules for this topic
      final updatedSchedules = await _revRepo.getSchedules(topicId: topicId);
      schedulesByTopic[topicId] = updatedSchedules;

      Get.snackbar('Done', 'First read marked as completed',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success.withOpacity(0.1));
    } catch (e, st) {
      print('[SubjectDetail] markFirstRead FAILED: $e');
      print('[SubjectDetail] Stacktrace: $st');
      Get.snackbar('Error', 'Failed: $e');
    }
  }

  void reorderTopics(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = topics.removeAt(oldIndex);
    topics.insert(newIndex, item);
  }

  /// Navigate to Gemini Live voice assistant with subject context
  void openVoiceAssistant() {
    final vc = Get.find<VoiceAssistantController>();
    vc.currentSubjectName = subject.name;
    Get.bottomSheet(
      const VoiceAssistantSheet(),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Get.theme.scaffoldBackgroundColor,
    );
  }
}

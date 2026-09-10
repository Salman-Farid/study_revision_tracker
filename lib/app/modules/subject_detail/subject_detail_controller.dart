import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/subject_model.dart';
import '../../data/models/topic_model.dart';
import '../../data/models/revision_schedule_model.dart';
import '../../data/repositories/subject_repository.dart';
import '../../data/repositories/topic_repository.dart';
import '../../data/repositories/revision_repository.dart';
import '../../data/services/supabase_service.dart';
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
  StreamSubscription? _schedulesStreamSub;

  /// Ignore one realtime overwrite right after a user drag-reorder.
  bool _ignoreNextRealtime = false;
  DateTime? _lastReorderAt;

  String get _orderKey => 'topic_order_${subject.id}';

  List<TopicModel> get filteredTopics {
    final list = switch (selectedFilter.value) {
      'firstRead' => topics.where((t) => !t.firstReadCompleted).toList(),
      'inRevision' =>
        topics.where((t) => t.firstReadCompleted && t.totalRevisions < 6).toList(),
      'completed' => topics.where((t) => t.totalRevisions >= 6).toList(),
      _ => topics.toList(),
    };
    return list;
  }

  int get firstReadCount => topics.where((t) => !t.firstReadCompleted).length;
  int get inRevisionCount =>
      topics.where((t) => t.firstReadCompleted && t.totalRevisions < 6).length;
  int get completedCount => topics.where((t) => t.totalRevisions >= 6).length;

  @override
  void onInit() {
    super.onInit();
    subject = Get.arguments as SubjectModel;
    load();
    _subscribeRealtime();
  }

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

  @override
  void onClose() {
    _realtimeSub?.cancel();
    _schedulesStreamSub?.cancel();
    super.onClose();
  }

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
      // Revision schedules are created only after first-read is marked complete.
      topics.insert(0, t);
      _subjectRepo.refresh();
      Get.snackbar('Created', '"$name" added to first read', snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success.withOpacity(0.1));
    } catch (e) { Get.snackbar('error'.tr, e.toString()); }
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
            if (n.isEmpty) { Get.snackbar('required'.tr, 'required'.tr); return; }
            final dt = DateTime(sd.value.year, sd.value.month, sd.value.day, st.value.hour, st.value.minute);
            createTopic(name: n, notes: nsc.text.trim().isEmpty ? null : nsc.text.trim(),
              refAnswer: rfc.text.trim().isEmpty ? null : rfc.text.trim(), firstRead: dt);
            Get.back();
          }, child: Text('createSubject'.tr))),
          SizedBox(height: S.base),
        ]))), isScrollControlled: true);
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
      print('[SubjectDetail] markFirstRead FAILED: $e');
      print('[SubjectDetail] Stacktrace: $st');
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

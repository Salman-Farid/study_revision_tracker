import 'dart:async';

import 'package:get/get.dart';
import '../../data/models/revision_schedule_model.dart';
import '../../data/repositories/revision_repository.dart';
import '../../data/services/supabase_service.dart';

class TodayController extends GetxController {
  final _repo = Get.find<RevisionRepository>();

  /// 0 = Ongoing Today, 1 = Missed, 2 = Upcoming
  final selectedTab = 0.obs;

  final overdue = <RevisionScheduleModel>[].obs;
  final today = <RevisionScheduleModel>[].obs;
  final upcoming = <RevisionScheduleModel>[].obs;
  final isLoading = true.obs;

  StreamSubscription? _schedulesSub;

  @override
  void onInit() {
    super.onInit();
    load();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _schedulesSub?.cancel();
    _schedulesSub = Get.find<SupabaseService>().schedulesStream.listen((_) => load());
  }

  @override
  void onClose() {
    _schedulesSub?.cancel();
    super.onClose();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      final now = DateTime.now();
      final ts = DateTime(now.year, now.month, now.day);
      final te = ts.add(const Duration(days: 1));
      overdue.assignAll(await _repo.getSchedules(status: 'pending', toDate: ts));
      today.assignAll(
          await _repo.getSchedules(status: 'pending', fromDate: ts, toDate: te));
      upcoming.assignAll(await _repo.getSchedules(
          status: 'pending', fromDate: te));
    } catch (e) {
      Get.snackbar('Error', "Failed to load today's revisions: $e",
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markDone(String id) async {
    await _repo.updateScheduleStatus(id, 'completed');
    overdue.removeWhere((s) => s.id == id);
    today.removeWhere((s) => s.id == id);
    upcoming.removeWhere((s) => s.id == id);
  }

  Future<void> markMissed(String id) async {
    await _repo.updateScheduleStatus(id, 'missed');
    overdue.removeWhere((s) => s.id == id);
    today.removeWhere((s) => s.id == id);
    upcoming.removeWhere((s) => s.id == id);
  }
}

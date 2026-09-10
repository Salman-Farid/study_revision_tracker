import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../data/models/revision_schedule_model.dart';
import '../../data/repositories/revision_repository.dart';
import '../../data/services/supabase_service.dart';
import '../../modules/navigation/navigation_controller.dart';
import '../../widgets/widget_promo_dialog.dart';

class DashboardController extends GetxController {
  final _repo = Get.find<RevisionRepository>();
  final stats = <String, dynamic>{}.obs;
  final isLoading = true.obs;
  final pendingSchedules = <RevisionScheduleModel>[].obs;

  StreamSubscription? _schedulesSub;
  StreamSubscription? _subjectsSub;

  @override void onInit() {
    super.onInit();
    load();
    _subscribeRealtime();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Get.context != null) {
        WidgetPromoDialog.showIfNeeded(Get.context!);
      }
    });
  }

  void _subscribeRealtime() {
    _schedulesSub?.cancel();
    _subjectsSub?.cancel();
    _schedulesSub = Get.find<SupabaseService>().schedulesStream.listen((_) => load());
    _subjectsSub = Get.find<SupabaseService>().subjectsStream.listen((_) => load());
  }

  @override
  void onClose() {
    _schedulesSub?.cancel();
    _subjectsSub?.cancel();
    super.onClose();
  }

  Future<void> load() async {
    try {
      if (Get.find<SupabaseService>().currentUser == null) return;
      isLoading.value = true;
      stats.assignAll(await _repo.getDashboardStats());
      final now = DateTime.now();
      final ts = DateTime(now.year, now.month, now.day);
      final te = ts.add(const Duration(days: 1));
      final overdue = await _repo.getSchedules(status: 'pending', toDate: ts);
      final today = await _repo.getSchedules(status: 'pending', fromDate: ts, toDate: te);
      pendingSchedules.assignAll([...overdue, ...today]);
    } catch (e) { Get.snackbar('Error', 'Failed to load dashboard: $e', snackPosition: SnackPosition.BOTTOM); }
    finally { isLoading.value = false; }
  }

  Future<void> startRevising() async {
    // Open the Subjects tab — pick a subject, then revise from there.
    try {
      NavigationController.to.goToSubjects();
    } catch (_) {
      // Controller may not exist yet if home just opened.
      Get.put(NavigationController(), permanent: true).goToSubjects();
    }
  }
}

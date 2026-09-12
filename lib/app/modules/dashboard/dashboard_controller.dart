import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../core/constants/responsive.dart';
import '../../data/models/revision_schedule_model.dart';
import '../../data/repositories/revision_repository.dart';
import '../../data/services/supabase_service.dart';
import '../../modules/navigation/navigation_controller.dart';
import '../../widgets/widget_promo_dialog.dart';

class DashboardController extends GetxController {
  final _repo = Get.find<RevisionRepository>();
  final _s = Get.find<SupabaseService>();

  final stats = <String, dynamic>{}.obs;
  final isLoading = true.obs;
  final pendingSchedules = <RevisionScheduleModel>[].obs;

  StreamSubscription? _schedulesSub;
  StreamSubscription? _subjectsSub;
  StreamSubscription? _topicsSub;
  Timer? _debounce;
  bool _loading = false;

  @override
  void onInit() {
    super.onInit();
    _ensureRealtime();
    _subscribeRealtime();
    // First paint first — then load stats.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(load());
      // Home-widget promo is phone-only (no home-screen widgets on web/desktop).
      if (Get.context != null && Responsive.useBottomNav) {
        WidgetPromoDialog.showIfNeeded(Get.context!);
      }
    });
  }

  void _ensureRealtime() {
    try {
      _s.initRealtime();
    } catch (_) {}
  }

  void _subscribeRealtime() {
    _schedulesSub?.cancel();
    _subjectsSub?.cancel();
    _topicsSub?.cancel();
    // Any schedule / subject / topic change → silent refresh.
    _schedulesSub = _s.schedulesStream.listen((_) => _scheduleSilentRefresh());
    _subjectsSub = _s.subjectsStream.listen((_) => _scheduleSilentRefresh());
    _topicsSub = _s.topicsStream.listen((_) => _scheduleSilentRefresh());
  }

  void _scheduleSilentRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(load(showLoading: false));
    });
  }

  @override
  void onClose() {
    _debounce?.cancel();
    _schedulesSub?.cancel();
    _subjectsSub?.cancel();
    _topicsSub?.cancel();
    super.onClose();
  }

  Future<void> load({bool showLoading = true}) async {
    if (_loading) return;
    _loading = true;
    try {
      if (_s.currentUser == null) return;
      if (showLoading) isLoading.value = true;

      final data = await _repo.getDashboardStats();
      stats.assignAll(data);

      final now = DateTime.now();
      final ts = DateTime(now.year, now.month, now.day);
      final te = ts.add(const Duration(days: 1));
      final overdue =
          await _repo.getSchedules(status: 'pending', toDate: ts);
      final today =
          await _repo.getSchedules(status: 'pending', fromDate: ts, toDate: te);
      pendingSchedules.assignAll([...overdue, ...today]);
    } catch (e) {
      if (showLoading) {
        Get.snackbar('Error', 'Failed to load dashboard: $e',
            snackPosition: SnackPosition.BOTTOM);
      }
    } finally {
      isLoading.value = false;
      _loading = false;
    }
  }

  Future<void> startRevising() async {
    try {
      NavigationController.to.goToSubjects();
    } catch (_) {
      Get.put(NavigationController(), permanent: true).goToSubjects();
    }
  }
}

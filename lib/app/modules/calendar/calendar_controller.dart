import 'dart:async';

import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../data/models/revision_schedule_model.dart';
import '../../data/repositories/revision_repository.dart';
import '../../data/services/supabase_service.dart';

class CalendarController extends GetxController {
  final _repo = Get.find<RevisionRepository>();

  final calendarFormat = CalendarFormat.month.obs;
  final focusedDay = DateTime.now().obs;
  final selectedDay = DateTime.now().obs;
  final events = <DateTime, List<RevisionScheduleModel>>{}.obs;
  final isLoading = true.obs;

  StreamSubscription? _schedulesSub;

  @override
  void onInit() {
    super.onInit();
    load();
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
      final ss = await _repo.getSchedules(
        fromDate: DateTime(now.year, now.month - 2, 1),
        toDate: DateTime(now.year, now.month + 3, 0));
      events.clear();
      for (final s in ss) {
        final k = DateTime(s.scheduledDate.year, s.scheduledDate.month, s.scheduledDate.day);
        events.putIfAbsent(k, () => []).add(s);
      }
    } catch (e) { Get.snackbar('Error', 'Failed to load calendar: $e', snackPosition: SnackPosition.BOTTOM); } finally {
      isLoading.value = false;
    }
  }

  List<RevisionScheduleModel> getEventsForDay(DateTime d) =>
      events[DateTime(d.year, d.month, d.day)] ?? [];

  void onDaySelected(DateTime selected, DateTime focused) {
    selectedDay.value = selected;
    focusedDay.value = focused;
  }

  void onFormatChanged(CalendarFormat format) {
    calendarFormat.value = format;
  }
}

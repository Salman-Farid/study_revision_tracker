import 'package:get/get.dart';
import '../../data/repositories/revision_repository.dart';

class StatisticsController extends GetxController {
  final _repo = Get.find<RevisionRepository>();
  final stats = <String, dynamic>{}.obs;
  final isLoading = true.obs;
  @override void onInit() { super.onInit(); load(); }
  Future<void> load() async {
    try { isLoading.value = true; stats.assignAll(await _repo.getDashboardStats()); }
    catch (_) {} finally { isLoading.value = false; }
  }
}

import 'package:get/get.dart';
import '../../data/repositories/revision_repository.dart';
import '../../data/services/supabase_service.dart';

class DashboardController extends GetxController {
  final _repo = Get.find<RevisionRepository>();
  final stats = <String, dynamic>{}.obs;
  final isLoading = true.obs;

  @override void onInit() { super.onInit(); load(); }

  Future<void> load() async {
    try {
      if (Get.find<SupabaseService>().currentUser == null) return;
      isLoading.value = true;
      stats.assignAll(await _repo.getDashboardStats());
    } catch (e) { /* silent - no user yet */ }
    finally { isLoading.value = false; }
  }
}

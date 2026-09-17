part of '../subjects_controller.dart';

/// Subject CRUD, load, and reorder.
extension SubjectsActions on SubjectsController {
  Future<void> load() async {
    try {
      if (Get.find<SupabaseService>().currentUser == null) return;
      isLoading.value = true;
      subjects.assignAll(await _repo.getAll());
      await _recomputeProgress();
    } catch (e) { Get.snackbar('Error', 'Failed to load subjects: $e', snackPosition: SnackPosition.BOTTOM); }
    finally { isLoading.value = false; }
  }

  Future<void> createSubject({required String name, String? imageUrl, String? colorHex, int? iconCodePoint}) async {
    try {
      if (subjects.any((s) => s.name.toLowerCase() == name.toLowerCase())) {
        Get.snackbar('error'.tr, 'duplicateSubject'.tr.replaceAll('{name}', name), snackPosition: SnackPosition.BOTTOM); return;
      }
      final sub = await _repo.create(name: name, imageUrl: imageUrl, colorHex: colorHex, iconCodePoint: iconCodePoint);
      subjects.insert(0, sub);
      Get.back();
      Get.snackbar('save'.tr, 'subjectAdded'.tr.replaceAll('{name}', name), snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success.withOpacity(0.1));
    } catch (e) { Get.snackbar('error'.tr, 'error'.tr); }
  }

  Future<void> deleteSubject(String id) async {
    try { await _repo.delete(id); subjects.removeWhere((s) => s.id == id); }
    catch (e) { Get.snackbar('error'.tr, 'error'.tr); }
  }

  void reorderSubjects(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = subjects.removeAt(oldIndex);
    subjects.insert(newIndex, item);
  }
}

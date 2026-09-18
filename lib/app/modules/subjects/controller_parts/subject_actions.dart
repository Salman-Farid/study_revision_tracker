part of '../subjects_controller.dart';

/// Subject CRUD, load, and reorder (order persisted across reloads).
extension SubjectsActions on SubjectsController {
  static const _subjectOrderKey = 'subject_grid_order_v1';

  Future<List<SubjectModel>> _orderSubjects(
      List<SubjectModel> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final order = prefs.getStringList(_subjectOrderKey);
      if (order == null || order.isEmpty) return list;
      final idx = {for (var i = 0; i < order.length; i++) order[i]: i};
      final sorted = list.toList()
        ..sort((a, b) {
          final ia = idx[a.id] ?? 1 << 20;
          final ib = idx[b.id] ?? 1 << 20;
          return ia.compareTo(ib);
        });
      return sorted;
    } catch (_) {
      return list;
    }
  }

  Future<void> _persistSubjectOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _subjectOrderKey,
        subjects.map((s) => s.id).toList(),
      );
    } catch (_) {}
  }

  Future<void> load() async {
    try {
      if (Get.find<SupabaseService>().currentUser == null) return;
      isLoading.value = true;
      final raw = await _repo.getAll();
      subjects.assignAll(await _orderSubjects(raw));
      await _recomputeProgress();
    } catch (e) {
      Get.snackbar('Error', 'Failed to load subjects: $e',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createSubject(
      {required String name,
      String? imageUrl,
      String? colorHex,
      int? iconCodePoint}) async {
    try {
      if (subjects.any((s) => s.name.toLowerCase() == name.toLowerCase())) {
        Get.snackbar('error'.tr,
            'duplicateSubject'.tr.replaceAll('{name}', name),
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      final sub = await _repo.create(
          name: name,
          imageUrl: imageUrl,
          colorHex: colorHex,
          iconCodePoint: iconCodePoint);
      subjects.insert(0, sub);
      await _persistSubjectOrder();
      Get.back();
      Get.snackbar(
          'save'.tr, 'subjectAdded'.tr.replaceAll('{name}', name),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success.withOpacity(0.1));
    } catch (e) {
      Get.snackbar('error'.tr, 'error'.tr);
    }
  }

  Future<void> deleteSubject(String id) async {
    try {
      await _repo.delete(id);
      subjects.removeWhere((s) => s.id == id);
      await _persistSubjectOrder();
    } catch (e) {
      Get.snackbar('error'.tr, 'error'.tr);
    }
  }

  void reorderSubjects(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final item = subjects.removeAt(oldIndex);
    subjects.insert(newIndex, item);
    unawaited(_persistSubjectOrder());
  }

  /// After grid drag-reorder (flutter_reorderable_grid_view).
  Future<void> applyReorderedSubjects(List<SubjectModel> next) async {
    subjects.assignAll(next);
    await _persistSubjectOrder();
  }
}

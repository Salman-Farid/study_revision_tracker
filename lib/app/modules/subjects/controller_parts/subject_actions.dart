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

  /// Wallpaper picker — expand/collapse on subject card (does not open topics).
  /// State lives on SubjectsController; methods live here.
  bool isWallpaperOpenFor(String subjectId) =>
      wallpaperSubjectId.value == subjectId;

  Future<void> toggleWallpaperPicker(SubjectModel subject) async {
    if (wallpaperSubjectId.value == subject.id) {
      closeWallpaperPicker();
      return;
    }
    wallpaperSubjectId.value = subject.id;
    wallpaperSubjectName.value = subject.name;
    wallpaperLoading.value = true;
    wallpaperUrls.clear();
    try {
      final pool =
          await ImageSearchService.fetchSubjectImagePool(subject.name);
      wallpaperUrls.assignAll(pool);
    } catch (_) {
      wallpaperUrls.clear();
    } finally {
      wallpaperLoading.value = false;
    }
  }

  void closeWallpaperPicker() {
    // Only mark closed — keep wallpaperUrls so the reverse animation
    // still has content (clearing them makes collapse look instant).
    wallpaperSubjectId.value = null;
    wallpaperLoading.value = false;
    wallpaperSubjectName.value = '';
  }

  /// Pick a cover — local update + DB write; close (animated) after apply.
  Future<void> applySubjectWallpaper(
      String subjectId, String imageUrl) async {
    closeWallpaperPicker();
    final i = subjects.indexWhere((s) => s.id == subjectId);
    if (i >= 0) {
      final s = subjects[i];
      subjects[i] = s.copyWith(imageUrl: imageUrl);
      subjects.refresh();
    }
    try {
      await _repo.update(subjectId, {'image_url': imageUrl});
      _repo.refresh();
    } catch (e) {
      Get.snackbar('error'.tr, 'error'.tr);
    }
  }
}

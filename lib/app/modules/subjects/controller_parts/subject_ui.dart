part of '../subjects_controller.dart';

/// Add-subject bottom sheet.
extension SubjectsUi on SubjectsController {
  void showAddSheet() {
    final nc = TextEditingController();
    final ic = TextEditingController();
    final sci = 0.obs;
    Get.bottomSheet(Container(padding: EdgeInsets.all(S.xl),
      decoration: BoxDecoration(color: AppColors.surface(Get.isDarkMode),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: AppColors.textMuted(Get.isDarkMode), borderRadius: BorderRadius.circular(2)))),
        SizedBox(height: S.xl),
        Text('addSubject'.tr, style: AppTextStyles.headlineSmall),
        SizedBox(height: S.xl),
        TextField(controller: nc, decoration: InputDecoration(
          labelText: 'subjectName'.tr, prefixIcon: Icon(Icons.book_rounded)), autofocus: true),
        SizedBox(height: S.base),
        TextField(controller: ic, decoration: InputDecoration(
          labelText: 'imageUrlOptional'.tr,
          prefixIcon: Icon(Icons.image_outlined),
          hintText: 'https://images.unsplash.com/...')),
        SizedBox(height: S.base),
        Text('color'.tr, style: AppTextStyles.labelLarge),
        SizedBox(height: S.sm),
        Obx(() => Wrap(spacing: S.sm, runSpacing: S.sm,
          children: List.generate(AppConstants.subjectColors.length, (i) => GestureDetector(
            onTap: () => sci.value = i,
            child: AnimatedContainer(duration: AppConstants.microDuration, width: 36, height: 36,
              decoration: BoxDecoration(color: AppConstants.subjectColors[i], shape: BoxShape.circle,
                border: sci.value == i ? Border.all(color: Colors.white, width: 3) : null,
                )))))),
        SizedBox(height: S.xl),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () {
          final n = nc.text.trim();
          if (n.isNotEmpty) {
            final hex = '#${AppConstants.subjectColors[sci.value].value.toRadixString(16).substring(2)}';
            final img = ic.text.trim();
            createSubject(name: n, imageUrl: img.isNotEmpty ? img : null, colorHex: hex);
          }}, child: Text('createSubject'.tr))),
        SizedBox(height: S.base),
      ])), isScrollControlled: true);
  }
}

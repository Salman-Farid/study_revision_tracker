import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/skeleton_loader.dart';
import 'subjects_controller.dart';
import 'widgets/subjects_grid.dart';

class SubjectsScreen extends GetView<SubjectsController> {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text('subjects'.tr, style: AppTextStyles.headlineMedium), actions: [
        IconButton(onPressed: controller.showAddSheet,
          icon: Icon(Icons.add_rounded, color: AppConstants.primaryColor),
          tooltip: 'addSubject'.tr),
      ]),
      floatingActionButton: FloatingActionButton(
        heroTag: null, // avoid Hero GlobalKey clashes across nav tabs
        onPressed: controller.openStudyAssistantDialogue,
        backgroundColor: AppConstants.primaryColor,
        child: const Icon(Icons.mic_rounded, color: Colors.white),
      ),
      body: Obx(() {
        if (controller.isLoading.value) return const SkeletonGrid();
        if (controller.subjects.isEmpty) return EmptyState(icon: Icons.menu_book_rounded,
          title: 'noSubjectsYet'.tr, subtitle: 'addFirstSubject'.tr,
          actionLabel: 'addSubject'.tr, onAction: controller.showAddSheet);
        return SubjectsGrid(d: d, controller: controller);
      }),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/size_constants.dart';
import '../../../data/models/subject_model.dart';
import '../../../theme/app_theme.dart';
import '../../subject_detail/subject_detail_controller.dart';
import '../../subject_detail/subject_detail_screen.dart';
import '../../subjects/subjects_controller.dart';

/// Right pane: selected subject detail, or a picker hint.
class SubjectDetailPane extends StatelessWidget {
  const SubjectDetailPane({super.key});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final subjectsCtrl = Get.find<SubjectsController>();
      final subject = subjectsCtrl.selectedSubject;
      if (subject == null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_rounded, size: 48, color: AppColors.textMuted(d)),
                const SizedBox(height: 12),
                Text(
                  'Select a subject',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: AppColors.textPrimary(d),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Topics and revisions open here',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted(d),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return EmbeddedSubjectDetail(subject: subject);
    });
  }
}

class EmbeddedSubjectDetail extends StatefulWidget {
  const EmbeddedSubjectDetail({super.key, required this.subject});
  final SubjectModel subject;

  @override
  State<EmbeddedSubjectDetail> createState() => _EmbeddedSubjectDetailState();
}

class _EmbeddedSubjectDetailState extends State<EmbeddedSubjectDetail> {
  String? _boundId;

  @override
  Widget build(BuildContext context) {
    final subject = widget.subject;
    if (_boundId != subject.id) {
      _boundId = subject.id;
      if (Get.isRegistered<SubjectDetailController>()) {
        Get.find<SubjectDetailController>().switchSubject(subject);
      } else {
        Get.put(SubjectDetailController(initialSubject: subject));
      }
    }
    if (!Get.isRegistered<SubjectDetailController>()) {
      return const Center(child: CircularProgressIndicator());
    }
    // Key forces a rebuild when the subject changes (title, chips, list).
    return SubjectDetailScreen(key: ValueKey('subject_detail_${subject.id}'));
  }
}

/// Card-like chrome for side-by-side panes.
class PaneFrame extends StatelessWidget {
  const PaneFrame({super.key, required this.child, this.showBorder = true});

  final Widget child;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    if (!showBorder) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface(d),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(d)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: d ? 0.25 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

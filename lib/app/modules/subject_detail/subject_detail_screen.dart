import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_state.dart';
import 'subject_detail_controller.dart';

class SubjectDetailScreen extends GetView<SubjectDetailController> {
  const SubjectDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text(controller.subject.name)),
        actions: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: controller.openVoiceAssistant,
              icon: Icon(Icons.mic_rounded, color: AppConstants.primaryColor),
              tooltip: 'studyRoutine'.tr,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.showAddSheet,
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          _chipTabs(d),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.topics.isEmpty) {
                return EmptyState(
                  icon: Icons.topic_rounded,
                  title: 'noTopicsYet'.tr,
                  subtitle: 'Add topics to "${controller.subject.name}"',
                  actionLabel: 'addTopic'.tr,
                  onAction: controller.showAddSheet,
                );
              }
              final filtered = controller.filteredTopics;
              if (filtered.isEmpty) {
                return EmptyState(
                  icon: Icons.filter_list_off_rounded,
                  title: 'noTopicsYet'.tr,
                  subtitle: 'No topics match this filter',
                );
              }
              return _list(d, filtered);
            }),
          ),
        ],
      ),
    );
  }

  Widget _chipTabs(bool d) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: S.base, vertical: S.sm),
      child: Obx(() {
        final selected = controller.selectedFilter.value;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chip(d, 'all'.tr, controller.topics.length, selected == 'all', () {
                controller.selectedFilter.value = 'all';
              }),
              SizedBox(width: S.sm),
              _chip(d, 'firstRead'.tr, controller.firstReadCount, selected == 'firstRead', () {
                controller.selectedFilter.value = 'firstRead';
              }),
              SizedBox(width: S.sm),
              _chip(d, 'inRevision'.tr, controller.inRevisionCount, selected == 'inRevision', () {
                controller.selectedFilter.value = 'inRevision';
              }),
              SizedBox(width: S.sm),
              _chip(d, 'done'.tr, controller.completedCount, selected == 'completed', () {
                controller.selectedFilter.value = 'completed';
              }),
            ],
          ),
        );
      }),
    );
  }

  Widget _chip(bool d, String label, int count, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface(d),
          borderRadius: BorderRadius.circular(S.radiusFull),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border(d),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary(d),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (count > 0) ...[
              SizedBox(width: S.xs),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.textMuted(d).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(S.radiusFull),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isSelected ? Colors.white : AppColors.textMuted(d),
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _list(bool d, List topics) {
    final isAllFilter = controller.selectedFilter.value == 'all';
    return ReorderableListView.builder(
      padding: EdgeInsets.all(S.base),
      itemCount: topics.length,
      onReorder: isAllFilter ? controller.reorderTopics : (oldIndex, newIndex) {},
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (_, __) => Material(color: Colors.transparent, elevation: 0, child: child),
        );
      },
      itemBuilder: (_, i) {
        final t = topics[i];
        final isFirstRead = !t.firstReadCompleted;
        final isCompleted = t.totalRevisions >= 6;

        if (isFirstRead) {
          return _firstReadCard(d, t, isAllFilter, i);
        } else {
          return _expandableRevisionCard(d, t, isCompleted, isAllFilter, i);
        }
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  FIRST READ CARD — compact, same style as revision collapsed
  // ══════════════════════════════════════════════════════════════
  Widget _firstReadCard(bool d, dynamic t, bool isAllFilter, int index) {
    return Container(
      key: Key(t.id),
      margin: EdgeInsets.only(bottom: S.md),
      padding: EdgeInsets.all(S.base),
      decoration: BoxDecoration(
        color: AppColors.surface(d),
        borderRadius: BorderRadius.circular(S.radiusLg),
        border: Border.all(color: AppColors.border(d)),
        boxShadow: S.shadowSm,
      ),
      child: Row(
        children: [
          if (isAllFilter) ...[
            Icon(Icons.drag_handle_rounded, color: AppColors.textMuted(d), size: 20),
            SizedBox(width: S.md),
          ],
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.warning, width: 1.5),
            ),
            child: Icon(Icons.menu_book_rounded, color: AppColors.warning, size: 22),
          ),
          SizedBox(width: S.md),
          // Name + badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.name,
                  style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimary(d)),
                ),
                SizedBox(height: S.xs),
                _badge(d, 'firstRead'.tr, AppColors.warning),
              ],
            ),
          ),
          // Complete button
          GestureDetector(
            onTap: () => _confirmFirstRead(d, t),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: S.md, vertical: S.sm),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(S.radiusFull),
                border: Border.all(color: AppColors.warning, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: AppColors.warning),
                  SizedBox(width: 4),
                  Text(
                    'Complete',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: S.sm),
          _deleteButton(d, t),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  EXPANDABLE REVISION / DONE CARD
  //  Collapsed: same look as first read card
  //  Expanded (tap): slowmo fade+slide animation reveals delivery trail
  // ══════════════════════════════════════════════════════════════
  Widget _expandableRevisionCard(
    bool d, dynamic t, bool isCompleted, bool isAllFilter, int index,
  ) {
    final dayLabels = ['1', '3', '7', '14', '30', '90'];
    final statusLabels = [
      '1st Revision', '2nd Revision', '3rd Revision',
      '4th Revision', '5th Revision', '6th Revision',
    ];
    final List<Color> stageColors = [
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFF9C27B0),
      const Color(0xFFFF9800),
      const Color(0xFFE91E63),
      const Color(0xFF00BCD4),
    ];

    return _ExpandableCard(
      key: Key('exp_${t.id}'),
      builder: (context, isExpanded, toggleExpand, animController) {
        return Container(
          margin: EdgeInsets.only(bottom: S.md),
          decoration: BoxDecoration(
            color: AppColors.surface(d),
            borderRadius: BorderRadius.circular(S.radiusLg),
            border: Border.all(
              color: isExpanded
                  ? (isCompleted ? AppColors.success : AppColors.info).withValues(alpha: 0.4)
                  : AppColors.border(d),
              width: isExpanded ? 1.5 : 1,
            ),
            boxShadow: isExpanded ? S.shadowMd : S.shadowSm,
          ),
          child: Column(
            children: [
              // ── COLLAPSED HEADER (always visible) ──
              GestureDetector(
                onTap: toggleExpand,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.all(S.base),
                  child: Row(
                    children: [
                      if (isAllFilter) ...[
                        Icon(Icons.drag_handle_rounded, color: AppColors.textMuted(d), size: 20),
                        SizedBox(width: S.md),
                      ],
                      _collapsedIndicator(d, t, isCompleted),
                      SizedBox(width: S.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.name,
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.textPrimary(d),
                              ),
                            ),
                            SizedBox(height: S.xs),
                            _statusBadge(d, t, dayLabels),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textMuted(d),
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── EXPANDED TRAIL (slowmo fade+slide) ──
              _AnimatedExpanded(
                controller: animController,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(S.base, 0, S.base, S.base),
                  child: _deliveryTrailContent(
                    d, t, isCompleted,
                    dayLabels, statusLabels, stageColors,
                    controller.getSchedules(t.id),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Collapsed indicator: circular progress for revision/done
  Widget _collapsedIndicator(bool d, dynamic t, bool isCompleted) {
    final total = t.totalRevisions.clamp(0, 6);
    final progress = total / 6;
    final color = isCompleted
        ? AppColors.success
        : AppColors.info;

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 4,
              color: AppColors.border(d),
            ),
          ),
          // Progress circle
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4,
              color: color,
              strokeCap: StrokeCap.round,
            ),
          ),
          // Center text
          Text(
            '$total',
            style: AppTextStyles.titleMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  DELIVERY TRAIL CONTENT (shown inside expanded card)
  // ══════════════════════════════════════════════════════════════
  Widget _deliveryTrailContent(
    bool d,
    dynamic t,
    bool isCompleted,
    List<String> dayLabels,
    List<String> statusLabels,
    List<Color> stageColors,
    List<dynamic> schedules,
  ) {
    final completedCount = t.totalRevisions.clamp(0, 6);
    final nodeSize = 24.0;
    final lineHeight = 20.0;
    final trailWidth = 2.5;
    final trailLeft = (nodeSize - trailWidth) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: AppColors.border(d)),
        SizedBox(height: S.md),
        Text(
          isCompleted
              ? 'allRevisionsDone'.tr
              : 'revisionsOfDone'.tr.replaceAll('{n}', '$completedCount'),
          style: AppTextStyles.labelMedium.copyWith(
            color: isCompleted ? AppColors.success : AppColors.textMuted(d),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: S.md),
        // Trail steps
        ...List.generate(6, (i) {
          final isStepCompleted = i < completedCount;
          final isCurrent = i == completedCount && !isCompleted;
          final isLast = i == 5;
          final color = stageColors[i]; // each step ALWAYS gets its own color

          return GestureDetector(
            onTap: (isCurrent && !isCompleted)
                ? () => _confirmRevision(d, t, dayLabels[i])
                : null,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Node + vertical line column
                  SizedBox(
                    width: nodeSize,
                    height: nodeSize + lineHeight,
                    child: Stack(
                      children: [
                        // Vertical connecting line — colored per step
                        if (!isLast)
                          Positioned(
                            left: trailLeft,
                            top: nodeSize,
                            width: trailWidth,
                            height: lineHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isStepCompleted || isCompleted
                                    ? color
                                    : color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(trailWidth / 2),
                              ),
                            ),
                          ),
                        // Node circle — colored per step
                        Positioned(
                          left: 0,
                          top: 0,
                          child: Container(
                            width: nodeSize,
                            height: nodeSize,
                            decoration: BoxDecoration(
                              color: isStepCompleted || isCompleted
                                  ? color
                                  : isCurrent
                                      ? color.withValues(alpha: 0.12)
                                      : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isStepCompleted || isCompleted || isCurrent
                                    ? color
                                    : color.withValues(alpha: 0.25),
                                width: isCurrent ? 2.5 : 2.0,
                              ),
                              boxShadow: (isStepCompleted || isCompleted)
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.3),
                                        blurRadius: 5,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: isStepCompleted || isCompleted
                                  ? Icon(Icons.check_rounded, size: 13, color: Colors.white)
                                  : isCurrent
                                      ? Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                          ),
                                        )
                                      : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  // Labels + action
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Day ${dayLabels[i]} — ${statusLabels[i]}',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isStepCompleted || isCompleted
                                        ? color
                                        : isCurrent
                                            ? color
                                            : color.withValues(alpha: 0.4),
                                  ),
                                ),
                                // Show scheduled date
                                if (i < schedules.length)
                                  Text(
                                    _formatDate(schedules[i].scheduledDate),
                                    style: AppTextStyles.labelSmall.copyWith(
                                      fontSize: 10,
                                      color: isStepCompleted || isCompleted
                                          ? color.withValues(alpha: 0.8)
                                          : isCurrent
                                              ? color.withValues(alpha: 0.7)
                                              : color.withValues(alpha: 0.35),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // Mark complete button for current step
                          if (isCurrent && !isCompleted)
                            GestureDetector(
                              onTap: () => _confirmRevision(d, t, dayLabels[i]),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(S.radiusFull),
                                  border: Border.all(color: color, width: 1.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 14, color: color),
                                    SizedBox(width: 4),
                                    Text(
                                      'Mark Done',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: color,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Completed checkmark
                          if (isStepCompleted || isCompleted)
                            Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.check_rounded, size: 14, color: color),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        SizedBox(height: S.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [_deleteButton(d, t)],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  DIALOGS
  // ══════════════════════════════════════════════════════════════
  void _confirmFirstRead(bool d, dynamic t) {
    Get.defaultDialog(
      title: 'firstRead'.tr,
      middleText: 'Mark "${t.name}" as first read completed?',
      textConfirm: 'ok'.tr,
      textCancel: 'cancel'.tr,
      confirmTextColor: Colors.white,
      buttonColor: AppColors.warning,
      onConfirm: () {
        Get.back();
        controller.markFirstRead(t.id);
      },
    );
  }

  void _confirmRevision(bool d, dynamic t, String dayLabel) {
    final dayNumber = int.parse(dayLabel);
    Get.defaultDialog(
      title: 'markDone'.tr,
      middleText: 'Mark Day $dayNumber revision for "${t.name}" as done?',
      textConfirm: 'ok'.tr,
      textCancel: 'cancel'.tr,
      confirmTextColor: Colors.white,
      buttonColor: AppColors.info,
      onConfirm: () {
        Get.back();
        controller.markRevisionComplete(t.id, dayNumber);
      },
    );
  }

  Widget _deleteButton(bool d, dynamic t) {
    return GestureDetector(
      onTap: () => Get.defaultDialog(
        title: 'deleteQ'.tr,
        middleText: 'Delete "${t.name}"?',
        textConfirm: 'delete'.tr,
        textCancel: 'cancel'.tr,
        confirmTextColor: Colors.white,
        buttonColor: AppColors.error,
        onConfirm: () {
          controller.deleteTopic(t.id);
          Get.back();
        },
      ),
      child: Container(
        padding: EdgeInsets.all(S.sm),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(S.radiusSm),
        ),
        child: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ══════════════════════════════════════════════════════════════
  //  BADGES
  // ══════════════════════════════════════════════════════════════
  Widget _statusBadge(bool d, dynamic t, List<String> dayLabels) {
    if (!t.firstReadCompleted) {
      return _badge(d, 'firstRead'.tr, AppColors.warning);
    } else if (t.totalRevisions >= 6) {
      return _badge(d, 'statCompleted'.tr, AppColors.success);
    } else {
      return _badge(d, 'Day ${dayLabels[t.totalRevisions]} • ${t.totalRevisions + 1}/6', AppColors.info);
    }
  }

  Widget _badge(bool d, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(S.radiusSm),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  EXPANDABLE CARD WIDGET — smooth slowmo expand/collapse
// ══════════════════════════════════════════════════════════════
class _ExpandableCard extends StatefulWidget {
  final Widget Function(BuildContext context, bool isExpanded, VoidCallback toggleExpand, AnimationController animController) builder;

  const _ExpandableCard({super.key, required this.builder});

  @override
  State<_ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<_ExpandableCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
      reverseDuration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _isExpanded, _toggle, _controller);
  }
}

/// Wraps expanded content with slowmo fade + slide animation
class _AnimatedExpanded extends StatelessWidget {
  final AnimationController controller;
  final Widget child;

  const _AnimatedExpanded({required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    final fadeAnim = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    );
    final slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
      reverseCurve: Curves.easeInOut,
    ));

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.value == 0.0) return const SizedBox.shrink();
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: fadeAnim.value,
            child: FadeTransition(
              opacity: fadeAnim,
              child: SlideTransition(
                position: slideAnim,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

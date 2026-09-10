import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

import '../../../gemini_3_flash_live_voice_chatbot/features/voice_assistant/study_assistant_dialogue.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';
import '../../data/models/class_routine_model.dart';
import 'routine_controller.dart';

class RoutineScreen extends GetView<RoutineController> {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.bg(d),
      appBar: AppBar(
        backgroundColor: AppColors.bg(d),
        elevation: 0,
        title: Text('routine'.tr),
        actions: [
          IconButton(
            tooltip: 'assistant'.tr,
            icon: const Icon(Icons.mic_rounded),
            onPressed: controller.openAssistant,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _ModeToggle(controller: controller),
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return controller.mode.value == RoutineMode.daily
                        ? _DailyShimmer(d: d)
                        : _ClassShimmer(d: d);
                  }
                  return controller.mode.value == RoutineMode.daily
                      ? _DailyBody(controller: controller)
                      : _ClassBody(controller: controller);
                }),
              ),
            ],
          ),
          Obx(() {
            if (!controller.voice.showDialogue.value) {
              return const SizedBox.shrink();
            }
            return const StudyAssistantDialogue();
          }),
        ],
      ),
    );
  }
}

// ── Mode Toggle ──

class _ModeToggle extends StatelessWidget {
  final RoutineController controller;
  const _ModeToggle({required this.controller});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(S.base, S.sm, S.base, S.sm),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: (d ? AppColors.surfaceDark : AppColors.surfaceLight)
              .withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(S.radiusFull),
          border: Border.all(
            color: (d ? Colors.white : Colors.black).withValues(alpha: 0.06),
          ),
        ),
        child: Obx(() {
          final mode = controller.mode.value;
          return Row(
            children: [
              Expanded(
                child: _Segment(
                  label: 'dailyRoutine'.tr,
                  icon: Icons.today_rounded,
                  active: mode == RoutineMode.daily,
                  onTap: () => controller.switchMode(RoutineMode.daily),
                  d: d,
                ),
              ),
              Expanded(
                child: _Segment(
                  label: 'classRoutine'.tr,
                  icon: Icons.event_note_rounded,
                  active: mode == RoutineMode.class$,
                  onTap: () => controller.switchMode(RoutineMode.class$),
                  d: d,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final bool d;
  const _Segment({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    required this.d,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? AppConstants.primaryColor.withValues(alpha: 0.18)
        : Colors.transparent;
    final border = active
        ? AppConstants.primaryColor.withValues(alpha: 0.6)
        : Colors.transparent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.shortDuration,
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(vertical: S.sm, horizontal: S.sm),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(S.radiusFull),
          border: Border.all(color: border, width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active
                  ? AppConstants.primaryColor
                  : AppColors.textMuted(d),
            ),
            SizedBox(width: S.sm),
            Text(
              label,
              style: AppTextStyles.titleSmall.copyWith(
                color: active
                    ? AppConstants.primaryColor
                    : AppColors.textMuted(d),
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Daily Routine: today's items (daily routine + unfinished classes) ──

class _DailyBody extends StatelessWidget {
  final RoutineController controller;
  const _DailyBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final items = controller.todayItems;
      if (items.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_available_rounded,
                  size: 48, color: AppColors.textMuted(d)),
              SizedBox(height: S.md),
              Text(
                'noRoutinesForToday'.tr,
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary(d),
                ),
              ),
              SizedBox(height: S.sm),
              Text(
                'tapMicToAskAssistant'.tr,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted(d),
                ),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.fromLTRB(S.base, 0, S.base, S.xxxl),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          return _RoutineTile(item: item, d: d);
        },
      );
    });
  }
}

// ── Class Routine: all class routines ──

class _ClassBody extends StatelessWidget {
  final RoutineController controller;
  const _ClassBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final routines = controller.classRoutines;
      if (routines.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_note_rounded,
                  size: 48, color: AppColors.textMuted(d)),
              SizedBox(height: S.md),
              Text(
                'noClassRoutines'.tr,
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary(d),
                ),
              ),
              SizedBox(height: S.sm),
              Text(
                'sayToAddOne'.tr,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted(d),
                ),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: EdgeInsets.fromLTRB(S.base, 0, S.base, S.xxxl),
        itemCount: routines.length,
        itemBuilder: (_, i) {
          final cr = routines[i];
          return _ClassRoutineTile(cr: cr, d: d);
        },
      );
    });
  }
}

// ── Tiles ──

class _RoutineTile extends StatelessWidget {
  final RoutineDisplayItem item;
  final bool d;
  const _RoutineTile({required this.item, required this.d});

  /// Soft background color per block type (99% white, 1% tint)
  Color _bgColor() {
    switch (item.type) {
      case 'class':
        return const Color(0xFFF8FAFF); // barely-there blue
      case 'study':
      case 'first_read':
      case 'revision':
        return const Color(0xFFF7FBF7); // barely-there green
      case 'break':
        return const Color(0xFFFEFCF6); // barely-there amber
      case 'meal':
        return const Color(0xFFFEF8FA); // barely-there pink
      case 'nap':
        return const Color(0xFFFBF8FE); // barely-there purple
      case 'recall':
        return const Color(0xFFF6FDFE); // barely-there cyan
      case 'question_practice':
        return const Color(0xFFFEFAF5); // barely-there orange
      case 'review':
        return const Color(0xFFF6FDF8); // barely-there teal
      default:
        return AppColors.surfaceLight;
    }
  }

  /// Accent color for icon/strip
  Color _accentColor() {
    switch (item.type) {
      case 'class':
        return const Color(0xFF5B8DEF); // blue
      case 'study':
      case 'first_read':
      case 'revision':
        return const Color(0xFF4CAF50); // green
      case 'break':
        return const Color(0xFFFFB74D); // amber
      case 'meal':
        return const Color(0xFFEC407A); // pink
      case 'nap':
        return const Color(0xFFAB7EFF); // purple
      case 'recall':
        return const Color(0xFF26C6DA); // cyan
      case 'question_practice':
        return const Color(0xFFFF9800); // orange
      case 'review':
        return const Color(0xFF66BB6A); // teal
      default:
        return AppConstants.primaryColor;
    }
  }

  IconData _icon() {
    switch (item.type) {
      case 'class':
        return Icons.school_rounded;
      case 'break':
        return Icons.coffee_rounded;
      case 'meal':
        return Icons.restaurant_rounded;
      case 'nap':
        return Icons.bedtime_rounded;
      case 'recall':
        return Icons.psychology_rounded;
      case 'question_practice':
        return Icons.quiz_rounded;
      case 'review':
        return Icons.replay_rounded;
      case 'study':
      case 'first_read':
      case 'revision':
      default:
        return Icons.menu_book_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor();
    final bgColor = _bgColor();
    final displayTitle = item.displayTitle;
    final tagline = item.tagline;

    return Container(
      margin: EdgeInsets.only(bottom: S.sm),
      padding: EdgeInsets.all(S.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(S.radiusLg),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // ── Accent strip ──
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: S.sm),
          // ── Content ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: timeline + icon + location
                Row(
                  children: [
                    Icon(_icon(), size: 14, color: accent),
                    SizedBox(width: 4),
                    Text(
                      item.timelineText,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.locationText.isNotEmpty) ...[
                      SizedBox(width: 8),
                      Icon(Icons.location_on_outlined,
                          size: 12, color: AppColors.textMuted(d)),
                      SizedBox(width: 2),
                      Text(
                        item.locationText,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textMuted(d),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 4),
                // Row 2: title (type-based)
                Text(
                  displayTitle,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary(d),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Row 3: tagline or topic
                if (tagline != null && tagline.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    tagline,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary(d),
                      fontStyle: (item.type == 'break' || item.type == 'nap')
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // ── Duration badge ──
          Container(
            padding: EdgeInsets.symmetric(horizontal: S.sm, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(S.radiusSm),
            ),
            child: Text(
              item.durationText,
              style: AppTextStyles.labelSmall.copyWith(color: accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassRoutineTile extends StatelessWidget {
  final ClassRoutineModel cr;
  final bool d;
  const _ClassRoutineTile({required this.cr, required this.d});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: S.sm),
      padding: EdgeInsets.all(S.md),
      decoration: BoxDecoration(
        color: (d ? AppColors.surfaceDark : AppColors.surfaceLight)
            .withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(S.radiusLg),
        border: Border.all(
          color: AppConstants.infoColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject name
          Text(
            cr.subjectName,
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.textPrimary(d),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: S.sm),
          // 3-section row: DATE | TIME | LOCATION
          Row(
            children: [
              // Section 1: Date
              _buildSection(
                icon: Icons.calendar_today_rounded,
                label: cr.daysText.isNotEmpty ? cr.daysText : 'oneTime'.tr,
                sub: cr.dates.isNotEmpty ? cr.dates.first : '',
                color: AppConstants.infoColor,
              ),
              Container(
                width: 1,
                height: 32,
                margin: EdgeInsets.symmetric(horizontal: S.sm),
                color: AppColors.textMuted(d).withValues(alpha: 0.3),
              ),
              // Section 2: Time
              _buildSection(
                icon: Icons.access_time_rounded,
                label: '${cr.timeText} - ${cr.endTimeText}',
                sub: cr.durationText,
                color: AppColors.accent,
              ),
              Container(
                width: 1,
                height: 32,
                margin: EdgeInsets.symmetric(horizontal: S.sm),
                color: AppColors.textMuted(d).withValues(alpha: 0.3),
              ),
              // Section 3: Location
              _buildSection(
                icon: Icons.location_on_rounded,
                label: cr.locationText.isNotEmpty ? cr.locationText : 'tba'.tr,
                sub: cr.room != null ? 'roomNumber'.tr.replaceAll('{room}', '${cr.room}') : '',
                color: AppColors.warning,
              ),
            ],
          ),
          if (cr.notes != null && cr.notes!.isNotEmpty) ...[
            SizedBox(height: S.sm),
            Text(
              cr.notes!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted(d),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (sub.isNotEmpty)
            Text(
              sub,
              style: AppTextStyles.labelSmall.copyWith(
                color: color.withValues(alpha: 0.7),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}

// ── Shimmer Skeletons ──

class _DailyShimmer extends StatelessWidget {
  final bool d;
  const _DailyShimmer({required this.d});

  @override
  Widget build(BuildContext context) {
    final baseColor = d ? const Color(0xFF2D3140) : const Color(0xFFE8ECF4);
    final highlightColor = d ? const Color(0xFF3D4250) : const Color(0xFFF0F3F8);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(S.base, 0, S.base, S.xxxl),
        itemCount: 6,
        itemBuilder: (_, i) => Container(
          margin: EdgeInsets.only(bottom: S.sm),
          padding: EdgeInsets.all(S.md),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(S.radiusLg),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: highlightColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: S.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 12, height: 12, color: highlightColor),
                        SizedBox(width: 6),
                        Container(width: 100, height: 10, color: highlightColor),
                      ],
                    ),
                    SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 12,
                      color: highlightColor,
                    ),
                    SizedBox(height: 6),
                    Container(width: 140, height: 10, color: highlightColor),
                  ],
                ),
              ),
              SizedBox(width: S.sm),
              Container(
                width: 40,
                height: 20,
                decoration: BoxDecoration(
                  color: highlightColor,
                  borderRadius: BorderRadius.circular(S.radiusSm),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassShimmer extends StatelessWidget {
  final bool d;
  const _ClassShimmer({required this.d});

  @override
  Widget build(BuildContext context) {
    final baseColor = d ? const Color(0xFF2D3140) : const Color(0xFFE8ECF4);
    final highlightColor = d ? const Color(0xFF3D4250) : const Color(0xFFF0F3F8);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(S.base, 0, S.base, S.xxxl),
        itemCount: 5,
        itemBuilder: (_, i) => Container(
          margin: EdgeInsets.only(bottom: S.sm),
          padding: EdgeInsets.all(S.md),
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(S.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 160,
                height: 14,
                color: highlightColor,
              ),
              SizedBox(height: S.sm),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Container(width: 14, height: 14, color: highlightColor),
                        SizedBox(height: 4),
                        Container(width: 60, height: 8, color: highlightColor),
                        SizedBox(height: 2),
                        Container(width: 40, height: 8, color: highlightColor),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: highlightColor,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Container(width: 14, height: 14, color: highlightColor),
                        SizedBox(height: 4),
                        Container(width: 80, height: 8, color: highlightColor),
                        SizedBox(height: 2),
                        Container(width: 50, height: 8, color: highlightColor),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: highlightColor,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Container(width: 14, height: 14, color: highlightColor),
                        SizedBox(height: 4),
                        Container(width: 50, height: 8, color: highlightColor),
                        SizedBox(height: 2),
                        Container(width: 30, height: 8, color: highlightColor),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/size_constants.dart';
import '../../../domain/routine/routine_timeline.dart';
import '../../../theme/app_theme.dart';
import '../../routine/widgets/routine_block_palette.dart';
import '../dashboard_controller.dart';

/// Live daily-routine card — same soft type colors as Routine tab tiles.
/// Countdown ticks every second and ALWAYS advances to the next block
/// when the current one ends (never counts up +mm:ss).
class DailyRoutineLiveCard extends StatelessWidget {
  final bool d;
  final DashboardController controller;
  const DailyRoutineLiveCard(
      {super.key, required this.d, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.hasDailyRoutineToday.value) {
        return const SizedBox.shrink();
      }
      return StreamBuilder<int>(
        stream: Stream.periodic(const Duration(seconds: 1), (_) => 0),
        builder: (_, __) {
          final now = DateTime.now();
          final items = controller.todayRoutineItems;
          // Live pick: current block, or next one if the last one just ended.
          final active = RoutineTimeline.activeOrNext(items, now);
          final upcoming =
              items.where((it) => it.start.isAfter(now)).toList();
          final done = items
              .where((it) => !it.end.isAfter(now))
              .length;

          return Container(
            margin: EdgeInsets.fromLTRB(S.xl, 0, S.xl, S.md),
            padding: EdgeInsets.all(S.xl),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(S.radiusLg),
              border: Border.all(color: AppColors.borderLight, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(S.sm + 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(S.radiusSm),
                      ),
                      child: Icon(
                        Icons.schedule_rounded,
                        color: AppColors.primary,
                        size: S.iconMd,
                      ),
                    ),
                    SizedBox(width: S.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'dailyRoutine'.tr,
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.textPrimaryLight,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${done.clamp(0, items.length)}/${items.length} blocks',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textMuted(d)),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: controller.openRoutineTab,
                      child: Text(
                        'open'.tr,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (active != null) ...[
                  SizedBox(height: S.md),
                  _NowBlock(item: active, now: now, d: d),
                ] else if (items.isNotEmpty) ...[
                  SizedBox(height: S.md),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(S.base),
                    decoration: BoxDecoration(
                      color: RoutineBlockPalette.bg('study'),
                      borderRadius: BorderRadius.circular(S.radiusMd),
                      border: Border.all(
                        color: RoutineBlockPalette.accent('study')
                            .withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      'Day complete — nice work.',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.textPrimary(d),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (upcoming.isNotEmpty) ...[
                  SizedBox(height: S.md),
                  Text(
                    'UP NEXT',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textMuted(d),
                      letterSpacing: 0.06,
                    ),
                  ),
                  SizedBox(height: S.sm),
                  SizedBox(
                    height: 86,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: upcoming.length,
                      separatorBuilder: (_, __) => SizedBox(width: S.sm),
                      itemBuilder: (_, i) =>
                          _UpNextCard(item: upcoming[i], d: d),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    });
  }
}

class _NowBlock extends StatelessWidget {
  const _NowBlock({required this.item, required this.now, required this.d});
  final RoutineTimelineItem item;
  final DateTime now;
  final bool d;

  @override
  Widget build(BuildContext context) {
    final type = item.type;
    final accent = RoutineBlockPalette.accent(type);
    final bg = RoutineBlockPalette.bg(type);
    final rem = item.end.difference(now);
    // Never show count-up — clamp at 00:00 if end is this second.
    final totalSec = rem.isNegative ? 0 : rem.inSeconds;
    final mm = (totalSec ~/ 60).toString().padLeft(2, '0');
    final ss = (totalSec % 60).toString().padLeft(2, '0');
    final startsLater = item.start.isAfter(now);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(S.base),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(S.radiusMd),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: S.sm),
          Container(
            padding: EdgeInsets.symmetric(horizontal: S.sm, vertical: 2),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              startsLater ? 'NEXT' : 'NOW',
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 9,
              ),
            ),
          ),
          SizedBox(width: S.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(RoutineBlockPalette.icon(type),
                        size: 14, color: accent),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: AppColors.textPrimaryLight,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  '${item.timeText} – ${item.endTimeText}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Builder(builder: (_) {
                  final tip = item.tagline;
                  if (tip == null || tip.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      tip,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted(d),
                        fontStyle: (type == 'break' ||
                                type == 'meal' ||
                                type == 'nap')
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          StreamBuilder<int>(
            stream: Stream.periodic(const Duration(seconds: 1), (_) => 0),
            builder: (_, __) {
              final n = DateTime.now();
              final r = item.end.difference(n);
              final secs = r.isNegative ? 0 : r.inSeconds;
              final m = (secs ~/ 60).toString().padLeft(2, '0');
              final s = (secs % 60).toString().padLeft(2, '0');
              final untilStart = item.start.difference(n);
              final showWait = item.start.isAfter(n);
              final waitSec =
                  untilStart.isNegative ? 0 : untilStart.inSeconds;
              final wm = (waitSec ~/ 60).toString().padLeft(2, '0');
              final ws = (waitSec % 60).toString().padLeft(2, '0');
              return Text(
                showWait ? 'in $wm:$ws' : '$m:$s',
                style: AppTextStyles.titleMedium.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontSize: 18,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UpNextCard extends StatelessWidget {
  const _UpNextCard({required this.item, required this.d});
  final dynamic item;
  final bool d;

  @override
  Widget build(BuildContext context) {
    final type = item.type as String;
    final accent = RoutineBlockPalette.accent(type);
    final bg = RoutineBlockPalette.bg(type);

    return Container(
      width: 156,
      padding: EdgeInsets.all(S.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(S.radiusMd),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(RoutineBlockPalette.icon(type), size: 12, color: accent),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${item.timeText} – ${item.endTimeText}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            item.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.textPrimary(d),
              fontSize: 12,
            ),
          ),
          Builder(builder: (_) {
            final tip = item.tagline;
            if (tip == null || tip.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                tip,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted(d),
                  fontSize: 10,
                  fontStyle: (type == 'break' || type == 'meal' || type == 'nap')
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

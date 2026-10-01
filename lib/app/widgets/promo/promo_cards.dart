import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';

class WidgetPromoCards extends StatelessWidget {
  final bool d;
  final Map<String, bool> added;
  final Future<void> Function(String name, String qualifiedName) onAdd;
  const WidgetPromoCards({
    super.key,
    required this.d,
    required this.added,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: S.xl),
      child: Column(
        children: [
          WidgetPromoCard(
            d: d,
            icon: Icons.schedule_rounded,
            title: 'dailyRoutine'.tr,
            desc: 'widgetPromoDailyDesc'.tr,
            color: const Color(0xFF6C63FF),
            name: 'dailyRoutine',
            qualifiedName: 'com.pootustudycompanion.app.DailyRoutineWidget',
            isAdded: added['dailyRoutine'] == true,
            onAdd: onAdd,
          ),
          SizedBox(height: S.sm),
          WidgetPromoCard(
            d: d,
            icon: Icons.replay_rounded,
            title: 'classRoutine'.tr,
            desc: 'widgetPromoClassDesc'.tr,
            color: const Color(0xFF26A69A),
            name: 'classRoutine',
            qualifiedName: 'com.pootustudycompanion.app.ClassRoutineWidget',
            isAdded: added['classRoutine'] == true,
            onAdd: onAdd,
          ),
          SizedBox(height: S.sm),
          WidgetPromoCard(
            d: d,
            icon: Icons.school_rounded,
            title: 'revisionsLabel'.tr,
            desc: 'widgetPromoRevisionDesc'.tr,
            color: const Color(0xFFFF8A65),
            name: 'revision',
            qualifiedName: 'com.pootustudycompanion.app.RevisionWidget',
            isAdded: added['revision'] == true,
            onAdd: onAdd,
          ),
        ],
      ),
    );
  }
}

class WidgetPromoCard extends StatelessWidget {
  final bool d;
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  final String name;
  final String qualifiedName;
  final bool isAdded;
  final Future<void> Function(String name, String qualifiedName) onAdd;
  const WidgetPromoCard({
    super.key,
    required this.d,
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
    required this.name,
    required this.qualifiedName,
    required this.isAdded,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: EdgeInsets.all(S.base),
      decoration: BoxDecoration(
        color: isAdded
            ? color.withValues(alpha: 0.08)
            : AppColors.bg(d),
        borderRadius: BorderRadius.circular(S.radiusMd),
        border: Border.all(
          color: isAdded ? color.withValues(alpha: 0.3) : AppColors.border(d),
          width: isAdded ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(S.sm + 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isAdded ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(S.radiusSm),
            ),
            child: Icon(icon, color: color, size: S.iconSm + 4),
          ),
          SizedBox(width: S.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary(d),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  desc,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted(d),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: S.sm),
          GestureDetector(
            onTap: isAdded ? null : () => onAdd(name, qualifiedName),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.symmetric(
                horizontal: S.base + 2,
                vertical: S.sm,
              ),
              decoration: BoxDecoration(
                color: isAdded ? color.withValues(alpha: 0.15) : color,
                borderRadius: BorderRadius.circular(S.radiusSm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isAdded ? Icons.check_rounded : Icons.add_rounded,
                    color: isAdded ? color : Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 4),
                  Text(
                    isAdded ? 'added'.tr : 'add'.tr,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: isAdded ? color : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

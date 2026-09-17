import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/size_constants.dart';
import '../../../theme/app_theme.dart';
import '../../../data/models/class_routine_model.dart';

class ClassRoutineTile extends StatelessWidget {
  final ClassRoutineModel cr;
  final bool d;
  const ClassRoutineTile({super.key, required this.cr, required this.d});

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

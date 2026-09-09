import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/size_constants.dart';
import '../theme/app_theme.dart';

class WidgetPromoDialog extends StatefulWidget {
  const WidgetPromoDialog({super.key});
  static const _dismissedKey = 'widget_promo_dismissed';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_dismissedKey) ?? false);
  }

  static Future<void> markDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
  }

  static void showIfNeeded(BuildContext context) {
    shouldShow().then((show) {
      if (show && context.mounted) {
        showDialog(
          context: context,
          barrierColor: Colors.black45,
          builder: (_) => const WidgetPromoDialog(),
        );
      }
    });
  }

  @override
  State<WidgetPromoDialog> createState() => _WidgetPromoDialogState();
}

class _WidgetPromoDialogState extends State<WidgetPromoDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  final _added = <String, bool>{}.obs;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Cubic(0.18, 1.42, 0.22, 1),
    );
    _fadeAnim = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOut,
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    WidgetPromoDialog.markDismissed();
    Navigator.of(context).pop();
  }

  Future<void> _addWidget(String name, String qualifiedName) async {
    try {
      await HomeWidget.requestPinWidget(qualifiedAndroidName: qualifiedName);
      _added[name] = true;
    } catch (e) {
      debugPrint('[WidgetPromo] pin failed for $name: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(
                horizontal: S.xl,
                vertical: size.height * 0.08,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(S.radiusXl),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface(d).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(S.radiusXl),
                      border: Border.all(
                        color: AppColors.border(d).withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          blurRadius: 40,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(d),
                        _buildSubtitle(d),
                        _buildWidgetCards(d),
                        _buildButtons(d),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool d) => Container(
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(S.xl, S.xl, S.xl, S.md),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.primary.withValues(alpha: 0.12),
          AppColors.secondary.withValues(alpha: 0.08),
        ],
      ),
    ),
    child: Row(
      children: [
        Container(
          padding: EdgeInsets.all(S.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(S.radiusMd),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.widgets_rounded, color: Colors.white, size: S.iconMd + 4),
        ),
        SizedBox(width: S.base),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'widgetPromoTitle'.tr,
                style: AppTextStyles.headlineSmall.copyWith(
                  color: AppColors.textPrimary(d),
                ),
              ),
              SizedBox(height: S.xs),
              Text(
                'widgetPromoSubtitle'.tr,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted(d),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildSubtitle(bool d) => Padding(
    padding: EdgeInsets.fromLTRB(S.xl, S.md, S.xl, S.sm),
    child: Text(
      'widgetPromoDesc'.tr,
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textSecondary(d),
      ),
    ),
  );

  Widget _buildWidgetCards(bool d) => Padding(
    padding: EdgeInsets.symmetric(horizontal: S.xl),
    child: Column(
      children: [
        _widgetCard(
          d,
          icon: Icons.schedule_rounded,
          title: 'dailyRoutine'.tr,
          desc: 'widgetPromoDailyDesc'.tr,
          color: const Color(0xFF6C63FF),
          name: 'dailyRoutine',
          qualifiedName: 'com.example.study_revision_tracker.DailyRoutineWidget',
        ),
        SizedBox(height: S.sm),
        _widgetCard(
          d,
          icon: Icons.replay_rounded,
          title: 'classRoutine'.tr,
          desc: 'widgetPromoClassDesc'.tr,
          color: const Color(0xFF26A69A),
          name: 'classRoutine',
          qualifiedName: 'com.example.study_revision_tracker.ClassRoutineWidget',
        ),
        SizedBox(height: S.sm),
        _widgetCard(
          d,
          icon: Icons.school_rounded,
          title: 'revisionsLabel'.tr,
          desc: 'widgetPromoRevisionDesc'.tr,
          color: const Color(0xFFFF8A65),
          name: 'revision',
          qualifiedName: 'com.example.study_revision_tracker.RevisionWidget',
        ),
      ],
    ),
  );

  Widget _widgetCard(
    bool d, {
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
    required String name,
    required String qualifiedName,
  }) {
    return Obx(() {
      final isAdded = _added[name] == true;
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
              onTap: isAdded ? null : () => _addWidget(name, qualifiedName),
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
    });
  }

  Widget _buildButtons(bool d) => Padding(
    padding: EdgeInsets.fromLTRB(S.xl, S.lg, S.xl, S.xl),
    child: Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _dismiss,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: S.base),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(S.radiusMd),
              ),
            ),
            child: Text(
              'widgetPromoMaybeLater'.tr,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted(d),
              ),
            ),
          ),
        ),
        SizedBox(width: S.sm),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _dismiss,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: S.base),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(S.radiusMd),
              ),
            ),
            child: Text(
              'widgetPromoDone'.tr,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

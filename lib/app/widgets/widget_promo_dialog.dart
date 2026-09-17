import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/responsive.dart';
import '../core/constants/size_constants.dart';
import '../theme/app_theme.dart';
import 'promo/promo_cards.dart';
import 'promo/promo_chrome.dart';

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
    // Home-screen widgets are mobile-only — never show this on web/desktop.
    if (kIsWeb || Responsive.useNavRail) return;
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
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: size.height * 0.78,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            WidgetPromoHeader(d: d),
                            WidgetPromoSubtitle(d: d),
                            Obx(() => WidgetPromoCards(
                                  d: d,
                                  added: Map<String, bool>.from(_added),
                                  onAdd: _addWidget,
                                )),
                            WidgetPromoButtons(d: d, onDismiss: _dismiss),
                          ],
                        ),
                      ),
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
}

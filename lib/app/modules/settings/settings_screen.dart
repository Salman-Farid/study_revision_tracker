import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';
import 'settings_controller.dart';
import 'widgets/settings_profile.dart';
import 'widgets/settings_sheets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<SettingsController>();
    return Scaffold(
      appBar: AppBar(title: Text('navSettings'.tr, style: AppTextStyles.headlineMedium)),
      body: RefreshIndicator(
        onRefresh: c.loadStats,
        child: ListView(padding: EdgeInsets.all(S.xl), children: [
          SettingsProfileHeader(c: c),
          SizedBox(height: S.xl),
          SettingsStatsRow(c: c),
          SizedBox(height: S.xl),
          _section('preferences'.tr, [
            _tile(Icons.language_rounded, 'language'.tr, c.currentLanguageName,
                () => showLanguageSheet(c)),
            Obx(() => _tile(Icons.record_voice_over_rounded, 'voiceLanguage'.tr,
                c.voiceLanguageName, () => showVoiceLanguageSheet(c))),
            Obx(() => _tile(Icons.brightness_6_rounded, 'theme'.tr,
                themeLabel(c.themeMode.value), () => showThemeSheet(c))),
            Obx(() => Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: S.base, vertical: S.xs),
                secondary: Icon(Icons.notifications_rounded,
                    color: AppColors.textPrimary(Get.isDarkMode), size: S.iconMd),
                title: Text('notifications'.tr,
                    style: AppTextStyles.titleSmall
                        .copyWith(color: AppColors.textPrimary(Get.isDarkMode))),
                subtitle: Text('manageReminders'.tr,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textMuted(Get.isDarkMode))),
                value: c.notificationsEnabled.value,
                activeColor: AppConstants.primaryColor,
                onChanged: c.toggleNotifications),
            )),
          ]),
          SizedBox(height: S.xl),
          _section('account'.tr, [
            Obx(() => _infoTile(Icons.alternate_email_rounded, 'email'.tr,
                c.email.value.isEmpty ? 'notSignedIn'.tr : c.email.value)),
            _infoTile(Icons.info_outline_rounded, 'appVersion'.tr, AppConstants.appVersion),
            Obx(() => _tile(Icons.logout_rounded, 'signOut'.tr, 'signOutQ'.tr,
                () => confirmSignOut(c), destructive: c.isSignedIn.value)),
          ]),
          SizedBox(height: S.xxxl),
        ]),
      ),
    );
  }

  // ─── SECTIONS ─────────────────────────────────────────────────
  Widget _section(String title, List<Widget> items) {
    final d = Get.isDarkMode;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted(d), letterSpacing: 1)),
      SizedBox(height: S.sm),
      Container(decoration: BoxDecoration(color: AppColors.surface(d), borderRadius: BorderRadius.circular(S.radiusLg),
        border: Border.all(color: AppColors.border(d))), child: Column(children: items)),
    ]);
  }

  Widget _tile(IconData icon, String title, String sub, VoidCallback onTap, {bool destructive = false}) {
    final d = Get.isDarkMode;
    final color = destructive ? AppColors.error : AppColors.textPrimary(d);
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap,
      child: Padding(padding: EdgeInsets.symmetric(horizontal: S.base, vertical: S.md),
        child: Row(children: [
          Icon(icon, color: color, size: S.iconMd), SizedBox(width: S.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTextStyles.titleSmall.copyWith(color: color)),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d))),
          ])),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted(d), size: S.iconSm),
        ]))));
  }

  /// Read-only row — no chevron, no fake tap target.
  Widget _infoTile(IconData icon, String title, String sub) {
    final d = Get.isDarkMode;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: S.base, vertical: S.md),
      child: Row(children: [
        Icon(icon, color: AppColors.textMuted(d), size: S.iconMd),
        SizedBox(width: S.md),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.textPrimary(d))),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d))),
        ])),
      ]),
    );
  }
}

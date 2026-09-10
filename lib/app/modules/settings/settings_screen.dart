import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/size_constants.dart';
import '../../core/localization/language_controller.dart';
import '../../theme/app_theme.dart';
import 'settings_controller.dart';

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
          _profileHeader(c),
          SizedBox(height: S.xl),
          _statsRow(c),
          SizedBox(height: S.xl),
          _section('preferences'.tr, [
            _tile(Icons.language_rounded, 'language'.tr, c.currentLanguageName,
                () => _showLanguageSheet(c)),
            Obx(() => _tile(Icons.brightness_6_rounded, 'theme'.tr,
                _themeLabel(c.themeMode.value), () => _showThemeSheet(c))),
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
            _tile(Icons.calendar_month_rounded, 'calendarIntegration'.tr,
                'deviceIntegration'.tr, () {}),
          ]),
          SizedBox(height: S.xl),
          _section('account'.tr, [
            Obx(() => _tile(Icons.alternate_email_rounded, 'email'.tr, c.email.value.isEmpty
                ? 'notSignedIn'.tr : c.email.value, () {})),
            _tile(Icons.info_outline_rounded, 'appVersion'.tr, AppConstants.appVersion, () {}),
            Obx(() => _tile(Icons.logout_rounded, 'signOut'.tr, 'signOutQ'.tr,
                () => _confirmSignOut(c), destructive: c.isSignedIn.value)),
          ]),
          SizedBox(height: S.xxxl),
        ]),
      ),
    );
  }

  // ─── PROFILE HEADER ───────────────────────────────────────────
  Widget _profileHeader(SettingsController c) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(S.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF9D97FF)]),
        borderRadius: BorderRadius.circular(S.radiusLg),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3),
          blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        // Avatar with initial
        Obx(() => Container(
          width: S.avatarSize * 1.6,
          height: S.avatarSize * 1.6,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white70, width: 2)),
          child: Text(c.avatarInitial,
            style: AppTextStyles.headlineLarge.copyWith(
              color: Colors.white, fontWeight: FontWeight.w900,
              fontSize: S.iconLg)))),
        SizedBox(width: S.base),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Obx(() => Text(
            c.displayName.value.isEmpty ? 'guestUser'.tr : c.displayName.value,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleLarge.copyWith(
              color: Colors.white, fontWeight: FontWeight.w800))),
          SizedBox(height: S.xs),
          Obx(() => Text(
            c.email.value.isEmpty ? 'notSignedIn'.tr : c.email.value,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(color: Colors.white70))),
          SizedBox(height: S.xs),
          Obx(() => Text(
            '${'memberSince'.tr} ${c.formatMemberSince()}',
            style: AppTextStyles.labelSmall.copyWith(color: Colors.white70))),
        ])),
      ]),
    );
  }

  // ─── REAL STUDY STATS ─────────────────────────────────────────
  Widget _statsRow(SettingsController c) {
    return Row(children: [
      Expanded(child: Obx(() => _miniStat('navSubjects'.tr, '${c.subjectCount.value}',
          Icons.menu_book_rounded, AppColors.primary))),
      SizedBox(width: S.md),
      Expanded(child: Obx(() => _miniStat('navToday'.tr, '${c.topicCount.value}',
          Icons.topic_rounded, AppColors.info))),
      SizedBox(width: S.md),
      Expanded(child: Obx(() => _miniStat('revisionsDone'.tr,
          '${c.revisionsDone.value}/${c.revisionsPlanned.value}',
          Icons.done_all_rounded, AppColors.success))),
    ]);
  }

  Widget _miniStat(String label, String value, IconData icon, Color color) {
    final d = Get.isDarkMode;
    return Container(
      padding: EdgeInsets.all(S.md),
      decoration: BoxDecoration(
        color: AppColors.surface(d),
        borderRadius: BorderRadius.circular(S.radiusLg),
        border: Border.all(color: AppColors.border(d)),
        boxShadow: S.shadowSm),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: S.iconMd),
        SizedBox(height: S.sm),
        FittedBox(fit: BoxFit.scaleDown,
          child: Text(value, maxLines: 1, style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.textPrimary(d), fontWeight: FontWeight.w800))),
        SizedBox(height: S.xs),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted(d))),
      ]),
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

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return 'themeLight'.tr;
      case ThemeMode.dark: return 'themeDark'.tr;
      case ThemeMode.system: return 'themeSystem'.tr;
    }
  }

  // ─── LANGUAGE SHEET (24 languages) ────────────────────────────
  void _showLanguageSheet(SettingsController c) {
    final lang = Get.find<LanguageController>();
    showModalBottomSheet(
      context: Get.context!,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: Get.height * 0.75),
        padding: EdgeInsets.all(S.xl),
        decoration: BoxDecoration(color: AppColors.surface(Get.isDarkMode),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('chooseLanguage'.tr, style: AppTextStyles.headlineSmall),
          SizedBox(height: S.base),
          Flexible(child: ListView.builder(
            shrinkWrap: true,
            itemCount: AppLanguages.all.length,
            itemBuilder: (_, i) {
              final code = AppLanguages.all.keys.elementAt(i);
              final name = AppLanguages.all.values.elementAt(i);
              return Obx(() {
                final selected = lang.locale.value.languageCode == code;
                return Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    dense: true,
                    leading: Icon(selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                      color: selected ? AppConstants.primaryColor : AppColors.textMuted(Get.isDarkMode)),
                    title: Text(name, style: AppTextStyles.titleSmall.copyWith(
                      color: AppColors.textPrimary(Get.isDarkMode),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                    onTap: () {
                      c.changeLanguage(code);
                      Get.back();
                      Get.snackbar('language'.tr, 'languageChanged'.tr,
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: AppColors.success.withOpacity(0.15));
                    },
                  ),
                );
              });
            })),
          SizedBox(height: S.base),
        ]),
      ),
    );
  }

  // ─── THEME SHEET ──────────────────────────────────────────────
  void _showThemeSheet(SettingsController c) {
    showModalBottomSheet(
      context: Get.context!,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.all(S.xl),
        decoration: BoxDecoration(color: AppColors.surface(Get.isDarkMode),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('theme'.tr, style: AppTextStyles.headlineSmall),
          SizedBox(height: S.sm),
          Material(
            type: MaterialType.transparency,
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.brightness_auto_rounded),
                title: Text('themeSystem'.tr),
                onTap: () { c.changeThemeMode(ThemeMode.system); Get.back(); }),
              ListTile(
                leading: const Icon(Icons.light_mode_rounded),
                title: Text('themeLight'.tr),
                onTap: () { c.changeThemeMode(ThemeMode.light); Get.back(); }),
              ListTile(
                leading: const Icon(Icons.dark_mode_rounded),
                title: Text('themeDark'.tr),
                onTap: () { c.changeThemeMode(ThemeMode.dark); Get.back(); }),
            ]),
          ),
          SizedBox(height: S.base),
        ]),
      ),
    );
  }

  // ─── SIGN OUT CONFIRM ─────────────────────────────────────────
  void _confirmSignOut(SettingsController c) {
    Get.defaultDialog(
      title: 'signOut'.tr,
      middleText: 'signOutQ'.tr,
      textConfirm: 'signOut'.tr,
      textCancel: 'cancel'.tr,
      confirmTextColor: Colors.white,
      buttonColor: AppColors.error,
      onConfirm: () {
        Get.back();
        c.signOut();
      },
    );
  }
}


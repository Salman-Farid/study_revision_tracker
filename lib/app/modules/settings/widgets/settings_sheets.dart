import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/size_constants.dart';
import '../../../core/localization/language_controller.dart';
import '../../../theme/app_theme.dart';
import '../settings_controller.dart';

String themeLabel(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light: return 'themeLight'.tr;
    case ThemeMode.dark: return 'themeDark'.tr;
    case ThemeMode.system: return 'themeSystem'.tr;
  }
}

// ─── LANGUAGE SHEET (24 languages) ────────────────────────────
void showLanguageSheet(SettingsController c) {
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

// ─── VOICE LANGUAGE SHEET (assistant reply language) ──────────
void showVoiceLanguageSheet(SettingsController c) {
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
        Text('chooseVoiceLanguage'.tr, style: AppTextStyles.headlineSmall),
        SizedBox(height: S.base),
        Flexible(child: ListView(
          shrinkWrap: true,
          children: [
            Obx(() {
              final selected = c.voiceLanguageCode.value == 'auto';
              return Material(
                type: MaterialType.transparency,
                child: ListTile(
                  dense: true,
                  leading: Icon(selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                    color: selected ? AppConstants.primaryColor : AppColors.textMuted(Get.isDarkMode)),
                  title: Text('voiceLanguageAuto'.tr, style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimary(Get.isDarkMode),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                  subtitle: Text('voiceLanguageAutoHint'.tr,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(Get.isDarkMode))),
                  onTap: () {
                    c.changeVoiceLanguage('auto');
                    Get.back();
                  },
                ),
              );
            }),
            ...AppLanguages.all.entries.map((e) {
              final code = e.key;
              final name = e.value;
              return Obx(() {
                final selected = c.voiceLanguageCode.value == code;
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
                      c.changeVoiceLanguage(code);
                      Get.back();
                    },
                  ),
                );
              });
            }),
          ],
        )),
        SizedBox(height: S.base),
      ]),
    ),
  );
}

// ─── THEME SHEET ──────────────────────────────────────────────
void showThemeSheet(SettingsController c) {
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
void confirmSignOut(SettingsController c) {
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

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported app languages (code → native display name).
/// 24 languages: English, Bengali, Hindi + 21 more.
class AppLanguages {
  AppLanguages._();

  static const Map<String, String> all = {
    'en': 'English',
    'bn': 'বাংলা (Bengali)',
    'hi': 'हिन्दी (Hindi)',
    'ur': 'اردو (Urdu)',
    'ar': 'العربية (Arabic)',
    'fa': 'فارسی (Persian)',
    'es': 'Español (Spanish)',
    'fr': 'Français (French)',
    'de': 'Deutsch (German)',
    'pt': 'Português (Portuguese)',
    'ru': 'Русский (Russian)',
    'zh': '中文 (Chinese)',
    'ja': '日本語 (Japanese)',
    'ko': '한국어 (Korean)',
    'tr': 'Türkçe (Turkish)',
    'id': 'Bahasa Indonesia',
    'vi': 'Tiếng Việt (Vietnamese)',
    'th': 'ไทย (Thai)',
    'ta': 'தமிழ் (Tamil)',
    'te': 'తెలుగు (Telugu)',
    'ml': 'മലയാളം (Malayalam)',
    'kn': 'ಕನ್ನಡ (Kannada)',
    'mr': 'मराठी (Marathi)',
    'gu': 'ગુજરાતી (Gujarati)',
  };

  /// Languages written right-to-left.
  static const List<String> rtl = ['ar', 'ur', 'fa'];

  static bool isRtl(String code) => rtl.contains(code.split('_').first);
}

/// Loads the persisted language at startup and switches it at runtime.
/// Registered permanently in main() so any screen can read/observe it.
class LanguageController extends GetxService {
  final locale = const Locale('en').obs;

  static const _prefsKey = 'app_language';

  @override
  void onInit() {
    super.onInit();
    _restore();
  }

  void _restore() {
    SharedPreferences.getInstance().then((p) {
      final stored = p.getString(_prefsKey);
      if (stored != null && AppLanguages.all.containsKey(stored)) {
        locale.value = Locale(stored);
      }
      Get.updateLocale(locale.value);
    });
  }

  /// Change the app language and persist the choice.
  Future<void> changeLanguage(String code) async {
    if (!AppLanguages.all.containsKey(code)) return;
    locale.value = Locale(code);
    Get.updateLocale(locale.value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, code);
    } catch (_) {}
  }

  String get currentCode => locale.value.languageCode;
  String get currentName => AppLanguages.all[currentCode] ?? 'English';
}

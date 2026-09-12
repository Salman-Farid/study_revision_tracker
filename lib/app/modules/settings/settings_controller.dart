import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/notification_service.dart';
import '../../data/repositories/subject_repository.dart';
import '../../data/repositories/topic_repository.dart';
import '../../core/localization/language_controller.dart';
import '../../routes/app_routes.dart';

/// Drives the Profile/Settings screen: real account info, live study stats,
/// language + theme preferences (persisted) and sign-out.
class SettingsController extends GetxController {
  final _subjectRepo = Get.find<SubjectRepository>();
  final _topicRepo = Get.find<TopicRepository>();

  // ── Account ──
  final email = ''.obs;
  final displayName = ''.obs;
  final memberSince = DateTime.now().obs;
  final isSignedIn = false.obs;

  // ── Real study stats ──
  final subjectCount = 0.obs;
  final topicCount = 0.obs;
  final revisionsDone = 0.obs;
  final revisionsPlanned = 0.obs;

  // ── Preferences ──
  final notificationsEnabled = true.obs;
  LanguageController get _lang => Get.find<LanguageController>();

  static const _themeKey = 'theme_mode';
  static const _notifKey = 'notifications_enabled';
  final themeMode = ThemeMode.system.obs;

  @override
  void onInit() {
    super.onInit();
    refreshAccount();
    loadStats();
    _restorePrefs();
    // Keep profile in sync if the session changes later (login / refresh).
    try {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        refreshAccount();
        loadStats();
      });
    } catch (_) {}
  }

  @override
  void onClose() {
    _authSub?.cancel();
    super.onClose();
  }

  /// Re-read the Supabase session into UI state.
  /// Called on init, after sign-in, and on every auth event.
  void refreshAccount() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      isSignedIn.value = user != null;
      if (user == null) {
        email.value = '';
        displayName.value = '';
        return;
      }
      email.value = user.email ?? user.phone ?? '';
      final meta = user.userMetadata;
      final metaName = meta?['full_name'] ?? meta?['name'] ?? meta?['display_name'];
      displayName.value =
          (metaName is String && metaName.isNotEmpty) ? metaName : email.value.split('@').first;
      memberSince.value = DateTime.tryParse(user.createdAt) ?? DateTime.now();
    } catch (_) {
      // Keep previous values if auth isn't ready yet.
    }
  }

  StreamSubscription<AuthState>? _authSub;

  Future<void> loadStats() async {
    try {
      final subjects = await _subjectRepo.getAll();
      subjectCount.value = subjects.length;
      int done = 0, planned = 0, totalTopics = 0;
      await Future.wait(subjects.map((s) async {
        try {
          final topics = await _topicRepo.getBySubject(s.id)
              .timeout(const Duration(seconds: 5));
          totalTopics += topics.length;
          done += topics.fold<int>(0, (sum, t) => sum + t.totalRevisions.clamp(0, 6));
          planned += topics.length * 6;
        } catch (_) {}
      }));
      topicCount.value = totalTopics;
      revisionsDone.value = done;
      revisionsPlanned.value = planned;
    } catch (_) {}
  }

  void _restorePrefs() {
    SharedPreferences.getInstance().then((p) {
      final t = p.getString(_themeKey);
      if (t == 'light') themeMode.value = ThemeMode.light;
      if (t == 'dark') themeMode.value = ThemeMode.dark;
      if (t == 'system') themeMode.value = ThemeMode.system;
      notificationsEnabled.value = p.getBool(_notifKey) ?? true;
    });
  }

  // ── Language ──
  String get currentLanguageCode => _lang.currentCode;
  String get currentLanguageName => _lang.currentName;

  Future<void> changeLanguage(String code) async {
    await _lang.changeLanguage(code);
  }

  // ── Theme ──
  Future<void> changeThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    Get.changeThemeMode(mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode.name);
    } catch (_) {}
  }

  // ── Notifications ──
  Future<void> toggleNotifications(bool value) async {
    notificationsEnabled.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notifKey, value);
    } catch (_) {}
    // Reschedule or cancel all notifications
    try {
      final notif = Get.find<NotificationService>();
      if (value) {
        notif.rescheduleAll();
      } else {
        notif.cancelAll();
      }
    } catch (_) {}
  }

  // ── Sign out ──
  Future<void> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      email.value = '';
      displayName.value = '';
      isSignedIn.value = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('logged_in', false);
      await prefs.remove('user_email');
      Get.offAllNamed(AppRoutes.auth);
    } catch (_) {}
  }

  /// Initial letter for the avatar.
  String get avatarInitial {
    final name = displayName.value;
    return name.isNotEmpty ? name.characters.first.toUpperCase() : 'S';
  }

  String formatMemberSince() {
    final m = memberSince.value;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[m.month - 1]} ${m.year}';
  }
}

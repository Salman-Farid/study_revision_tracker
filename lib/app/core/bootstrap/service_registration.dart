import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:study_revision_tracker/gemini_3_flash_live_voice_chatbot/gemini_chatbot.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../localization/language_controller.dart';
import '../services/connectivity_service.dart';
import '../services/notification_service.dart';
import '../services/password_recovery_service.dart';
import '../../data/repositories/revision_repository.dart';
import '../../data/repositories/subject_repository.dart';
import '../../data/repositories/topic_repository.dart';
import '../../data/repositories/routine_repository.dart';
import '../../data/services/supabase_service.dart';
import '../../modules/settings/settings_controller.dart';

/// Supabase + recovery-service bring-up. Must run before any auth UI.
/// [launchUri] is captured before [Supabase.initialize] rewrites the URL.
Future<void> initSupabaseAndRecovery(Uri launchUri) async {
  // Supabase persists the session in secure storage (mobile) or
  // localStorage (web). initialize() restores it before we read currentUser.
  // detectSessionInUri (default true) completes PKCE for recovery/OAuth links.
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      // We exchange the recovery `code` once in PasswordRecoveryService.
      // Auto-detect + our exchange double-burns the one-time PKCE code.
      detectSessionInUri: false,
    ),
  );

  Get.put(PasswordRecoveryService(launchUri: launchUri), permanent: true);
  Get.put(SupabaseService(), permanent: true);

  // Finish PKCE before first frame so AuthScreen can show the set-password
  // form as soon as recovery=1 is on the URL.
  await Get.find<PasswordRecoveryService>().completeFromLaunchUri(launchUri);
}

/// Repositories, controllers, and long-lived services.
void registerAppServices() {
  Get.put(SubjectRepository(), permanent: true);
  Get.put(TopicRepository(), permanent: true);
  Get.put(RevisionRepository(), permanent: true);
  Get.put(RoutineRepository(), permanent: true);
  Get.put(ConnectivityService(), permanent: true);
  // Heavy chatbot services — create only when first used (mic / voice UI).
  Get.lazyPut<GeminiLiveService>(() => GeminiLiveService(), fenix: true);
  Get.lazyPut<VoiceAssistantController>(() => VoiceAssistantController(), fenix: true);
  Get.put(LanguageController(), permanent: true);
  Get.put(SettingsController(), permanent: true);
}

/// Local notifications are mobile-only; on web this is a no-op service.
Future<void> initNotificationService() async {
  try {
    await Get.putAsync<NotificationService>(
      () => NotificationService().init(),
    ).timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('[main] NotificationService init failed/slow: $e');
    Get.put(NotificationService(), permanent: true);
  }
}

/// Warm the realtime channel when a session already exists.
void initRealtimeIfLoggedIn() {
  if (Get.find<SupabaseService>().currentUser != null) {
    Get.find<SupabaseService>().initRealtime();
  }
}

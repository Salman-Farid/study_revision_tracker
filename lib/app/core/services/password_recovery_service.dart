import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'web_history_stub.dart'
    if (dart.library.js_interop) 'web_history_web.dart';

import '../../data/services/supabase_service.dart';
import '../../modules/settings/settings_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

part 'password_recovery/detection.dart';
part 'password_recovery/session_establish.dart';
part 'password_recovery/update_password.dart';

/// App-wide password-recovery handler.
///
/// Registered permanently in [main] so a recovery link works even when
/// AuthController is not on screen (cold start → Home, or Home already open).
class PasswordRecoveryService extends GetxService {
  PasswordRecoveryService({Uri? launchUri}) : _launchUri = launchUri;

  /// Captured before [Supabase.initialize] — PKCE exchange can rewrite the URL.
  final Uri? _launchUri;

  final isRecovery = false.obs;
  final isLoading = false.obs;
  /// Last PKCE / recovery error (shown on the set-password form).
  final recoveryError = RxnString();

  bool _promptShown = false;
  bool _seeded = false;
  bool _exchangeAttempted = false;
  StreamSubscription<AuthState>? _sub;

  /// Redirect target written into reset emails (must be allow-listed in
  /// Supabase → Authentication → URL Configuration → Redirect URLs).
  static const String mobileCallback = 'study-revision-tracker://recovery';

  static String webRedirect() {
    final origin = Uri.base.origin;
    // PathUrlStrategy — no hash. recovery=1 survives as a launch marker.
    return '$origin/auth?recovery=1';
  }

  static String redirectForPlatform() =>
      kIsWeb ? webRedirect() : mobileCallback;

  /// Strip recovery/auth query + fragment from the address bar (web only).
  static void clearAuthQueryFromUrl() {
    if (!kIsWeb) return;
    try {
      final path = Uri.base.path.isEmpty ? '/auth' : Uri.base.path;
      replaceHistoryUrl(path);
    } catch (_) {}
  }

  /// True when [uri] is a password-recovery callback.
  static bool looksLikeRecoveryUri(Uri? uri) {
    if (uri == null) return false;
    final qp = uri.queryParameters;
    final frag = uri.fragment;
    if (qp['recovery'] == '1' || qp['type'] == 'recovery') return true;
    if (frag.contains('recovery=1') ||
        frag.contains('type=recovery') ||
        frag.contains('access_token=')) {
      return true;
    }
    if (uri.scheme == 'study-revision-tracker' &&
        (uri.host == 'recovery' || uri.path.contains('recovery'))) {
      return true;
    }
    return false;
  }

  @override
  void onInit() {
    super.onInit();
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        isRecovery.value = true;
        _promptShown = false;
        scheduleMicrotask(maybePromptNewPassword);
        return;
      }
      // PKCE exchange may emit signedIn instead of passwordRecovery when the
      // verifier's event name was lost — still prompt if this launch is recovery.
      if (state.event == AuthChangeEvent.signedIn && isRecovery.value) {
        _promptShown = false;
        scheduleMicrotask(maybePromptNewPassword);
      }
    });
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  /// Called after Sign Out so recovery UI cannot stick around.
  void resetAfterSignOut() {
    isRecovery.value = false;
    recoveryError.value = null;
    _promptShown = false;
    // Keep _exchangeAttempted true so a leftover URL cannot retrigger recovery.
    clearAuthQueryFromUrl();
  }
}

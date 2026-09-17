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

  /// Re-read the browser URL (web). Safe to call from AuthScreen.build.
  ///
  /// A leftover `?code=…&recovery=1` in the address bar after sign-out must
  /// NOT re-enter recovery UI — that code is already burned.
  void syncFromCurrentUri() {
    final looks =
        looksLikeRecoveryUri(_launchUri) || looksLikeRecoveryUri(Uri.base);
    if (!looks) return;

    if (_exchangeAttempted && !hasSession) {
      // Stale recovery URL (e.g. after sign-out). Leave normal Sign In.
      isRecovery.value = false;
      clearAuthQueryFromUrl();
      return;
    }
    isRecovery.value = true;
  }

  /// Strip recovery/auth query + fragment from the address bar (web only).
  static void clearAuthQueryFromUrl() {
    if (!kIsWeb) return;
    try {
      final path = Uri.base.path.isEmpty ? '/auth' : Uri.base.path;
      replaceHistoryUrl(path);
    } catch (_) {}
  }

  /// Called after Sign Out so recovery UI cannot stick around.
  void resetAfterSignOut() {
    isRecovery.value = false;
    recoveryError.value = null;
    _promptShown = false;
    // Keep _exchangeAttempted true so a leftover URL cannot retrigger recovery.
    clearAuthQueryFromUrl();
  }

  /// Finish recovery for a cold-start link: flag the launch, establish session.
  /// Call from [main] after [Supabase.initialize].
  Future<void> completeFromLaunchUri(Uri launchUri) async {
    if (looksLikeRecoveryUri(launchUri) || looksLikeRecoveryUri(Uri.base)) {
      isRecovery.value = true;
    }
    _seeded = true;
    if (!isRecovery.value) return;
    await _establishRecoverySession(launchUri);
    // Never leave ?code=&recovery=1 in the bar — sign-out / reload would
    // reprocess a dead link and show "token expired".
    clearAuthQueryFromUrl();
  }

  /// Read session from the recovery redirect URL.
  ///
  /// Prefers implicit `access_token` in the fragment (no code_verifier).
  /// Falls back to PKCE `code` only if a verifier is still in storage.
  Future<void> _establishRecoverySession(Uri launchUri) async {
    if (_exchangeAttempted) return;
    _exchangeAttempted = true;

    final auth = Supabase.instance.client.auth;
    if (auth.currentSession != null) return;

    final candidates = <Uri?>[
      launchUri,
      Uri.base,
    ];

    for (final uri in candidates) {
      if (uri == null) continue;
      final hasTokens = uri.fragment.contains('access_token') ||
          uri.queryParameters.containsKey('access_token');
      final hasCode = uri.queryParameters.containsKey('code');
      if (!hasTokens && !hasCode) continue;

      try {
        await auth.getSessionFromUrl(uri);
        recoveryError.value = null;
        return;
      } on AuthException catch (e) {
        debugPrint('[PasswordRecovery] getSessionFromUrl: ${e.message}');
        // PKCE path without verifier → try nothing else for this URI.
        if (e.message.toLowerCase().contains('code verifier')) {
          recoveryError.value = e.message;
          continue;
        }
        recoveryError.value = e.message;
      } catch (e) {
        debugPrint('[PasswordRecovery] getSessionFromUrl: $e');
        recoveryError.value = e.toString();
      }

      // Last resort: PKCE exchange if code present.
      final code = uri.queryParameters['code'];
      if (code != null) {
        try {
          await auth.exchangeCodeForSession(code);
          recoveryError.value = null;
          return;
        } catch (e) {
          debugPrint('[PasswordRecovery] exchangeCodeForSession: $e');
          recoveryError.value = e.toString();
        }
      }
    }

    if (auth.currentSession == null &&
        (recoveryError.value == null || recoveryError.value!.isEmpty)) {
      recoveryError.value =
          'Could not open a recovery session. Request a new reset email.';
    }
  }

  /// Detect recovery from the launch URI (web snapshot) and mobile deep link.
  Future<void> detectInitialRecoveryLink() async {
    if (_seeded) return;
    _seeded = true;

    if (looksLikeRecoveryUri(_launchUri) || looksLikeRecoveryUri(Uri.base)) {
      isRecovery.value = true;
      return;
    }
    if (!kIsWeb) {
      try {
        final uri = await AppLinks().getInitialLink();
        if (looksLikeRecoveryUri(uri)) {
          isRecovery.value = true;
        }
      } catch (_) {
        // AppLinks unavailable — event listener still covers warm recovery.
      }
    }
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

  bool get hasSession => Supabase.instance.client.auth.currentSession != null;

  /// Wait for PKCE session (or fail after a short poll). Used by AuthScreen.
  Future<bool> ensureSessionForRecovery() async {
    syncFromCurrentUri();
    if (hasSession) return true;
    await completeFromLaunchUri(_launchUri ?? Uri.base);
    if (hasSession) return true;
    // exchange may still be in flight if completeFromLaunchUri was skipped
    for (var i = 0; i < 15; i++) {
      if (hasSession) return true;
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    debugPrint(
        '[PasswordRecovery] no session. error=${recoveryError.value}');
    return hasSession;
  }

  /// Show the set-new-password dialog when a recovery session is active.
  /// Prefer the inline AuthScreen form; dialog is a backup path.
  Future<void> maybePromptNewPassword() async {
    if (!isRecovery.value || _promptShown) return;
    if (Get.isDialogOpen ?? false) return;

    final ok = await ensureSessionForRecovery();
    if (!ok) return;
    if (_promptShown || !isRecovery.value) return;
    if (Get.isDialogOpen ?? false) return;

    _promptShown = true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!isRecovery.value) return;
    // Inline form on AuthScreen is the primary UI — only dialog if somehow
    // we're not on that screen.
    if (Get.currentRoute == AppRoutes.auth) return;
    await showSetNewPasswordDialog();
  }

  Future<void> showSetNewPasswordDialog() async {
    await Get.dialog(
      SetNewPasswordDialog(
        isLoading: () => isLoading.value,
        isRecovery: () => isRecovery.value,
        onSubmit: (pw) => updatePassword(pw),
      ),
      barrierDismissible: false,
    );
  }

  Future<bool> updatePassword(String newPassword) async {
    isLoading.value = true;
    try {
      if (!hasSession) {
        final ready = await ensureSessionForRecovery();
        if (!ready) {
          Get.snackbar('error'.tr,
              'Reset link expired or already used. Request a new one.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppColors.error,
              colorText: Colors.white,
              duration: const Duration(seconds: 5));
          return false;
        }
      }

      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: newPassword));
      isRecovery.value = false;
      _promptShown = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('logged_in', true);
      final email = Supabase.instance.client.auth.currentUser?.email;
      if (email != null && email.isNotEmpty) {
        await prefs.setString('user_email', email);
      }

      try {
        Get.find<SupabaseService>().initRealtime();
      } catch (_) {}
      try {
        Get.find<SettingsController>().refreshAccount();
        Get.find<SettingsController>().loadStats();
      } catch (_) {}

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      Get.snackbar('info'.tr, 'passwordUpdated'.tr,
          snackPosition: SnackPosition.BOTTOM);
      Get.offAllNamed(AppRoutes.home);
      return true;
    } on AuthException catch (e) {
      Get.snackbar('error'.tr, e.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: Colors.white,
          duration: const Duration(seconds: 5));
      return false;
    } catch (e) {
      Get.snackbar('error'.tr, e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: Colors.white);
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}

/// Owns its [TextEditingController] so dispose runs after unmount.
class SetNewPasswordDialog extends StatefulWidget {
  const SetNewPasswordDialog({
    super.key,
    required this.isLoading,
    required this.isRecovery,
    required this.onSubmit,
  });

  final bool Function() isLoading;
  final bool Function() isRecovery;
  final Future<void> Function(String password) onSubmit;

  @override
  State<SetNewPasswordDialog> createState() => _SetNewPasswordDialogState();
}

class _SetNewPasswordDialogState extends State<SetNewPasswordDialog> {
  late final TextEditingController _ctrl;
  final _key = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_key.currentState?.validate() ?? false)) return;
    final pw = _ctrl.text;
    await widget.onSubmit(pw);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !widget.isRecovery()) Get.back();
      },
      child: AlertDialog(
        title: Text('setNewPassword'.tr),
        content: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'setNewPasswordBody'.tr,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ctrl,
                autofocus: true,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'newPassword'.tr,
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'required'.tr;
                  if (v.length < 6) return 'minChars'.tr;
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: widget.isLoading() ? null : _submit,
            child: widget.isLoading()
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('save'.tr),
          ),
        ],
      ),
    );
  }
}

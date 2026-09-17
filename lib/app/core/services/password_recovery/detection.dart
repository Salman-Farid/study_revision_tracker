part of '../password_recovery_service.dart';

/// Recovery-link detection from launch URI, browser URL, and deep links.
extension PasswordRecoveryDetection on PasswordRecoveryService {
  /// Re-read the browser URL (web). Safe to call from AuthScreen.build.
  ///
  /// A leftover `?code=…&recovery=1` in the address bar after sign-out must
  /// NOT re-enter recovery UI — that code is already burned.
  void syncFromCurrentUri() {
    final looks = PasswordRecoveryService.looksLikeRecoveryUri(_launchUri) ||
        PasswordRecoveryService.looksLikeRecoveryUri(Uri.base);
    if (!looks) return;

    if (_exchangeAttempted && !hasSession) {
      // Stale recovery URL (e.g. after sign-out). Leave normal Sign In.
      isRecovery.value = false;
      PasswordRecoveryService.clearAuthQueryFromUrl();
      return;
    }
    isRecovery.value = true;
  }

  /// Detect recovery from the launch URI (web snapshot) and mobile deep link.
  Future<void> detectInitialRecoveryLink() async {
    if (_seeded) return;
    _seeded = true;

    if (PasswordRecoveryService.looksLikeRecoveryUri(_launchUri) ||
        PasswordRecoveryService.looksLikeRecoveryUri(Uri.base)) {
      isRecovery.value = true;
      return;
    }
    if (!kIsWeb) {
      try {
        final uri = await AppLinks().getInitialLink();
        if (PasswordRecoveryService.looksLikeRecoveryUri(uri)) {
          isRecovery.value = true;
        }
      } catch (_) {
        // AppLinks unavailable — event listener still covers warm recovery.
      }
    }
  }
}

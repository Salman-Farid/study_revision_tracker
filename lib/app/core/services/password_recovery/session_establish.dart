part of '../password_recovery_service.dart';

/// Session establishment from recovery redirect URLs (implicit / PKCE).
extension PasswordRecoverySession on PasswordRecoveryService {
  bool get hasSession => Supabase.instance.client.auth.currentSession != null;

  /// Finish recovery for a cold-start link: flag the launch, establish session.
  /// Call from [main] after [Supabase.initialize].
  Future<void> completeFromLaunchUri(Uri launchUri) async {
    if (PasswordRecoveryService.looksLikeRecoveryUri(launchUri) ||
        PasswordRecoveryService.looksLikeRecoveryUri(Uri.base)) {
      isRecovery.value = true;
    }
    _seeded = true;
    if (!isRecovery.value) return;
    await _establishRecoverySession(launchUri);
    // Never leave ?code=&recovery=1 in the bar — sign-out / reload would
    // reprocess a dead link and show "token expired".
    PasswordRecoveryService.clearAuthQueryFromUrl();
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
}

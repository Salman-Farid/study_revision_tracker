import 'package:flutter_test/flutter_test.dart';
import 'package:study_revision_tracker/app/core/services/password_recovery_service.dart';

void main() {
  group('PasswordRecoveryService.redirect', () {
    test('mobile callback uses custom scheme host recovery', () {
      expect(
        PasswordRecoveryService.mobileCallback,
        'study-revision-tracker://recovery',
      );
      expect(
        PasswordRecoveryService.redirectForPlatform(),
        PasswordRecoveryService.mobileCallback,
      );
    });
  });

  group('PasswordRecoveryService.looksLikeRecoveryUri', () {
    test('detects web PKCE recovery marker', () {
      expect(
        PasswordRecoveryService.looksLikeRecoveryUri(
          Uri.parse('https://app.example/auth?recovery=1&code=abc'),
        ),
        isTrue,
      );
    });

    test('detects legacy type=recovery in query and fragment', () {
      expect(
        PasswordRecoveryService.looksLikeRecoveryUri(
          Uri.parse('https://app.example/auth?type=recovery'),
        ),
        isTrue,
      );
      expect(
        PasswordRecoveryService.looksLikeRecoveryUri(
          Uri.parse('https://app.example/auth#type=recovery'),
        ),
        isTrue,
      );
    });

    test('detects mobile deep link', () {
      expect(
        PasswordRecoveryService.looksLikeRecoveryUri(
          Uri.parse('study-revision-tracker://recovery?code=xyz'),
        ),
        isTrue,
      );
    });

    test('ignores normal login and Google OAuth code', () {
      expect(
        PasswordRecoveryService.looksLikeRecoveryUri(
          Uri.parse('https://app.example/auth'),
        ),
        isFalse,
      );
      expect(
        PasswordRecoveryService.looksLikeRecoveryUri(
          Uri.parse('https://app.example/auth?code=oauth-only'),
        ),
        isFalse,
      );
      expect(PasswordRecoveryService.looksLikeRecoveryUri(null), isFalse);
    });
  });
}

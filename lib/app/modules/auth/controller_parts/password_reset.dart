part of '../auth_controller.dart';

/// Password-reset email send and forgot-password dialog launch.
extension AuthPasswordReset on AuthController {
  /// Send a password-reset email via Supabase.
  Future<void> sendPasswordReset(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      Get.snackbar('error'.tr, 'invalid'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: Colors.white);
      return;
    }
    isLoading.value = true;
    try {
      final redirectTo = PasswordRecoveryService.redirectForPlatform();
      // Call /recover WITHOUT a PKCE code_challenge. The Flutter web client
      // loses the code_verifier across reloads/ports, so PKCE recovery always
      // fails with "code verifier could not be found". Implicit flow returns
      // access_token on the redirect URL, which getSessionFromUrl can read.
      final res = await http.post(
        Uri.parse(
            '${AppConstants.supabaseUrl}/auth/v1/recover?redirect_to=${Uri.encodeComponent(redirectTo)}'),
        headers: {
          'apikey': AppConstants.supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': trimmed}),
      );
      if (res.statusCode >= 400) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }
      Get.snackbar('info'.tr, 'resetEmailSent'.tr,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5));
    } catch (e) {
      Get.snackbar('error'.tr, '${'resetEmailFailed'.tr}: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  /// Dialog used from the Sign In form.
  /// Controller lives in [ForgotPasswordDialog] state so it is not disposed
  /// while the route is still tearing down (GetX offAllNamed race).
  Future<void> showForgotPasswordDialog() async {
    await Get.dialog(
      ForgotPasswordDialog(
        initialEmail: emailCtrl.text.trim(),
        isLoading: () => isLoading.value,
        onSubmit: sendPasswordReset,
      ),
    );
  }
}

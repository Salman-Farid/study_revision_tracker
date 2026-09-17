import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/password_recovery_service.dart';
import '../../data/services/supabase_service.dart';
import '../../modules/settings/settings_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

class AuthController extends GetxController {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final isLogin = true.obs;
  final isLoading = false.obs;
  final isGoogleLoading = false.obs;

  @override
  void onClose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.onClose();
  }

  void toggleMode() => isLogin.value = !isLogin.value;

  /// Recovery is handled app-wide by [PasswordRecoveryService].
  void maybePromptNewPassword() {
    try {
      Get.find<PasswordRecoveryService>().maybePromptNewPassword();
    } catch (_) {}
  }

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

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    isLoading.value = true;
    try {
      final s = Supabase.instance.client;
      if (isLogin.value) {
        await s.auth.signInWithPassword(
            email: emailCtrl.text.trim(), password: passCtrl.text);
      } else {
        final res = await s.auth.signUp(
            email: emailCtrl.text.trim(), password: passCtrl.text);
        if (res.user != null && res.session == null) {
          Get.snackbar('info'.tr, 'accountCreated'.tr,
              snackPosition: SnackPosition.BOTTOM);
          isLogin.value = true;
          return;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('logged_in', true);
      await prefs.setString('user_email', emailCtrl.text.trim());
      Get.find<SupabaseService>().initRealtime();
      try {
        Get.find<SettingsController>().refreshAccount();
        Get.find<SettingsController>().loadStats();
      } catch (_) {}
      Get.offAllNamed(AppRoutes.home);
    } on AuthException catch (e) {
      String msg = e.message;
      if (msg.toLowerCase().contains('email not confirmed')) {
        msg = 'emailNotConfirmed'.tr;
      }
      if (msg.toLowerCase().contains('rate limit')) {
        msg = 'tooManyAttempts'.tr;
      }
      Get.snackbar('error'.tr, msg,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: Colors.white,
          duration: const Duration(seconds: 5));
    } catch (e) {
      Get.snackbar('error'.tr, e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInWithGoogle() async {
    isGoogleLoading.value = true;
    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: '385193287847-rj9khau0b9h4dc8imqtfijs1gr8ahaes.apps.googleusercontent.com',
      );
      await googleSignIn.signOut();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        isGoogleLoading.value = false;
        return;
      }
      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        Get.snackbar('error'.tr, 'error'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.error,
            colorText: Colors.white);
        isGoogleLoading.value = false;
        return;
      }
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('logged_in', true);
      await prefs.setString('user_email', googleUser.email);
      Get.find<SupabaseService>().initRealtime();
      try {
        Get.find<SettingsController>().refreshAccount();
        Get.find<SettingsController>().loadStats();
      } catch (_) {}
      Get.offAllNamed(AppRoutes.home);
    } on AuthException catch (e) {
      Get.snackbar('error'.tr, e.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: Colors.white,
          duration: const Duration(seconds: 5));
    } catch (e) {
      final msg = kIsWeb
          ? 'Google Sign-In may need extra browser setup. Use email & password instead.'
          : e.toString();
      Get.snackbar('error'.tr, msg,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: Colors.white);
    } finally {
      isGoogleLoading.value = false;
    }
  }
}

/// Owns its [TextEditingController] so dispose runs after the dialog
/// is unmounted (avoids "used after being disposed" on route teardown).
class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({
    super.key,
    required this.initialEmail,
    required this.isLoading,
    required this.onSubmit,
  });

  final String initialEmail;
  final bool Function() isLoading;
  final Future<void> Function(String email) onSubmit;

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  late final TextEditingController _ctrl;
  final _key = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_key.currentState?.validate() ?? false)) return;
    if (_submitting) return;
    final email = _ctrl.text.trim();
    setState(() => _submitting = true);
    Get.back();
    await widget.onSubmit(email);
  }

  @override
  Widget build(BuildContext context) {
    final busy = _submitting || widget.isLoading();
    return AlertDialog(
      title: Text('resetPasswordTitle'.tr),
      content: Form(
        key: _key,
        child: TextFormField(
          controller: _ctrl,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'email'.tr,
            prefixIcon: const Icon(Icons.email_outlined),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'required'.tr;
            if (!v.trim().contains('@')) return 'invalid'.tr;
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Get.back(),
          child: Text('cancel'.tr),
        ),
        ElevatedButton(
          onPressed: busy ? null : _submit,
          child: busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('resetPassword'.tr),
        ),
      ],
    );
  }
}

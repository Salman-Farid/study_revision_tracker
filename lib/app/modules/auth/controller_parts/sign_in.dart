part of '../auth_controller.dart';

/// Email/password submit and Google Sign-In.
extension AuthSignIn on AuthController {
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

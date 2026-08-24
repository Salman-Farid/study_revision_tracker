import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/supabase_service.dart';
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
          Get.snackbar('Info', 'Account created. Try signing in.',
              snackPosition: SnackPosition.BOTTOM);
          isLogin.value = true;
          return;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('logged_in', true);
      await prefs.setString('user_email', emailCtrl.text.trim());
      Get.find<SupabaseService>().initRealtime();
      Get.offAllNamed(AppRoutes.home);
    } on AuthException catch (e) {
      String msg = e.message;
      if (msg.toLowerCase().contains('email not confirmed')) {
        msg = 'Email not confirmed. Please check your inbox or contact support.';
      }
      if (msg.toLowerCase().contains('rate limit')) {
        msg = 'Too many attempts. Wait a few minutes and try again.';
      }
      Get.snackbar('Error', msg,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: Colors.white,
          duration: const Duration(seconds: 5));
    } catch (e) {
      Get.snackbar('Error', e.toString(),
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
        Get.snackbar('Error', 'Failed to get Google credentials.',
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
      Get.offAllNamed(AppRoutes.home);
    } on AuthException catch (e) {
      Get.snackbar('Error', e.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: Colors.white,
          duration: const Duration(seconds: 5));
    } catch (e) {
      Get.snackbar('Error', 'Google sign-in failed: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: Colors.white);
    } finally {
      isGoogleLoading.value = false;
    }
  }
}

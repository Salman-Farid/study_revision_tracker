import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/size_constants.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController(), _pass = TextEditingController();
  final _fk = GlobalKey<FormState>();
  bool _login = true, _loading = false;
  bool _googleLoading = false;

  Future<void> _submit() async {
    if (!_fk.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final s = Supabase.instance.client;
      if (_login) {
        await s.auth.signInWithPassword(
            email: _email.text.trim(), password: _pass.text);
      } else {
        final res = await s.auth.signUp(
            email: _email.text.trim(), password: _pass.text);
        if (res.user != null && res.session == null) {
          Get.snackbar('Info', 'Account created. Try signing in.',
              snackPosition: SnackPosition.BOTTOM);
          setState(() => _login = true);
          return;
        }
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('logged_in', true);
      await prefs.setString('user_email', _email.text.trim());
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
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: '385193287847-rj9khau0b9h4dc8imqtfijs1gr8ahaes.apps.googleusercontent.com',
      );
      await googleSignIn.signOut(); // Force account picker every time
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _googleLoading = false);
        return; // User cancelled
      }
      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        Get.snackbar('Error', 'Failed to get Google credentials.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppColors.error,
            colorText: Colors.white);
        setState(() => _googleLoading = false);
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
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
        body: SafeArea(
            child: SingleChildScrollView(
                padding: EdgeInsets.all(S.xl),
                child: Form(
                    key: _fk,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: S.huge),
                          Container(
                              padding: EdgeInsets.all(S.lg),
                              decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius:
                                      BorderRadius.circular(S.radiusLg)),
                              child: Icon(Icons.school_rounded,
                                  color: AppColors.primary, size: S.iconXl)),
                          SizedBox(height: S.xxl),
                          Text(
                              _login ? 'Welcome Back' : 'Create Account',
                              style: AppTextStyles.displaySmall
                                  .copyWith(color: AppColors.textPrimary(d))),
                          SizedBox(height: S.sm),
                          Text(
                              _login
                                  ? 'Sign in to continue'
                                  : 'Start your revision journey',
                              style: AppTextStyles.bodyLarge
                                  .copyWith(color: AppColors.textMuted(d))),
                          SizedBox(height: S.xxxl),
                          // ── Google Sign-In Button ──
                          SizedBox(
                              width: double.infinity,
                              height: S.buttonHeight,
                              child: OutlinedButton.icon(
                                  onPressed:
                                      _googleLoading ? null : _signInWithGoogle,
                                  icon: _googleLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Icon(Icons.g_mobiledata_rounded,
                                          size: 24),
                                  label: Text('Continue with Google',
                                      style: AppTextStyles.labelLarge),
                                  style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color: AppColors.border(d)),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              S.radiusMd))))),
                          SizedBox(height: S.base),
                          // ── Divider ──
                          Row(children: [
                            Expanded(
                                child: Divider(color: AppColors.border(d))),
                            Padding(
                                padding:
                                    EdgeInsets.symmetric(horizontal: S.base),
                                child: Text('OR',
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textMuted(d)))),
                            Expanded(
                                child: Divider(color: AppColors.border(d))),
                          ]),
                          SizedBox(height: S.base),
                          // ── Email Fields ──
                          TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon:
                                      Icon(Icons.email_outlined)),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (!v.contains('@')) return 'Invalid';
                                return null;
                              }),
                          SizedBox(height: S.base),
                          TextFormField(
                              controller: _pass,
                              obscureText: true,
                              decoration: const InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon:
                                      Icon(Icons.lock_outline)),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (v.length < 6) return 'Min 6 chars';
                                return null;
                              }),
                          SizedBox(height: S.xxl),
                          SizedBox(
                              width: double.infinity,
                              height: S.buttonHeight,
                              child: ElevatedButton(
                                  onPressed: _loading ? null : _submit,
                                  child: _loading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : Text(_login ? 'Sign In' : 'Sign Up'))),
                          SizedBox(height: S.base),
                          Center(
                              child: TextButton(
                                  onPressed: () =>
                                      setState(() => _login = !_login),
                                  child: Text(
                                      _login
                                          ? "Don't have an account? Sign Up"
                                          : 'Already have an account? Sign In',
                                      style: AppTextStyles.bodyMedium
                                          .copyWith(
                                              color: AppColors.primary)))),
                        ])))));
  }
}

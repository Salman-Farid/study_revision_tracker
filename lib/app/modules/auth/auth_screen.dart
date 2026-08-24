import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';
import 'auth_controller.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<AuthController>();
    final d = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
        body: SafeArea(
            child: SingleChildScrollView(
                padding: EdgeInsets.all(S.xl),
                child: Form(
                    key: c.formKey,
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
                          Obx(() => Text(
                              c.isLogin.value ? 'Welcome Back' : 'Create Account',
                              style: AppTextStyles.displaySmall
                                  .copyWith(color: AppColors.textPrimary(d)))),
                          SizedBox(height: S.sm),
                          Obx(() => Text(
                              c.isLogin.value
                                  ? 'Sign in to continue'
                                  : 'Start your revision journey',
                              style: AppTextStyles.bodyLarge
                                  .copyWith(color: AppColors.textMuted(d)))),
                          SizedBox(height: S.xxxl),
                          SizedBox(
                              width: double.infinity,
                              height: S.buttonHeight,
                              child: Obx(() => OutlinedButton.icon(
                                  onPressed:
                                      c.isGoogleLoading.value ? null : c.signInWithGoogle,
                                  icon: c.isGoogleLoading.value
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
                                              S.radiusMd)))))),
                          SizedBox(height: S.base),
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
                          TextFormField(
                              controller: c.emailCtrl,
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
                              controller: c.passCtrl,
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
                              child: Obx(() => ElevatedButton(
                                  onPressed: c.isLoading.value ? null : c.submit,
                                  child: c.isLoading.value
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : Text(c.isLogin.value ? 'Sign In' : 'Sign Up')))),
                          SizedBox(height: S.base),
                          Center(
                              child: TextButton(
                                  onPressed: c.toggleMode,
                                  child: Obx(() => Text(
                                      c.isLogin.value
                                          ? "Don't have an account? Sign Up"
                                          : 'Already have an account? Sign In',
                                      style: AppTextStyles.bodyMedium
                                          .copyWith(
                                              color: AppColors.primary))))),
                        ])))));
  }
}

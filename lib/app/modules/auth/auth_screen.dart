import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/responsive.dart';
import '../../core/constants/size_constants.dart';
import '../../theme/app_theme.dart';
import 'auth_controller.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AuthController>();
    final d = Theme.of(context).brightness == Brightness.dark;
    Responsive.init(context);

    // Phone: existing single-column form.
    if (!Responsive.useNavRail) {
      return Scaffold(
        body: SafeArea(child: _formPane(c, d, compact: false)),
      );
    }

    // Desktop/tablet: form on one half, study art on the other.
    return Scaffold(
      body: Row(
        children: [
          Expanded(flex: 5, child: SafeArea(child: _formPane(c, d, compact: true))),
          Expanded(flex: 5, child: _imagePane(d)),
        ],
      ),
    );
  }

  Widget _imagePane(bool d) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        border: Border(
          left: BorderSide(color: AppColors.border(d)),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/auth_study.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallbackArt(d),
          ),
          // Soft brand wash so the form side stays the focus.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.bg(d).withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Positioned(
            left: 28,
            right: 28,
            bottom: 36,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Revision Tracker',
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Spaced revisions · Daily & class routines · Voice assistant',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackArt(bool d) {
    return ColoredBox(
      color: AppColors.primary.withValues(alpha: 0.12),
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 120,
          color: AppColors.primary.withValues(alpha: 0.45),
        ),
      ),
    );
  }

  Widget _formPane(AuthController c, bool d, {required bool compact}) {
    final maxWidth = compact ? 420.0 : double.infinity;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? S.xl : S.xl,
            vertical: S.xl,
          ),
          child: Form(
            key: c.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!compact) SizedBox(height: S.huge),
                Container(
                  padding: EdgeInsets.all(S.lg),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(S.radiusLg),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color: AppColors.primary,
                    size: S.iconXl,
                  ),
                ),
                SizedBox(height: compact ? S.xl : S.xxl),
                Obx(() => Text(
                      c.isLogin.value ? 'welcomeBack'.tr : 'createAccount'.tr,
                      style: AppTextStyles.displaySmall
                          .copyWith(color: AppColors.textPrimary(d)),
                    )),
                SizedBox(height: S.sm),
                Obx(() => Text(
                      c.isLogin.value
                          ? 'signInToContinue'.tr
                          : 'startRevisionJourney'.tr,
                      style: AppTextStyles.bodyLarge
                          .copyWith(color: AppColors.textMuted(d)),
                    )),
                SizedBox(height: compact ? S.xl : S.xxxl),
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.g_mobiledata_rounded, size: 24),
                        label: Text('continueWithGoogle'.tr,
                            style: AppTextStyles.labelLarge),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.border(d)),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(S.radiusMd),
                          ),
                        ),
                      )),
                ),
                SizedBox(height: S.base),
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.border(d))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: S.base),
                      child: Text(
                        'or'.tr,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted(d)),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.border(d))),
                  ],
                ),
                SizedBox(height: S.base),
                TextFormField(
                  controller: c.emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'email'.tr,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'required'.tr;
                    if (!v.contains('@')) return 'invalid'.tr;
                    return null;
                  },
                ),
                SizedBox(height: S.base),
                TextFormField(
                  controller: c.passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'password'.tr,
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'required'.tr;
                    if (v.length < 6) return 'minChars'.tr;
                    return null;
                  },
                ),
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
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                c.isLogin.value ? 'signIn'.tr : 'signUp'.tr),
                      )),
                ),
                SizedBox(height: S.base),
                Center(
                  child: TextButton(
                    onPressed: c.toggleMode,
                    child: Obx(() => Text(
                          c.isLogin.value
                              ? 'noAccount'.tr
                              : 'haveAccount'.tr,
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.primary),
                        )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

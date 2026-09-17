import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/responsive.dart';
import '../../core/constants/size_constants.dart';
import '../../core/services/password_recovery_service.dart';
import '../../theme/app_theme.dart';
import 'auth_controller.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AuthController>();
    final recovery = Get.find<PasswordRecoveryService>();
    // Always re-check the address bar (web cold start / hot restart).
    recovery.syncFromCurrentUri();
    final d = Theme.of(context).brightness == Brightness.dark;
    Responsive.init(context);

    // Phone: existing single-column form.
    if (!Responsive.useNavRail) {
      return Scaffold(
        body: SafeArea(child: _formPane(c, recovery, d, compact: false)),
      );
    }

    // Desktop/tablet: study art LEFT, form RIGHT.
    return Scaffold(
      body: Row(
        children: [
          Expanded(flex: 5, child: _imagePane(d)),
          Expanded(
              flex: 5,
              child: SafeArea(child: _formPane(c, recovery, d, compact: true))),
        ],
      ),
    );
  }

  Widget _imagePane(bool d) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        border: Border(
          right: BorderSide(color: AppColors.border(d)),
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
          // Soft wash toward the form side so fields stay the focus.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.transparent,
                  AppColors.bg(d).withValues(alpha: 0.4),
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

  Widget _formPane(
    AuthController c,
    PasswordRecoveryService recovery,
    bool d, {
    required bool compact,
  }) {
    final maxWidth = compact ? 420.0 : double.infinity;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: S.xl,
            vertical: S.xl,
          ),
          // Recovery email link → always show the set-password form here.
          // (A floating dialog races cold-start / PKCE exchange.)
          child: Obx(() {
            if (recovery.isRecovery.value) {
              return _SetPasswordPane(recovery: recovery, d: d, compact: compact);
            }
            return _SignInPane(c: c, d: d, compact: compact);
          }),
        ),
      ),
    );
  }
}

class _SetPasswordPane extends StatefulWidget {
  const _SetPasswordPane({
    required this.recovery,
    required this.d,
    required this.compact,
  });

  final PasswordRecoveryService recovery;
  final bool d;
  final bool compact;

  @override
  State<_SetPasswordPane> createState() => _SetPasswordPaneState();
}

class _SetPasswordPaneState extends State<_SetPasswordPane> {
  final _ctrl = TextEditingController();
  final _key = GlobalKey<FormState>();
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Ensure PKCE exchange finished, then allow submit once a session exists.
    await widget.recovery.ensureSessionForRecovery();
    if (!mounted) return;
    setState(() {
      _ready = widget.recovery.hasSession;
      if (!_ready) {
        final detail = widget.recovery.recoveryError.value;
        _error = detail == null || detail.isEmpty
            ? 'This reset link is expired or already used. Request a new one from Sign In.'
            : 'Reset failed: $detail';
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_key.currentState?.validate() ?? false)) return;
    setState(() => _error = null);
    final ok = await widget.recovery.updatePassword(_ctrl.text);
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = 'Could not update password. Try a new reset link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    return Obx(() {
      final loading = widget.recovery.isLoading.value;
      final ready = _ready;
      return Form(
        key: _key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.compact) SizedBox(height: S.huge),
            Container(
              padding: EdgeInsets.all(S.lg),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(S.radiusLg),
              ),
              child: Icon(
                Icons.lock_reset_rounded,
                color: AppColors.primary,
                size: S.iconXl,
              ),
            ),
            SizedBox(height: widget.compact ? S.xl : S.xxl),
            Text(
              'setNewPassword'.tr,
              style: AppTextStyles.displaySmall
                  .copyWith(color: AppColors.textPrimary(d)),
            ),
            SizedBox(height: S.sm),
            Text(
              'setNewPasswordBody'.tr,
              style: AppTextStyles.bodyLarge
                  .copyWith(color: AppColors.textMuted(d)),
            ),
            SizedBox(height: S.xl),
            if (!ready && _error == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                ),
              ),
              SizedBox(height: S.base),
              SizedBox(
                width: double.infinity,
                height: S.buttonHeight,
                child: OutlinedButton(
                  onPressed: () {
                    widget.recovery.isRecovery.value = false;
                    PasswordRecoveryService.clearAuthQueryFromUrl();
                  },
                  child: Text('signIn'.tr),
                ),
              ),
            ],
            if (ready) ...[
              TextFormField(
                controller: _ctrl,
                autofocus: true,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'newPassword'.tr,
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
                child: ElevatedButton(
                  onPressed: loading ? null : _submit,
                  child: loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('save'.tr),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _SignInPane extends StatelessWidget {
  const _SignInPane({
    required this.c,
    required this.d,
    required this.compact,
  });

  final AuthController c;
  final bool d;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Form(
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
                  onPressed: c.isGoogleLoading.value ? null : c.signInWithGoogle,
                  icon: c.isGoogleLoading.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.g_mobiledata_rounded, size: 24),
                  label: Text('continueWithGoogle'.tr,
                      style: AppTextStyles.labelLarge),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.border(d)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(S.radiusMd),
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
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d)),
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
          // Forgot password — login mode only.
          Obx(() {
            if (!c.isLogin.value) return const SizedBox.shrink();
            return Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: c.showForgotPasswordDialog,
                child: Text(
                  'forgotPassword'.tr,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.primary),
                ),
              ),
            );
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
                            color: Colors.white,
                          ),
                        )
                      : Text(c.isLogin.value ? 'signIn'.tr : 'signUp'.tr),
                )),
          ),
          SizedBox(height: S.base),
          Center(
            child: TextButton(
              onPressed: c.toggleMode,
              child: Obx(() => Text(
                    c.isLogin.value ? 'noAccount'.tr : 'haveAccount'.tr,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.primary),
                  )),
            ),
          ),
        ],
      ),
    );
  }
}
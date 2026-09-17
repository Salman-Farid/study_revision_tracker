import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/size_constants.dart';
import '../../../core/services/password_recovery_service.dart';
import '../../../theme/app_theme.dart';

class SetPasswordPane extends StatefulWidget {
  const SetPasswordPane({
    super.key,
    required this.recovery,
    required this.d,
    required this.compact,
  });

  final PasswordRecoveryService recovery;
  final bool d;
  final bool compact;

  @override
  State<SetPasswordPane> createState() => _SetPasswordPaneState();
}

class _SetPasswordPaneState extends State<SetPasswordPane> {
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

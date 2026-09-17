part of '../password_recovery_service.dart';

/// Set-new-password prompt and password update flow.
extension PasswordRecoveryUpdate on PasswordRecoveryService {
  /// Show the set-new-password dialog when a recovery session is active.
  /// Prefer the inline AuthScreen form; dialog is a backup path.
  Future<void> maybePromptNewPassword() async {
    if (!isRecovery.value || _promptShown) return;
    if (Get.isDialogOpen ?? false) return;

    final ok = await ensureSessionForRecovery();
    if (!ok) return;
    if (_promptShown || !isRecovery.value) return;
    if (Get.isDialogOpen ?? false) return;

    _promptShown = true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!isRecovery.value) return;
    // Inline form on AuthScreen is the primary UI — only dialog if somehow
    // we're not on that screen.
    if (Get.currentRoute == AppRoutes.auth) return;
    await showSetNewPasswordDialog();
  }

  Future<void> showSetNewPasswordDialog() async {
    await Get.dialog(
      SetNewPasswordDialog(
        isLoading: () => isLoading.value,
        isRecovery: () => isRecovery.value,
        onSubmit: (pw) => updatePassword(pw),
      ),
      barrierDismissible: false,
    );
  }

  Future<bool> updatePassword(String newPassword) async {
    isLoading.value = true;
    try {
      if (!hasSession) {
        final ready = await ensureSessionForRecovery();
        if (!ready) {
          Get.snackbar('error'.tr,
              'Reset link expired or already used. Request a new one.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppColors.error,
              colorText: Colors.white,
              duration: const Duration(seconds: 5));
          return false;
        }
      }

      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: newPassword));
      isRecovery.value = false;
      _promptShown = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('logged_in', true);
      final email = Supabase.instance.client.auth.currentUser?.email;
      if (email != null && email.isNotEmpty) {
        await prefs.setString('user_email', email);
      }

      try {
        Get.find<SupabaseService>().initRealtime();
      } catch (_) {}
      try {
        Get.find<SettingsController>().refreshAccount();
        Get.find<SettingsController>().loadStats();
      } catch (_) {}

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      Get.snackbar('info'.tr, 'passwordUpdated'.tr,
          snackPosition: SnackPosition.BOTTOM);
      Get.offAllNamed(AppRoutes.home);
      return true;
    } on AuthException catch (e) {
      Get.snackbar('error'.tr, e.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: Colors.white,
          duration: const Duration(seconds: 5));
      return false;
    } catch (e) {
      Get.snackbar('error'.tr, e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: Colors.white);
      return false;
    } finally {
      isLoading.value = false;
    }
  }
}

/// Owns its [TextEditingController] so dispose runs after unmount.
class SetNewPasswordDialog extends StatefulWidget {
  const SetNewPasswordDialog({
    super.key,
    required this.isLoading,
    required this.isRecovery,
    required this.onSubmit,
  });

  final bool Function() isLoading;
  final bool Function() isRecovery;
  final Future<void> Function(String password) onSubmit;

  @override
  State<SetNewPasswordDialog> createState() => _SetNewPasswordDialogState();
}

class _SetNewPasswordDialogState extends State<SetNewPasswordDialog> {
  late final TextEditingController _ctrl;
  final _key = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_key.currentState?.validate() ?? false)) return;
    final pw = _ctrl.text;
    await widget.onSubmit(pw);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !widget.isRecovery()) Get.back();
      },
      child: AlertDialog(
        title: Text('setNewPassword'.tr),
        content: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'setNewPasswordBody'.tr,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
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
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: widget.isLoading() ? null : _submit,
            child: widget.isLoading()
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('save'.tr),
          ),
        ],
      ),
    );
  }
}

part of '../auth_controller.dart';

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

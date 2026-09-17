import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/responsive.dart';
import '../../core/constants/size_constants.dart';
import '../../core/services/password_recovery_service.dart';
import '../../theme/app_theme.dart';
import 'auth_controller.dart';
import 'widgets/auth_image_pane.dart';
import 'widgets/set_password_pane.dart';
import 'widgets/sign_in_pane.dart';

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
          Expanded(flex: 5, child: AuthImagePane(d: d)),
          Expanded(
              flex: 5,
              child: SafeArea(child: _formPane(c, recovery, d, compact: true))),
        ],
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
              return SetPasswordPane(recovery: recovery, d: d, compact: compact);
            }
            return SignInPane(c: c, d: d, compact: compact);
          }),
        ),
      ),
    );
  }
}

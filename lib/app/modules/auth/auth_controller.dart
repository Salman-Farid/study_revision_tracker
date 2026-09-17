import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/password_recovery_service.dart';
import '../../data/services/supabase_service.dart';
import '../../modules/settings/settings_controller.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

part 'controller_parts/password_reset.dart';
part 'controller_parts/sign_in.dart';
part 'controller_parts/forgot_password_dialog.dart';

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

  /// Recovery is handled app-wide by [PasswordRecoveryService].
  void maybePromptNewPassword() {
    try {
      Get.find<PasswordRecoveryService>().maybePromptNewPassword();
    } catch (_) {}
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/size_constants.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController(), _pass = TextEditingController();
  final _fk = GlobalKey<FormState>();
  bool _login = true, _loading = false;

  Future<void> _submit() async {
    if (!_fk.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final s = Supabase.instance.client;
      if (_login) {
        await s.auth.signInWithPassword(email: _email.text.trim(), password: _pass.text);
      } else {
        await s.auth.signUp(email: _email.text.trim(), password: _pass.text);
      }
      Get.offAllNamed(AppRoutes.home);
    } on AuthException catch (e) {
      Get.snackbar('Error', e.message, snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error, colorText: Colors.white);
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override void dispose() { _email.dispose(); _pass.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(body: SafeArea(child: SingleChildScrollView(
      padding: EdgeInsets.all(S.xl), child: Form(key: _fk, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(height: S.huge),
          Container(padding: EdgeInsets.all(S.lg), decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(S.radiusLg)),
            child: Icon(Icons.school_rounded, color: AppColors.primary, size: S.iconXl)),
          SizedBox(height: S.xxl),
          Text(_login ? 'Welcome Back' : 'Create Account',
            style: AppTextStyles.displaySmall.copyWith(color: AppColors.textPrimary(d))),
          SizedBox(height: S.sm),
          Text(_login ? 'Sign in to continue' : 'Start your revision journey',
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textMuted(d))),
          SizedBox(height: S.xxxl),
          TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
            validator: (v) { if (v == null || v.isEmpty) return 'Required'; if (!v.contains('@')) return 'Invalid'; return null; }),
          SizedBox(height: S.base),
          TextFormField(controller: _pass, obscureText: true,
            decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
            validator: (v) { if (v == null || v.isEmpty) return 'Required'; if (v.length < 6) return 'Min 6 chars'; return null; }),
          SizedBox(height: S.xxl),
          SizedBox(width: double.infinity, height: S.buttonHeight, child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading ? const SizedBox(height: 20, width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_login ? 'Sign In' : 'Sign Up'))),
          SizedBox(height: S.base),
          Center(child: TextButton(onPressed: () => setState(() => _login = !_login),
            child: Text(_login ? "Don't have an account? Sign Up" : 'Already have an account? Sign In',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary)))),
        ])))));
  }
}

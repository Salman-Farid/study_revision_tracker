import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/size_constants.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final d = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(appBar: AppBar(title: Text('Settings', style: AppTextStyles.headlineMedium)),
      body: ListView(padding: EdgeInsets.all(S.xl), children: [
        _section('Account', [_tile(Icons.person_rounded, 'Profile',
          Supabase.instance.client.auth.currentUser?.email ?? '', () {})]),
        SizedBox(height: S.xl),
        _section('Preferences', [
          _tile(Icons.notifications_rounded, 'Notifications', 'Manage reminders', () {}),
          _tile(Icons.calendar_month_rounded, 'Calendar', 'Device integration', () {}),
        ]),
        SizedBox(height: S.xl),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: () async { await Supabase.instance.client.auth.signOut(); Get.offAllNamed(AppRoutes.auth); },
          icon: const Icon(Icons.logout_rounded, color: AppColors.error),
          label: Text('Sign Out', style: AppTextStyles.labelLarge.copyWith(color: AppColors.error)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)))),
        SizedBox(height: S.xxxl),
      ]));
  }

  Widget _section(String title, List<Widget> items) {
    final d = Get.isDarkMode;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: AppTextStyles.labelLarge.copyWith(color: AppColors.textMuted(d), letterSpacing: 1)),
      SizedBox(height: S.sm),
      Container(decoration: BoxDecoration(color: AppColors.surface(d), borderRadius: BorderRadius.circular(S.radiusLg),
        border: Border.all(color: AppColors.border(d))), child: Column(children: items)),
    ]);
  }

  Widget _tile(IconData icon, String title, String sub, VoidCallback onTap) {
    final d = Get.isDarkMode;
    return Material(color: Colors.transparent, child: InkWell(onTap: onTap,
      child: Padding(padding: EdgeInsets.symmetric(horizontal: S.base, vertical: S.md),
        child: Row(children: [
          Icon(icon, color: AppColors.textPrimary(d), size: S.iconMd), SizedBox(width: S.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTextStyles.titleSmall.copyWith(color: AppColors.textPrimary(d))),
            Text(sub, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted(d))),
          ])),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted(d), size: S.iconSm),
        ]))));
  }
}

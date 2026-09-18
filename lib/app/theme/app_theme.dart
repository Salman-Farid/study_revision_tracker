import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/responsive.dart';

class AppColors {
  AppColors._();
  static Color get primary => AppConstants.primaryColor;
  static Color get primaryLight => AppConstants.primaryColorLight;
  static Color get secondary => AppConstants.secondaryColor;
  static Color get success => AppConstants.successColor;
  static Color get warning => AppConstants.warningColor;
  static Color get error => AppConstants.errorColor;
  static Color get info => AppConstants.infoColor;
  static Color get forgot => AppConstants.errorColor;
  static Color get partial => AppConstants.warningColor;
  static Color get good => AppConstants.infoColor;
  static Color get perfect => AppConstants.successColor;

  static const Color bgLight = Color(0xFFF8F9FC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE8ECF4);
  static const Color textPrimaryLight = Color(0xFF1A1D26);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textMutedLight = Color(0xFF9CA3AF);

  static const Color bgDark = Color(0xFF0D0F14);
  static const Color surfaceDark = Color(0xFF1A1D26);
  static const Color borderDark = Color(0xFF2D3140);
  static const Color textPrimaryDark = Color(0xFFF0F2F5);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);
  static const Color textMutedDark = Color(0xFF6B7280);

  static Color textPrimary(bool d) => d ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(bool d) => d ? textSecondaryDark : textSecondaryLight;
  static Color textMuted(bool d) => d ? textMutedDark : textMutedLight;
  static Color surface(bool d) => d ? surfaceDark : surfaceLight;
  static Color bg(bool d) => d ? bgDark : bgLight;
  static Color border(bool d) => d ? borderDark : borderLight;
  static Color ratingColor(String r) {
    switch (r) { case 'forgot': return forgot; case 'partial': return partial;
      case 'good': return good; case 'perfect': return perfect; default: return textMutedLight; }
  }

  static Color get accent => AppConstants.accentColor;
  static Color get accentLight => AppConstants.accentColorLight;
  static Color get primarySurface => AppConstants.primarySurface;
  static Color get secondarySurface => AppConstants.secondarySurface;
  static Color get accentSurface => AppConstants.accentSurface;
}

class AppTextStyles {
  AppTextStyles._();
  static double _f(double s) => Responsive.fontScale(s);
  static TextStyle get displaySmall => TextStyle(fontSize: _f(24), fontWeight: FontWeight.w700, height: 1.3);
  static TextStyle get headlineLarge => TextStyle(fontSize: _f(22), fontWeight: FontWeight.w700, height: 1.35);
  static TextStyle get headlineMedium => TextStyle(fontSize: _f(20), fontWeight: FontWeight.w600, height: 1.35);
  static TextStyle get headlineSmall => TextStyle(fontSize: _f(18), fontWeight: FontWeight.w600, height: 1.4);
  static TextStyle get titleLarge => TextStyle(fontSize: _f(17), fontWeight: FontWeight.w600, height: 1.4);
  static TextStyle get titleMedium => TextStyle(fontSize: _f(15), fontWeight: FontWeight.w600, height: 1.45);
  static TextStyle get titleSmall => TextStyle(fontSize: _f(14), fontWeight: FontWeight.w500, height: 1.45);
  static TextStyle get bodyLarge => TextStyle(fontSize: _f(16), fontWeight: FontWeight.w400, height: 1.5);
  static TextStyle get bodyMedium => TextStyle(fontSize: _f(14), fontWeight: FontWeight.w400, height: 1.5);
  static TextStyle get bodySmall => TextStyle(fontSize: _f(12), fontWeight: FontWeight.w400, height: 1.5);
  static TextStyle get labelLarge => TextStyle(fontSize: _f(14), fontWeight: FontWeight.w500, height: 1.4, letterSpacing: 0.1);
  static TextStyle get labelMedium => TextStyle(fontSize: _f(12), fontWeight: FontWeight.w500, height: 1.4, letterSpacing: 0.5);
  static TextStyle get labelSmall => TextStyle(fontSize: _f(10), fontWeight: FontWeight.w500, height: 1.4, letterSpacing: 0.5);
}

class AppTheme {
  AppTheme._();
  static ThemeData get light => ThemeData(
    useMaterial3: true, brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: AppConstants.primaryColor, secondary: AppConstants.secondaryColor,
      surface: AppColors.surfaceLight, background: AppColors.bgLight,
      error: AppConstants.errorColor, onPrimary: Colors.white, onSecondary: Colors.white,
      onSurface: AppColors.textPrimaryLight, onBackground: AppColors.textPrimaryLight,
    ),
    scaffoldBackgroundColor: AppColors.bgLight,
    textTheme: _text(Brightness.light),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bgLight, foregroundColor: AppColors.textPrimaryLight,
      elevation: 0, centerTitle: false,
      systemOverlayStyle: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
      titleTextStyle: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(color: AppColors.surfaceLight, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: AppColors.surfaceLight,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderLight)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMutedLight),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0,
      minimumSize: const Size(double.infinity, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
    )),
    dividerTheme: const DividerThemeData(color: AppColors.borderLight, thickness: 1, space: 0),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textPrimaryLight,
      contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    dialogTheme: DialogThemeData(backgroundColor: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: AppColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24)))),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true, brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: AppConstants.primaryColor, secondary: AppConstants.secondaryColor,
      surface: AppColors.surfaceDark, background: AppColors.bgDark,
      error: AppConstants.errorColor, onPrimary: Colors.white, onSecondary: Colors.white,
      onSurface: AppColors.textPrimaryDark, onBackground: AppColors.textPrimaryDark,
    ),
    scaffoldBackgroundColor: AppColors.bgDark,
    textTheme: _text(Brightness.dark),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bgDark, foregroundColor: AppColors.textPrimaryDark,
      elevation: 0, centerTitle: false,
      systemOverlayStyle: const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
    ),
    cardTheme: CardThemeData(color: AppColors.surfaceDark, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: AppColors.surfaceDark,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.borderDark)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMutedDark),
    ),
    dialogTheme: DialogThemeData(backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24)))),
  );

  static TextTheme _text(Brightness b) {
    final c = b == Brightness.light ? AppColors.textPrimaryLight : AppColors.textPrimaryDark;
    return TextTheme(
      displaySmall: AppTextStyles.displaySmall.copyWith(color: c),
      headlineLarge: AppTextStyles.headlineLarge.copyWith(color: c),
      headlineMedium: AppTextStyles.headlineMedium.copyWith(color: c),
      headlineSmall: AppTextStyles.headlineSmall.copyWith(color: c),
      titleLarge: AppTextStyles.titleLarge.copyWith(color: c),
      titleMedium: AppTextStyles.titleMedium.copyWith(color: c),
      titleSmall: AppTextStyles.titleSmall.copyWith(color: c),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(color: c),
      bodyMedium: AppTextStyles.bodyMedium.copyWith(color: c),
      bodySmall: AppTextStyles.bodySmall.copyWith(color: c),
      labelLarge: AppTextStyles.labelLarge.copyWith(color: c),
      labelMedium: AppTextStyles.labelMedium.copyWith(color: c),
      labelSmall: AppTextStyles.labelSmall.copyWith(color: c),
    );
  }
}

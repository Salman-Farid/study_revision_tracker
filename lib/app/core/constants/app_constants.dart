import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();
  static const String appName = 'Pootu: StudyCompanion';
  static const String appVersion = '1.0.3';

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL', defaultValue: 'https://bvvflpxmpdwgpliispxi.supabase.co');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2dmZscHhtcGR3Z3BsaWlzcHhpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc0ODQ5ODQsImV4cCI6MjEwMzA2MDk4NH0.h0sisR7CK6lujdTkSdk76oBcz4uGXoIJ2eeCVkOxBNU');

  static const List<int> revisionDays = [1, 3, 7, 14, 30, 90];
  static const List<String> revisionDayLabels = [
    'Day 1', 'Day 3', 'Day 7', 'Day 14', 'Day 30', 'Day 90',
  ];

  static const Duration pageTransitionDuration = Duration(milliseconds: 400);
  static const Duration microDuration = Duration(milliseconds: 150);
  static const Duration shortDuration = Duration(milliseconds: 250);
  static const Duration mediumDuration = Duration(milliseconds: 400);
  static const Duration longDuration = Duration(milliseconds: 600);
  static const Duration cinematicDuration = Duration(milliseconds: 1200);
  static const Duration staggerDelay = Duration(milliseconds: 80);

  // ── BRAND COLORS ──
  static const Color primaryColor = Color(0xFF87CEEB);       // Sky Blue
  static const Color primaryDarkColor = Color(0xFF5BA3D9);   // Deeper Sky Blue
  static const Color primaryLightColor = Color(0xFFB8E0F7);  // Light Sky Blue

  static const Color secondaryColor = Color(0xFF81D4FA);     // Light Sky Blue
  static const Color secondaryDarkColor = Color(0xFF4FC3F7); // Deeper Light Sky Blue
  static const Color secondaryLightColor = Color(0xFFE1F5FE);// Pale Sky Blue

  static const Color accentColor = Color(0xFFFF8A80);        // Soft Red
  static const Color accentDarkColor = Color(0xFFE56B60);    // Deeper Soft Red
  static const Color accentLightColor = Color(0xFFFFCDD2);   // Light Soft Red

  static const List<Color> subjectColors = [
    Color(0xFF87CEEB), Color(0xFF81D4FA), Color(0xFFFF8A80),
    Color(0xFFB8E0F7), Color(0xFF4FC3F7), Color(0xFFE56B60),
    Color(0xFF5BA3D9), Color(0xFFE1F5FE), Color(0xFFFFCDD2),
    Color(0xFF4FC3F7), Color(0xFF29B6F6), Color(0xFFEF9A9A),
  ];

  // ── SEMANTIC COLORS ──
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color infoColor = Color(0xFF2196F3);

  // ── SURFACE COLORS ──
  static const Color primarySurface = Color(0xFFE3F2FD);
  static const Color secondarySurface = Color(0xFFE1F5FE);
  static const Color accentSurface = Color(0xFFFFEBEE);

  // ── ALIASES ──
  static const Color primaryColorLight = Color(0xFFB8E0F7);
  static const Color accentColorLight = Color(0xFFFFCDD2);
  // Centralized day-key list used across calendar, class routine, and edit sheets.
  // Use getter instead of const to avoid runtime locale lookup issues.
  static List<String> get dayKeys => ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

}

import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();
  static const String appName = 'Smart Revision Tracker';
  static const String appVersion = '1.0.0';

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL', defaultValue: 'https://YOUR_PROJECT.supabase.co');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY', defaultValue: 'YOUR_ANON_KEY');
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY', defaultValue: 'YOUR_GEMINI_KEY');

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

  static const List<Color> subjectColors = [
    Color(0xFF6C63FF), Color(0xFFFF6584), Color(0xFF43E97B),
    Color(0xFFFA709A), Color(0xFFF093FB), Color(0xFF4FACFE),
    Color(0xFFFFA726), Color(0xFF0099F7), Color(0xFFF5576C),
    Color(0xFF0250C5), Color(0xFFD4FC79), Color(0xFF96E6A1),
  ];
}

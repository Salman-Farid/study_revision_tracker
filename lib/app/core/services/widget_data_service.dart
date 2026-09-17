import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import '../../data/models/class_routine_model.dart';
import '../../data/models/daily_routine_model.dart';
import '../../data/models/revision_schedule_model.dart';

part 'widget_data/keys.dart';
part 'widget_data/daily_routine_fetch.dart';
part 'widget_data/revision_fetch.dart';
part 'widget_data/class_routine_fetch.dart';
part 'widget_data/save_helpers.dart';
part 'widget_data/format_utils.dart';

/// Background callback entry point — MUST be a top-level function.
/// Invoked by home_widget WorkManager / interactive taps when the
/// Flutter UI is not running.
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseAnonKey,
      );
    } catch (_) {
      // Already initialized in this isolate.
    }
    await WidgetDataProvider.updateAllWidgets(forceRefresh: true);
  } catch (e) {
    debugPrint('[WidgetData] backgroundCallback error: $e');
  }
}

/// Provides widget data to home screen widgets.
///
/// This service fetches data directly from Supabase (bypassing GetX)
/// so it works both in foreground and background callbacks.
class WidgetDataProvider {
  WidgetDataProvider._();

  // ── Deep-link scheme ──
  static const String urlScheme = 'study-revision-tracker';

  // ── Initialize ──

  /// Call once during app startup to register background callbacks.
  /// No-op on web — there are no home-screen widgets in the browser.
  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      await HomeWidget.registerInteractivityCallback(backgroundCallback);
    } catch (e) {
      debugPrint('[WidgetData] registerInteractivityCallback failed: $e');
    }
  }

  /// Get the initial deep link URI from a widget tap (if any).
  static Future<Uri?> getInitialLink() async {
    if (kIsWeb) return null;
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (_) {
      return null;
    }
  }

  // ── Widget tap handler ──
  // Interactive taps are handled by the Flutter app's navigation via deep links.
  // Background data refresh is handled by [backgroundCallback].

  // ── Public API ──

  /// Update all three widgets. Call on data changes and periodically.
  /// No-op on web.
  static Future<void> updateAllWidgets({bool forceRefresh = false}) async {
    if (kIsWeb) return;
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        await _setEmptyData();
        return;
      }
      final userId = user.id;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      // Fetch all needed data in parallel
      final results = await Future.wait([
        _fetchDailyRoutineData(client, userId, now, today, tomorrow),
        _fetchRevisionData(client, userId, today, tomorrow),
        _fetchClassRoutineData(client, userId, now, today, tomorrow),
      ]);

      debugPrint('[WidgetData] updateAllWidgets daily=${results[0]['hasData']} '
          'rev=${results[1]['hasData']} class=${results[2]['hasToday']}');

      // Save data via HomeWidget (writes to the platform-native shared
      // preferences file that Android/iOS widgets can read).
      await Future.wait([
        HomeWidget.saveWidgetData<String>(_kLastUpdated, now.toIso8601String()),
        _saveDailyWidgetData(results[0]),
        _saveRevisionWidgetData(results[1]),
        _saveClassWidgetData(results[2]),
      ]);

      // Notify native widgets to update
      await Future.wait([
        HomeWidget.updateWidget(
          qualifiedAndroidName: 'com.example.study_revision_tracker.DailyRoutineWidget',
        ),
        HomeWidget.updateWidget(
          qualifiedAndroidName: 'com.example.study_revision_tracker.RevisionWidget',
        ),
        HomeWidget.updateWidget(
          qualifiedAndroidName: 'com.example.study_revision_tracker.ClassRoutineWidget',
        ),
      ]);
    } catch (e, stack) {
      debugPrint('[WidgetData] updateAllWidgets error: $e\n$stack');
    }
  }
}

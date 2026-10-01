package com.pootustudycompanion.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "study_revision_tracker/widget_tick"
        ).setMethodCallHandler { call, result ->
            if (call.method == "schedule") {
                try {
                    WidgetTickReceiver.scheduleNext(applicationContext)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("schedule_failed", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Re-arm the 10-minute tick whenever the app is used.
        try {
            WidgetTickReceiver.scheduleNext(applicationContext)
        } catch (_: Exception) {
        }
    }
}

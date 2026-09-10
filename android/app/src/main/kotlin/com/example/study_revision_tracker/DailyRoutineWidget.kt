package com.example.study_revision_tracker

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.widget.RemoteViews
import android.app.PendingIntent

class DailyRoutineWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_REFRESH, ACTION_DAILY_TICK,
            "com.example.study_revision_tracker.UPDATE_WIDGETS",
            AppWidgetManager.ACTION_APPWIDGET_UPDATE -> {
                val mgr = AppWidgetManager.getInstance(context)
                val ids = mgr.getAppWidgetIds(ComponentName(context, DailyRoutineWidget::class.java))
                for (id in ids) updateWidget(context, mgr, id, updateTimer = true)
            }
        }
    }

    companion object {
        const val ACTION_REFRESH = "com.example.study_revision_tracker.REFRESH_DAILY"
        const val ACTION_DAILY_TICK = "com.example.study_revision_tracker.DAILY_TICK"
    }
}

private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, updateTimer: Boolean = false) {
    try {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val hasData = prefs.getString("widget_daily_has_data", "false") == "true"
        var statusMessage = prefs.getString("widget_daily_status_message", "") ?: ""
        if (statusMessage.isBlank() || statusMessage.contains("Error", ignoreCase = true)) {
            statusMessage = "Nothing to show"
        }
        val currentSubject = prefs.getString("widget_daily_current_subject", "") ?: ""
        val currentTopic = prefs.getString("widget_daily_current_topic", "") ?: ""
        val currentType = prefs.getString("widget_daily_current_type", "") ?: ""
        val currentTime = prefs.getString("widget_daily_current_time", "") ?: ""
        val remaining = prefs.getString("widget_daily_remaining", "") ?: ""
        val endTimestamp = prefs.getString("widget_daily_current_end_timestamp", "0")?.toLongOrNull() ?: 0L
        val lastUpdated = prefs.getString("widget_last_updated", "") ?: ""

        val hasCurrent = currentSubject.isNotEmpty() && endTimestamp > System.currentTimeMillis()

        val views = RemoteViews(context.packageName, R.layout.daily_routine_widget)

        // Current card
        if (hasCurrent) {
            views.setViewVisibility(R.id.widget_current_card, android.view.View.VISIBLE)
            views.setTextViewText(R.id.widget_current_subject, currentSubject)
            views.setTextViewText(R.id.widget_current_topic, currentTopic)
            views.setTextViewText(R.id.widget_current_type, currentType)
            // Timeline (start – end) of the current task
            views.setTextViewText(R.id.widget_current_time, currentTime)

            // Real-time countdown timer (ticks every second in the widget itself).
            // Uses a Chronometer counting down to the task's end timestamp.
            // Falls back to the static "remaining" text below API 24.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && endTimestamp > System.currentTimeMillis()) {
                val remainingMs = endTimestamp - System.currentTimeMillis()
                views.setChronometerCountDown(R.id.widget_current_timer, true)
                views.setChronometer(
                    R.id.widget_current_timer,
                    SystemClock.elapsedRealtime() + remainingMs,
                    "%s",
                    true
                )
            } else {
                views.setString(R.id.widget_current_timer, "setText", remaining)
            }

            // Click to open app
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pending = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            views.setOnClickPendingIntent(R.id.widget_current_card, pending)
        } else {
            views.setViewVisibility(R.id.widget_current_card, android.view.View.GONE)
        }

        // Upcoming header — ONLY if there ARE upcoming items
        val upcomingJson = prefs.getString("widget_daily_upcoming_items", "[]") ?: "[]"
        val hasUpcoming = try {
            val arr = org.json.JSONArray(upcomingJson)
            arr.length() > 0
        } catch (_: Exception) { false }

        if (hasUpcoming && hasCurrent) {
            views.setViewVisibility(R.id.widget_upcoming_header, android.view.View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_upcoming_header, android.view.View.GONE)
        }

        // Connect the ListView to the RemoteViewsService adapter for scrollable content
        val adapterIntent = Intent(context, DailyRoutineWidgetService::class.java)
        adapterIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        adapterIntent.action = "android.appwidget.action.APPWIDGET_UPDATE"
        views.setRemoteAdapter(R.id.widget_upcoming_list, adapterIntent)

        // Set the empty view for when there's no data
        views.setEmptyView(R.id.widget_upcoming_list, R.id.widget_empty)

        // Empty state
        if (!hasData) {
            views.setViewVisibility(R.id.widget_upcoming_list, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_empty, android.view.View.VISIBLE)
            views.setTextViewText(R.id.widget_empty_message, statusMessage)
        } else if (!hasUpcoming && !hasCurrent) {
            views.setViewVisibility(R.id.widget_upcoming_list, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_empty, android.view.View.VISIBLE)
            views.setTextViewText(R.id.widget_empty_message, "No more blocks today")
        } else {
            views.setViewVisibility(R.id.widget_empty, android.view.View.GONE)
        }

        // Timestamp
        if (lastUpdated.isNotEmpty()) {
            val time = lastUpdated.substringAfter("T", "").take(5)
            views.setTextViewText(R.id.widget_updated, "Updated $time")
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
        // Notify the adapter to reload data
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_upcoming_list)
    } catch (e: Exception) {
        android.util.Log.e("DailyRoutineWidget", "update error: ${e.message}")
    }
}

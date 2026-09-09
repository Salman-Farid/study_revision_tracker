package com.example.study_revision_tracker

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import android.app.PendingIntent

class DailyRoutineWidget : AppWidgetProvider() {

    private val handler = Handler(Looper.getMainLooper())
    private val timerUpdateRunnable = object : Runnable {
        override fun run() {
            val ctx = androidx.core.content.ContextCompat.getImplApplication(context)
            if (ctx != null) {
                val mgr = AppWidgetManager.getInstance(ctx)
                val ids = mgr.getAppWidgetIds(ComponentName(ctx, DailyRoutineWidget::class.java))
                for (id in ids) updateWidget(ctx, mgr, id, updateTimer = true)
            }
            handler.postDelayed(this, 60_000)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
        // Start periodic timer updates
        handler.removeCallbacks(timerUpdateRunnable)
        handler.postDelayed(timerUpdateRunnable, 60_000)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_REFRESH -> {
                val mgr = AppWidgetManager.getInstance(context)
                val ids = mgr.getAppWidgetIds(ComponentName(context, DailyRoutineWidget::class.java))
                for (id in ids) updateWidget(context, mgr, id)
            }
        }
    }

    companion object {
        const val ACTION_REFRESH = "com.example.study_revision_tracker.REFRESH_DAILY"
    }
}

private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, updateTimer: Boolean = false) {
    try {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val hasData = prefs.getString("widget_daily_has_data", "false") == "true"
        val statusMessage = prefs.getString("widget_daily_status_message", "No routine for today") ?: "No routine for today"
        val currentSubject = prefs.getString("widget_daily_current_subject", "") ?: ""
        val currentTopic = prefs.getString("widget_daily_current_topic", "") ?: ""
        val currentType = prefs.getString("widget_daily_current_type", "") ?: ""
        val currentTime = prefs.getString("widget_daily_current_time", "") ?: ""
        val remaining = prefs.getString("widget_daily_remaining", "") ?: ""
        val endTimestamp = prefs.getString("widget_daily_current_end_timestamp", "0")?.toLongOrNull() ?: 0L
        val upcomingJson = prefs.getString("widget_daily_upcoming_items", "[]") ?: "[]"
        val lastUpdated = prefs.getString("widget_last_updated", "") ?: ""

        val hasUpcoming = try {
            val arr = org.json.JSONArray(upcomingJson)
            arr.length() > 0
        } catch (_: Exception) { false }

        val hasCurrent = currentSubject.isNotEmpty() && endTimestamp > System.currentTimeMillis()

        val views = RemoteViews(context.packageName, R.layout.daily_routine_widget)

        // Current card
        if (hasCurrent) {
            views.setViewVisibility(R.id.widget_current_card, android.view.View.VISIBLE)
            views.setTextViewText(R.id.widget_current_subject, currentSubject)
            views.setTextViewText(R.id.widget_current_topic, currentTopic)
            views.setTextViewText(R.id.widget_current_type, currentType)
            views.setTextViewText(R.id.widget_current_timer, remaining)

            // Click to open app
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pending = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            views.setOnClickPendingIntent(R.id.widget_current_card, pending)
        } else {
            views.setViewVisibility(R.id.widget_current_card, android.view.View.GONE)
        }

        // Upcoming header — ONLY if there ARE upcoming items
        if (hasUpcoming && hasCurrent) {
            views.setViewVisibility(R.id.widget_upcoming_header, android.view.View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_upcoming_header, android.view.View.GONE)
        }

        // ListView for upcoming items
        val svcIntent = Intent(context, DailyRoutineWidgetListService::class.java).apply {
            putExtra("upcoming_json", upcomingJson)
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            data = Uri.parse(svcIntent.toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.widget_upcoming_list, svcIntent)
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
        }

        // Timestamp
        if (lastUpdated.isNotEmpty()) {
            val time = lastUpdated.substringAfter("T", "").take(5)
            views.setTextViewText(R.id.widget_updated, "Updated $time")
        }

        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_upcoming_list)
        appWidgetManager.updateAppWidget(appWidgetId, views)
    } catch (e: Exception) {
        android.util.Log.e("DailyRoutineWidget", "update error: ${e.message}")
    }
}

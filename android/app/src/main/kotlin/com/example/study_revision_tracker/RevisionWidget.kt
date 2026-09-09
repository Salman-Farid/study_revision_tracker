package com.example.study_revision_tracker

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import android.app.PendingIntent
import android.os.Build

class RevisionWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_TOGGLE_MODE -> {
                val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
                if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                    val currentMode = prefs.getString("widget_revision_toggle_mode", "missed")
                    val newMode = if (currentMode == "missed") "upcoming" else "missed"
                    prefs.edit().putString("widget_revision_toggle_mode", newMode).apply()
                    val mgr = AppWidgetManager.getInstance(context)
                    updateWidget(context, mgr, appWidgetId)
                }
            }
            ACTION_REFRESH -> {
                val mgr = AppWidgetManager.getInstance(context)
                val ids = mgr.getAppWidgetIds(ComponentName(context, RevisionWidget::class.java))
                for (id in ids) updateWidget(context, mgr, id)
            }
        }
    }

    companion object {
        const val ACTION_TOGGLE_MODE = "com.example.study_revision_tracker.TOGGLE_MODE"
        const val ACTION_REFRESH = "com.example.study_revision_tracker.REFRESH_REVISION"
    }
}

private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
    try {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val hasData = prefs.getString("widget_revision_has_data", "false") == "true"
        val statusMessage = prefs.getString("widget_revision_status_message", "Nothing for today") ?: "Nothing for today"
        val toggleMode = prefs.getString("widget_revision_toggle_mode", "missed") ?: "missed"
        val lastUpdated = prefs.getString("widget_last_updated", "") ?: ""

        // Determine which items to show (mutual exclusion: missed OR upcoming)
        val isMissedMode = toggleMode != "upcoming"
        val itemsJson: String
        val statusText: String
        val statusColorRes: Int

        if (isMissedMode) {
            itemsJson = prefs.getString("widget_revision_overdue_items", "[]") ?: "[]"
            val count = prefs.getString("widget_revision_overdue_count", "0")?.toIntOrNull() ?: 0
            statusText = if (count > 0) "Overdue" else "None overdue"
            statusColorRes = if (count > 0) R.drawable.badge_overdue_bg else R.drawable.badge_completed_bg
        } else {
            itemsJson = prefs.getString("widget_revision_upcoming_items", "[]") ?: "[]"
            val count = prefs.getString("widget_revision_upcoming_count", "0")?.toIntOrNull() ?: 0
            statusText = if (count > 0) "Upcoming" else "None upcoming"
            statusColorRes = if (count > 0) R.drawable.badge_upcoming_bg else R.drawable.badge_completed_bg
        }

        val hasItems = try {
            val arr = org.json.JSONArray(itemsJson)
            arr.length() > 0
        } catch (_: Exception) { false }

        val views = RemoteViews(context.packageName, R.layout.revision_widget)

        // Toggle button states
        if (isMissedMode) {
            views.setIntResource(R.id.btn_missed, "setBackgroundResource", R.drawable.btn_toggle_active)
            views.setInt(R.id.btn_missed, "setTextColor", android.graphics.Color.parseColor("#E0FFFFFF"))
            views.setIntResource(R.id.btn_coming_soon, "setBackgroundResource", R.drawable.btn_toggle_inactive)
            views.setInt(R.id.btn_coming_soon, "setTextColor", android.graphics.Color.parseColor("#80FFFFFF"))
        } else {
            views.setIntResource(R.id.btn_coming_soon, "setBackgroundResource", R.drawable.btn_toggle_active)
            views.setInt(R.id.btn_coming_soon, "setTextColor", android.graphics.Color.parseColor("#E0FFFFFF"))
            views.setIntResource(R.id.btn_missed, "setBackgroundResource", R.drawable.btn_toggle_inactive)
            views.setInt(R.id.btn_missed, "setTextColor", android.graphics.Color.parseColor("#80FFFFFF"))
        }

        // Status badge
        views.setTextViewText(R.id.widget_status, statusText)
        views.setIntResource(R.id.widget_status, "setBackgroundResource", statusColorRes)
        views.setViewVisibility(R.id.widget_status, if (hasItems || (!hasData && !isMissedMode)) android.view.View.GONE else android.view.View.VISIBLE)

        // Toggle click intents
        val toggleIntent = Intent(context, RevisionWidget::class.java).apply {
            action = RevisionWidget.ACTION_TOGGLE_MODE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        val togglePending = PendingIntent.getBroadcast(
            context, 0, toggleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.btn_missed, togglePending)
        views.setOnClickPendingIntent(R.id.btn_coming_soon, togglePending)

        // Empty state
        if (!hasData || !hasItems) {
            views.setViewVisibility(R.id.widget_list, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_empty, android.view.View.VISIBLE)
            views.setTextViewText(R.id.widget_empty_message, statusMessage)
        } else {
            views.setViewVisibility(R.id.widget_list, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.widget_empty, android.view.View.GONE)
        }

        // ListView
        val svcIntent = Intent(context, RevisionWidgetListService::class.java).apply {
            putExtra("is_missed_mode", isMissedMode)
            putExtra("items_json", itemsJson)
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            data = Uri.parse(svcIntent.toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.widget_list, svcIntent)
        views.setEmptyView(R.id.widget_list, R.id.widget_empty)

        // Timestamp
        if (lastUpdated.isNotEmpty()) {
            val time = lastUpdated.substringAfter("T", "").take(5)
            views.setTextViewText(R.id.widget_updated, "Updated $time")
        }

        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list)
        appWidgetManager.updateAppWidget(appWidgetId, views)
    } catch (e: Exception) {
        android.util.Log.e("RevisionWidget", "update error: ${e.message}")
    }
}

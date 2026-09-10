package com.example.study_revision_tracker

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.app.PendingIntent

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
                    val targetMode = intent.getStringExtra(EXTRA_TARGET_MODE)
                        ?: run {
                            val currentMode = prefs.getString("widget_revision_toggle_mode", "missed")
                            if (currentMode == "missed") "upcoming" else "missed"
                        }
                    prefs.edit().putString("widget_revision_toggle_mode", targetMode).apply()
                    val mgr = AppWidgetManager.getInstance(context)
                    updateWidget(context, mgr, appWidgetId)
                }
            }
            ACTION_REFRESH,
            "com.example.study_revision_tracker.UPDATE_WIDGETS",
            AppWidgetManager.ACTION_APPWIDGET_UPDATE -> {
                val mgr = AppWidgetManager.getInstance(context)
                val ids = mgr.getAppWidgetIds(ComponentName(context, RevisionWidget::class.java))
                for (id in ids) updateWidget(context, mgr, id)
            }
        }
    }

    companion object {
        const val ACTION_TOGGLE_MODE = "com.example.study_revision_tracker.TOGGLE_MODE"
        const val ACTION_REFRESH = "com.example.study_revision_tracker.REFRESH_REVISION"
        const val EXTRA_TARGET_MODE = "target_mode"
    }
}

private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
    try {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val hasData = prefs.getString("widget_revision_has_data", "false") == "true"
        // Never surface a raw error string on the home screen.
        var statusMessage = prefs.getString("widget_revision_status_message", "Nothing planned yet") ?: "Nothing planned yet"
        if (statusMessage.isBlank() || statusMessage.contains("Error", ignoreCase = true)) {
            statusMessage = "Nothing planned yet"
        }
        val toggleMode = prefs.getString("widget_revision_toggle_mode", "missed") ?: "missed"
        val lastUpdated = prefs.getString("widget_last_updated", "") ?: ""

        val overdueCount = prefs.getString("widget_revision_overdue_count", "0")?.toIntOrNull() ?: 0
        val upcomingCount = prefs.getString("widget_revision_upcoming_count", "0")?.toIntOrNull() ?: 0

        val isMissedMode = toggleMode != "upcoming"
        val itemsJson: String
        val statusText: String
        val statusColorRes: Int
        val statusTextColor: String

        if (isMissedMode) {
            itemsJson = prefs.getString("widget_revision_overdue_items", "[]") ?: "[]"
            statusText = if (overdueCount > 0) "Overdue" else "None overdue"
            statusColorRes = if (overdueCount > 0) R.drawable.badge_overdue_bg else R.drawable.badge_completed_bg
            statusTextColor = if (overdueCount > 0) "#D93025" else "#1E8E3E"
        } else {
            itemsJson = prefs.getString("widget_revision_upcoming_items", "[]") ?: "[]"
            statusText = if (upcomingCount > 0) "Upcoming" else "None upcoming"
            statusColorRes = if (upcomingCount > 0) R.drawable.badge_upcoming_bg else R.drawable.badge_completed_bg
            statusTextColor = if (upcomingCount > 0) "#1E8E3E" else "#1E8E3E"
        }

        val hasItems = try {
            val arr = org.json.JSONArray(itemsJson)
            arr.length() > 0
        } catch (_: Exception) { false }

        // Friendly empty message — never "error"
        val emptyMessage = when {
            hasItems -> statusMessage
            isMissedMode && overdueCount == 0 && upcomingCount == 0 -> "Nothing planned yet"
            isMissedMode -> "None overdue"
            upcomingCount == 0 -> "Nothing planned yet"
            else -> "None upcoming"
        }

        val views = RemoteViews(context.packageName, R.layout.revision_widget)

        views.setTextViewText(R.id.btn_missed, "MISSED ($overdueCount)")
        views.setTextViewText(R.id.btn_coming_soon, "COMING SOON ($upcomingCount)")
        if (isMissedMode) {
            views.setInt(R.id.btn_missed, "setBackgroundResource", R.drawable.btn_toggle_active)
            views.setInt(R.id.btn_missed, "setTextColor", android.graphics.Color.parseColor("#FFFFFF"))
            views.setInt(R.id.btn_coming_soon, "setBackgroundResource", R.drawable.btn_toggle_inactive)
            views.setInt(R.id.btn_coming_soon, "setTextColor", android.graphics.Color.parseColor("#80000000"))
        } else {
            views.setInt(R.id.btn_coming_soon, "setBackgroundResource", R.drawable.btn_toggle_active)
            views.setInt(R.id.btn_coming_soon, "setTextColor", android.graphics.Color.parseColor("#FFFFFF"))
            views.setInt(R.id.btn_missed, "setBackgroundResource", R.drawable.btn_toggle_inactive)
            views.setInt(R.id.btn_missed, "setTextColor", android.graphics.Color.parseColor("#80000000"))
        }

        views.setTextViewText(R.id.widget_status, statusText)
        views.setInt(R.id.widget_status, "setBackgroundResource", statusColorRes)
        views.setInt(R.id.widget_status, "setTextColor", android.graphics.Color.parseColor(statusTextColor))
        views.setViewVisibility(R.id.widget_status, if (hasItems) android.view.View.GONE else android.view.View.VISIBLE)

        val missedIntent = Intent(context, RevisionWidget::class.java).apply {
            action = RevisionWidget.ACTION_TOGGLE_MODE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            putExtra(RevisionWidget.EXTRA_TARGET_MODE, "missed")
        }
        val missedPending = PendingIntent.getBroadcast(
            context, appWidgetId, missedIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.btn_missed, missedPending)

        val upcomingIntent = Intent(context, RevisionWidget::class.java).apply {
            action = RevisionWidget.ACTION_TOGGLE_MODE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            putExtra(RevisionWidget.EXTRA_TARGET_MODE, "upcoming")
        }
        val upcomingPending = PendingIntent.getBroadcast(
            context, 100000 + appWidgetId, upcomingIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.btn_coming_soon, upcomingPending)

        val adapterIntent = Intent(context, RevisionWidgetService::class.java)
        adapterIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        adapterIntent.action = "android.appwidget.action.APPWIDGET_UPDATE"
        views.setRemoteAdapter(R.id.widget_list, adapterIntent)

        views.setEmptyView(R.id.widget_list, R.id.widget_empty)

        if (!hasItems) {
            views.setViewVisibility(R.id.widget_list, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_empty, android.view.View.VISIBLE)
            views.setTextViewText(R.id.widget_empty_message, emptyMessage)
        } else {
            views.setViewVisibility(R.id.widget_list, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.widget_empty, android.view.View.GONE)
        }

        if (lastUpdated.isNotEmpty()) {
            val time = lastUpdated.substringAfter("T", "").take(5)
            if (time.isNotEmpty()) {
                views.setTextViewText(R.id.widget_updated, "Updated $time")
            }
        }

        // Deep-link to Today tab
        val openIntent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse("study-revision-tracker://today"))
        openIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        val openPending = PendingIntent.getActivity(
            context, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, openPending)

        appWidgetManager.updateAppWidget(appWidgetId, views)
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list)
    } catch (e: Exception) {
        android.util.Log.e("RevisionWidget", "update error: ${e.message}")
        try {
            val views = RemoteViews(context.packageName, R.layout.revision_widget)
            views.setViewVisibility(R.id.widget_list, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_empty, android.view.View.VISIBLE)
            views.setTextViewText(R.id.widget_empty_message, "Nothing planned yet")
            appWidgetManager.updateAppWidget(appWidgetId, views)
        } catch (_: Exception) {}
    }
}

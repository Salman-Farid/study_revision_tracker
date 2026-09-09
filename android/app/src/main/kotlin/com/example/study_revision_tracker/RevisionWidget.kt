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
                    // Set the mode of the button that was actually pressed.
                    // Falls back to flipping the current mode if the extra is missing.
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
        const val EXTRA_TARGET_MODE = "target_mode"
    }
}

private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
    try {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val hasData = prefs.getString("widget_revision_has_data", "false") == "true"
        val statusMessage = prefs.getString("widget_revision_status_message", "Nothing for today") ?: "Nothing for today"
        val toggleMode = prefs.getString("widget_revision_toggle_mode", "missed") ?: "missed"
        val lastUpdated = prefs.getString("widget_last_updated", "") ?: ""

        // Counts for both sections (shown on the toggle buttons)
        val overdueCount = prefs.getString("widget_revision_overdue_count", "0")?.toIntOrNull() ?: 0
        val upcomingCount = prefs.getString("widget_revision_upcoming_count", "0")?.toIntOrNull() ?: 0

        // Determine which items to show (mutual exclusion: missed OR upcoming)
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

        val views = RemoteViews(context.packageName, R.layout.revision_widget)

        // Toggle button labels with counts + states (white theme:
        // active = solid blue with white text, inactive = gray text)
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

        // Status badge (colorful text on light tinted background)
        views.setTextViewText(R.id.widget_status, statusText)
        views.setInt(R.id.widget_status, "setBackgroundResource", statusColorRes)
        views.setInt(R.id.widget_status, "setTextColor", android.graphics.Color.parseColor(statusTextColor))
        views.setViewVisibility(R.id.widget_status, if (hasItems || (!hasData && !isMissedMode)) android.view.View.GONE else android.view.View.VISIBLE)

        // Toggle click intents — one per button, each carrying its own target
        // mode, so pressing MISSED shows missed and COMING SOON shows upcoming.
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

        // Content rows — rendered directly with RemoteViews.addView().
        // No ListView/adapter/service → no "Loading…" placeholder, ever.
        views.removeAllViews(R.id.widget_list)
        if (!hasData || !hasItems) {
            views.setViewVisibility(R.id.widget_list, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_empty, android.view.View.VISIBLE)
            views.setTextViewText(R.id.widget_empty_message, statusMessage)
        } else {
            views.setViewVisibility(R.id.widget_list, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.widget_empty, android.view.View.GONE)
            try {
                val arr = org.json.JSONArray(itemsJson)
                val maxItems = 5
                for (i in 0 until minOf(arr.length(), maxItems)) {
                    views.addView(R.id.widget_list, buildRevisionRow(context, arr.getJSONObject(i), isMissedMode))
                }
                if (arr.length() > maxItems) {
                    val more = RemoteViews(context.packageName, R.layout.widget_more_row)
                    more.setTextViewText(R.id.more_text, "+${arr.length() - maxItems} more")
                    views.addView(R.id.widget_list, more)
                }
            } catch (e: Exception) {
                android.util.Log.e("RevisionWidget", "row build failed: ${e.message}")
            }
        }

        // Timestamp
        if (lastUpdated.isNotEmpty()) {
            val time = lastUpdated.substringAfter("T", "").take(5)
            views.setTextViewText(R.id.widget_updated, "Updated $time")
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    } catch (e: Exception) {
        android.util.Log.e("RevisionWidget", "update error: ${e.message}")
    }
}

/** Builds one revision row (topic + subject + date/label badge). */
private fun buildRevisionRow(context: Context, item: org.json.JSONObject, isMissedMode: Boolean): RemoteViews {
    val row = RemoteViews(context.packageName, R.layout.revision_widget_item)
    row.setTextViewText(R.id.item_name, item.optString("topicName", "Unknown"))
    row.setTextViewText(R.id.item_subject, item.optString("subjectName", ""))
    val dayLabel = if (isMissedMode) {
        item.optString("scheduledDate", item.optString("dayLabel", ""))
    } else {
        item.optString("dayLabel", "")
    }
    row.setTextViewText(R.id.item_day_badge, dayLabel)

    // Color coding: red for overdue, blue for upcoming (white theme)
    if (isMissedMode) {
        row.setInt(R.id.item_dot, "setBackgroundResource", R.drawable.dot_circle_overdue)
        row.setInt(R.id.item_day_badge, "setBackgroundResource", R.drawable.badge_overdue_bg)
        row.setTextColor(R.id.item_day_badge, android.graphics.Color.parseColor("#D93025"))
    } else {
        row.setInt(R.id.item_dot, "setBackgroundResource", R.drawable.dot_circle_today)
        row.setInt(R.id.item_day_badge, "setBackgroundResource", R.drawable.badge_today_bg)
        row.setTextColor(R.id.item_day_badge, android.graphics.Color.parseColor("#1A73E8"))
    }
    return row
}

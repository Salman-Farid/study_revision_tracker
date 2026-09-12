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
                    val targetMode = normalizeMode(
                        intent.getStringExtra(EXTRA_TARGET_MODE)
                            ?: run {
                                val currentMode = prefs.getString(KEY_TOGGLE_MODE, MODE_TODAY) ?: MODE_TODAY
                                when (currentMode) {
                                    MODE_TODAY -> MODE_MISSED
                                    MODE_MISSED -> MODE_UPCOMING
                                    else -> MODE_TODAY
                                }
                            }
                    )
                    prefs.edit().putString(KEY_TOGGLE_MODE, targetMode).apply()
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
        const val KEY_TOGGLE_MODE = "widget_revision_toggle_mode"
        const val MODE_TODAY = "today"
        const val MODE_MISSED = "missed"
        const val MODE_UPCOMING = "upcoming"

        fun normalizeMode(raw: String?): String = when (raw) {
            MODE_TODAY, MODE_MISSED, MODE_UPCOMING -> raw
            // Legacy values from older builds.
            "coming_soon", "comingup", "coming-up" -> MODE_UPCOMING
            else -> MODE_TODAY
        }
    }
}

private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
    try {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        var statusMessage = prefs.getString("widget_revision_status_message", "Nothing planned yet") ?: "Nothing planned yet"
        if (statusMessage.isBlank() || statusMessage.contains("Error", ignoreCase = true)) {
            statusMessage = "Nothing planned yet"
        }
        val toggleMode = RevisionWidget.normalizeMode(prefs.getString(RevisionWidget.KEY_TOGGLE_MODE, RevisionWidget.MODE_TODAY))
        val lastUpdated = prefs.getString("widget_last_updated", "") ?: ""

        val overdueCount = prefs.getString("widget_revision_overdue_count", "0")?.toIntOrNull() ?: 0
        val todayCount = prefs.getString("widget_revision_today_count", "0")?.toIntOrNull() ?: 0
        val upcomingCount = prefs.getString("widget_revision_upcoming_count", "0")?.toIntOrNull() ?: 0

        val itemsJson: String

        when (toggleMode) {
            RevisionWidget.MODE_MISSED -> {
                itemsJson = prefs.getString("widget_revision_overdue_items", "[]") ?: "[]"
            }
            RevisionWidget.MODE_UPCOMING -> {
                itemsJson = prefs.getString("widget_revision_upcoming_items", "[]") ?: "[]"
            }
            else -> {
                itemsJson = prefs.getString("widget_revision_today_items", "[]") ?: "[]"
            }
        }

        val hasItems = try {
            val arr = org.json.JSONArray(itemsJson)
            arr.length() > 0
        } catch (_: Exception) { false }

        val emptyMessage = when {
            hasItems -> statusMessage
            overdueCount == 0 && todayCount == 0 && upcomingCount == 0 -> "Nothing planned yet"
            toggleMode == RevisionWidget.MODE_MISSED -> "None overdue"
            toggleMode == RevisionWidget.MODE_TODAY -> "None due today"
            else -> "None coming up"
        }

        val views = RemoteViews(context.packageName, R.layout.revision_widget)

        views.setTextViewText(R.id.btn_today, "TODAY ($todayCount)")
        views.setTextViewText(R.id.btn_missed, "MISSED ($overdueCount)")
        views.setTextViewText(R.id.btn_coming_up, "COMING UP ($upcomingCount)")

        val activeColor = android.graphics.Color.parseColor("#FFFFFF")
        val inactiveColor = android.graphics.Color.parseColor("#80000000")

        fun setBtn(id: Int, active: Boolean) {
            views.setInt(id, "setBackgroundResource", if (active) R.drawable.btn_toggle_active else R.drawable.btn_toggle_inactive)
            views.setInt(id, "setTextColor", if (active) activeColor else inactiveColor)
        }
        setBtn(R.id.btn_today, toggleMode == RevisionWidget.MODE_TODAY)
        setBtn(R.id.btn_missed, toggleMode == RevisionWidget.MODE_MISSED)
        setBtn(R.id.btn_coming_up, toggleMode == RevisionWidget.MODE_UPCOMING)

        views.setViewVisibility(R.id.widget_status, android.view.View.GONE)

        fun modePending(mode: String, requestCode: Int): PendingIntent {
            val i = Intent(context, RevisionWidget::class.java).apply {
                action = RevisionWidget.ACTION_TOGGLE_MODE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                putExtra(RevisionWidget.EXTRA_TARGET_MODE, mode)
            }
            return PendingIntent.getBroadcast(
                context, requestCode, i,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        views.setOnClickPendingIntent(R.id.btn_today, modePending(RevisionWidget.MODE_TODAY, appWidgetId))
        views.setOnClickPendingIntent(R.id.btn_missed, modePending(RevisionWidget.MODE_MISSED, 100000 + appWidgetId))
        views.setOnClickPendingIntent(R.id.btn_coming_up, modePending(RevisionWidget.MODE_UPCOMING, 200000 + appWidgetId))

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

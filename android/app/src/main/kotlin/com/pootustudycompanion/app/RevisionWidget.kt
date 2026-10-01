package com.pootustudycompanion.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray

/**
 * Revision home-screen widget.
 *
 * RemoteViews only allows a small set of view classes. Never put
 * HorizontalScrollView (or similar) in the layout — the launcher throws
 * "Class not allowed to be inflated" and shows "Can't load widget".
 */
class RevisionWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            render(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_TOGGLE_MODE -> {
                val appWidgetId = intent.getIntExtra(
                    AppWidgetManager.EXTRA_APPWIDGET_ID,
                    AppWidgetManager.INVALID_APPWIDGET_ID,
                )
                if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    val current = prefs.getString(KEY_TOGGLE_MODE, MODE_TODAY)
                    val targetMode = normalizeMode(
                        intent.getStringExtra(EXTRA_TARGET_MODE) ?: nextMode(current),
                    )
                    prefs.edit().putString(KEY_TOGGLE_MODE, targetMode).apply()
                    render(context, AppWidgetManager.getInstance(context), appWidgetId)
                }
            }
            ACTION_REFRESH,
            "com.pootustudycompanion.app.UPDATE_WIDGETS",
            AppWidgetManager.ACTION_APPWIDGET_UPDATE -> {
                val mgr = AppWidgetManager.getInstance(context)
                val ids = mgr.getAppWidgetIds(ComponentName(context, RevisionWidget::class.java))
                for (id in ids) render(context, mgr, id)
            }
        }
    }

    companion object {
        private const val TAG = "RevisionWidget"
        private const val PREFS = "HomeWidgetPreferences"
        const val ACTION_TOGGLE_MODE = "com.pootustudycompanion.app.TOGGLE_MODE"
        const val ACTION_REFRESH = "com.pootustudycompanion.app.REFRESH_REVISION"
        const val EXTRA_TARGET_MODE = "target_mode"
        const val KEY_TOGGLE_MODE = "widget_revision_toggle_mode"
        const val MODE_TODAY = "today"
        const val MODE_MISSED = "missed"
        const val MODE_UPCOMING = "upcoming"

        fun normalizeMode(raw: String?): String = when (raw) {
            MODE_TODAY, MODE_MISSED, MODE_UPCOMING -> raw
            "coming_soon", "comingup", "coming-up" -> MODE_UPCOMING
            else -> MODE_TODAY
        }

        private fun nextMode(current: String?): String = when (current) {
            MODE_TODAY -> MODE_MISSED
            MODE_MISSED -> MODE_UPCOMING
            else -> MODE_TODAY
        }

        private fun readCount(prefs: android.content.SharedPreferences, key: String): Int =
            (prefs.getString(key, "0") ?: "0").toIntOrNull() ?: 0

        private fun readListJson(prefs: android.content.SharedPreferences, key: String): String {
            val raw = prefs.getString(key, "[]") ?: "[]"
            return if (raw.isBlank() || raw == "null") "[]" else raw
        }

        private fun listHasItems(json: String): Boolean = try {
            JSONArray(json).length() > 0
        } catch (_: Exception) {
            false
        }

        fun render(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.revision_widget)
            try {
                val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

                var statusMessage =
                    prefs.getString("widget_revision_status_message", "Nothing planned yet")
                        ?: "Nothing planned yet"
                if (statusMessage.isBlank() ||
                    statusMessage.contains("Error", ignoreCase = true)
                ) {
                    statusMessage = "Nothing planned yet"
                }

                val toggleMode = normalizeMode(prefs.getString(KEY_TOGGLE_MODE, MODE_TODAY))

                val overdueCount = readCount(prefs, "widget_revision_overdue_count")
                val todayCount = readCount(prefs, "widget_revision_today_count")
                val upcomingCount = readCount(prefs, "widget_revision_upcoming_count")

                val itemsJson = when (toggleMode) {
                    MODE_MISSED -> readListJson(prefs, "widget_revision_overdue_items")
                    MODE_UPCOMING -> readListJson(prefs, "widget_revision_upcoming_items")
                    else -> readListJson(prefs, "widget_revision_today_items")
                }
                val hasItems = listHasItems(itemsJson)

                // Selected tab is color-only — no bullet/indicator.
                views.setTextViewText(R.id.btn_today, "TODAY ($todayCount)")
                views.setTextViewText(R.id.btn_missed, "MISSED ($overdueCount)")
                views.setTextViewText(R.id.btn_coming_up, "UPCOMING ($upcomingCount)")

                val activeColor = android.graphics.Color.parseColor("#1A73E8")
                val inactiveColor = android.graphics.Color.parseColor("#80000000")
                views.setTextColor(R.id.btn_today, if (toggleMode == MODE_TODAY) activeColor else inactiveColor)
                views.setTextColor(R.id.btn_missed, if (toggleMode == MODE_MISSED) activeColor else inactiveColor)
                views.setTextColor(R.id.btn_coming_up, if (toggleMode == MODE_UPCOMING) activeColor else inactiveColor)

                fun modePending(mode: String, requestCode: Int): PendingIntent {
                    val i = Intent(context, RevisionWidget::class.java).apply {
                        action = ACTION_TOGGLE_MODE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                        putExtra(EXTRA_TARGET_MODE, mode)
                    }
                    return PendingIntent.getBroadcast(
                        context, requestCode, i,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    )
                }
                views.setOnClickPendingIntent(R.id.btn_today, modePending(MODE_TODAY, appWidgetId))
                views.setOnClickPendingIntent(R.id.btn_missed, modePending(MODE_MISSED, 100000 + appWidgetId))
                views.setOnClickPendingIntent(R.id.btn_coming_up, modePending(MODE_UPCOMING, 200000 + appWidgetId))

                val adapterIntent = Intent(context, RevisionWidgetService::class.java)
                adapterIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                adapterIntent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                views.setRemoteAdapter(R.id.widget_list, adapterIntent)
                views.setEmptyView(R.id.widget_list, R.id.widget_empty)

                val emptyMessage = when {
                    hasItems -> statusMessage
                    overdueCount == 0 && todayCount == 0 && upcomingCount == 0 ->
                        "Nothing planned yet"
                    toggleMode == MODE_MISSED -> "None overdue"
                    toggleMode == MODE_TODAY -> "None due today"
                    else -> "None coming up"
                }

                if (!hasItems) {
                    views.setViewVisibility(R.id.widget_list, View.GONE)
                    views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                    views.setTextViewText(R.id.widget_empty, emptyMessage)
                } else {
                    views.setViewVisibility(R.id.widget_list, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_empty, View.GONE)
                }

                val openIntent = Intent(
                    Intent.ACTION_VIEW,
                    android.net.Uri.parse("study-revision-tracker://today"),
                ).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                    setPackage(context.packageName)
                }
                views.setOnClickPendingIntent(
                    R.id.widget_root,
                    PendingIntent.getActivity(
                        context, 0, openIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                )

                appWidgetManager.updateAppWidget(appWidgetId, views)
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list)
                Log.d(TAG, "render ok id=$appWidgetId hasItems=$hasItems mode=$toggleMode")
            } catch (e: Exception) {
                Log.e(TAG, "render failed id=$appWidgetId: ${e.message}", e)
                try {
                    views.setViewVisibility(R.id.widget_list, View.GONE)
                    views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                    views.setTextViewText(R.id.widget_empty, "Nothing planned yet")
                    appWidgetManager.updateAppWidget(appWidgetId, views)
                } catch (_: Exception) {
                }
            }
        }
    }
}

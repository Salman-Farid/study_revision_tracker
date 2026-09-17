package com.example.study_revision_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray

/**
 * Class-routine widget. Shows today's classes only.
 * List body is a scrollable ListView (RemoteViewsAdapter).
 * NOW header, empty state, and footer stay outside the list.
 */
class ClassRoutineWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) render(context, manager, id)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        render(context, appWidgetManager, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        if (action == ACTION_REFRESH ||
            action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            action == "com.example.study_revision_tracker.UPDATE_WIDGETS"
        ) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, ClassRoutineWidget::class.java))
            for (id in ids) render(context, mgr, id)
            return
        }
        super.onReceive(context, intent)
    }

    companion object {
        private const val TAG = "ClassRoutineWidget"
        const val ACTION_REFRESH = "com.example.study_revision_tracker.REFRESH_CLASS"
        private const val MIN_WIDTH_FOR_DURATION = 250

        private val PALETTE = intArrayOf(
            0xFF1A73E8.toInt(),
            0xFF6A1B9A.toInt(),
            0xFFC62828.toInt(),
            0xFF00897B.toInt(),
            0xFFEF6C00.toInt(),
            0xFF2E7D32.toInt(),
            0xFFAD1457.toInt(),
            0xFF4527A0.toInt(),
        )

        fun render(context: Context, manager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.class_routine_widget)
            try {
                val prefs =
                    context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

                val options = manager.getAppWidgetOptions(appWidgetId)
                val minW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
                val showDuration = minW >= MIN_WIDTH_FOR_DURATION
                // Factory reads this to show/hide the duration pill.
                prefs.edit().putString("widget_class_show_duration", showDuration.toString()).apply()

                var itemsJson = prefs.getString("widget_class_today_items", null)
                if (itemsJson == null) {
                    val all = prefs.getString("widget_class_items", "[]") ?: "[]"
                    itemsJson = filterToday(all)
                }

                val arr = try { JSONArray(itemsJson) } catch (_: Exception) { JSONArray() }
                val count = arr.length()
                val nowMs = System.currentTimeMillis()

                var nowShown = false

                for (i in 0 until count) {
                    val o = arr.getJSONObject(i)
                    val startTs = o.optLong("startTimestamp", 0L)
                    val endTs = o.optLong("endTimestamp", 0L)
                    val isNow = o.optBoolean("isCurrent", false) ||
                        (startTs > 0L && endTs > 0L && nowMs in startTs until endTs)
                    if (isNow) {
                        if (!nowShown) {
                            nowShown = true
                            val subject = o.optString("subject", "")
                            val timeText = o.optString("timeText", "")
                            val endText = o.optString("endTimeText", "")
                            val location = o.optString("location", "")
                            val timeLine = if (endText.isNotEmpty()) "$timeText – $endText" else timeText
                            val subCol = PALETTE[i % PALETTE.size]
                            val timeCol = 0xFF5C6BC0.toInt()
                            val locCol = 0xFFEF6C00.toInt()

                            views.setViewVisibility(R.id.widget_now_label, View.VISIBLE)
                            views.setViewVisibility(R.id.widget_now_subject, View.VISIBLE)
                            views.setViewVisibility(R.id.widget_now_time, View.VISIBLE)
                            views.setTextViewText(R.id.widget_now_subject, subject)
                            views.setTextViewText(R.id.widget_now_time, timeLine)
                            if (location.isNotEmpty()) {
                                views.setViewVisibility(R.id.widget_now_location, View.VISIBLE)
                                views.setTextViewText(R.id.widget_now_location, location)
                            } else {
                                views.setViewVisibility(R.id.widget_now_location, View.GONE)
                            }
                            views.setTextColor(R.id.widget_now_subject, subCol)
                            views.setTextColor(R.id.widget_now_time, timeCol)
                            views.setTextColor(R.id.widget_now_location, locCol)
                        }
                    }
                }

                if (!nowShown) {
                    views.setViewVisibility(R.id.widget_now_label, View.GONE)
                    views.setViewVisibility(R.id.widget_now_subject, View.GONE)
                    views.setViewVisibility(R.id.widget_now_time, View.GONE)
                    views.setViewVisibility(R.id.widget_now_location, View.GONE)
                }

                val adapterIntent = Intent(context, ClassRoutineWidgetService::class.java)
                adapterIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                adapterIntent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                views.setRemoteAdapter(R.id.widget_class_list, adapterIntent)

                if (count == 0) {
                    views.setViewVisibility(R.id.widget_class_list, View.GONE)
                    views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                    views.setTextViewText(R.id.widget_empty, "Nothing to show\nNo classes today")
                } else {
                    // List is visible even when only the NOW card is present
                    // (factory skips the current class, so rows may be 0).
                    views.setViewVisibility(R.id.widget_class_list, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_empty, View.GONE)
                }

                val open = Intent(
                    Intent.ACTION_VIEW,
                    Uri.parse("study-revision-tracker://routine")
                ).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                    setPackage(context.packageName)
                }
                val pi = PendingIntent.getActivity(
                    context, 0, open,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pi)

                manager.updateAppWidget(appWidgetId, views)
                manager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_class_list)
            } catch (e: Exception) {
                Log.e(TAG, "render failed id=$appWidgetId", e)
                try {
                    views.setViewVisibility(R.id.widget_now_label, View.GONE)
                    views.setViewVisibility(R.id.widget_now_subject, View.GONE)
                    views.setViewVisibility(R.id.widget_now_time, View.GONE)
                    views.setViewVisibility(R.id.widget_now_location, View.GONE)
                    views.setViewVisibility(R.id.widget_class_list, View.GONE)
                    views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                    views.setTextViewText(R.id.widget_empty, "Nothing to show")
                    manager.updateAppWidget(appWidgetId, views)
                } catch (_: Exception) {
                }
            }
        }

        private fun filterToday(allJson: String): String {
            return try {
                val src = JSONArray(allJson)
                val out = JSONArray()
                for (i in 0 until src.length()) {
                    val o = src.getJSONObject(i)
                    if (o.optBoolean("isToday", false) || o.optBoolean("isCurrent", false)) {
                        out.put(o)
                    }
                }
                out.toString()
            } catch (_: Exception) {
                "[]"
            }
        }
    }
}

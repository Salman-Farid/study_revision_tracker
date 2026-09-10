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
 * Minimal class-routine widget. Shows today's classes only.
 * Layout is TextView-only (no vectors / ImageViews) so Samsung
 * launchers never hit "Can't load widget" from inflate failures.
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
        /** Below this min-width (dp), hide the duration pill to keep the row readable. */
        private const val MIN_WIDTH_FOR_DURATION = 250

        // Vivid subject/title colors (ARGB).
        private val PALETTE = intArrayOf(
            0xFF1A73E8.toInt(), // blue
            0xFF6A1B9A.toInt(), // purple
            0xFFC62828.toInt(), // red
            0xFF00897B.toInt(), // teal
            0xFFEF6C00.toInt(), // orange
            0xFF2E7D32.toInt(), // green
            0xFFAD1457.toInt(), // pink
            0xFF4527A0.toInt(), // indigo
        )
        private val META_PALETTE = intArrayOf(
            0xFF0277BD.toInt(),
            0xFF8E24AA.toInt(),
            0xFFE53935.toInt(),
            0xFF00897B.toInt(),
            0xFFFB8C00.toInt(),
            0xFF43A047.toInt(),
            0xFFD81B60.toInt(),
            0xFF5E35B1.toInt(),
        )

        fun render(context: Context, manager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.class_routine_widget)
            try {
                val prefs =
                    context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)

                // Hide duration pill when the widget is resized narrow.
                val options = manager.getAppWidgetOptions(appWidgetId)
                val minW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
                val showDuration = minW >= MIN_WIDTH_FOR_DURATION

                // Prefer today's items; fall back to full list filtered by isToday.
                var itemsJson = prefs.getString("widget_class_today_items", null)
                if (itemsJson == null) {
                    val all = prefs.getString("widget_class_items", "[]") ?: "[]"
                    itemsJson = filterToday(all)
                }

                val arr = try { JSONArray(itemsJson) } catch (_: Exception) { JSONArray() }
                val count = arr.length()

                views.removeAllViews(R.id.widget_class_list)

                if (count == 0) {
                    views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_now_label, View.GONE)
                    views.setViewVisibility(R.id.widget_now_subject, View.GONE)
                    views.setViewVisibility(R.id.widget_now_time, View.GONE)
                    views.setViewVisibility(R.id.widget_now_location, View.GONE)
                    views.setTextViewText(R.id.widget_footer, "")
                } else {
                    views.setViewVisibility(R.id.widget_empty, View.GONE)

                    var nowShown = false
                    val nowMs = System.currentTimeMillis()

                    for (i in 0 until count.coerceAtMost(8)) {
                        val o = arr.getJSONObject(i)
                        val subject = o.optString("subject", "")
                        val timeText = o.optString("timeText", "")
                        val endText = o.optString("endTimeText", "")
                        val location = o.optString("location", "")
                        val startTs = o.optLong("startTimestamp", 0L)
                        val endTs = o.optLong("endTimestamp", 0L)
                        val isNow = o.optBoolean("isCurrent", false) ||
                            (startTs > 0L && endTs > 0L && nowMs in startTs until endTs)
                        val isPast = o.optBoolean("isPast", false) ||
                            (endTs > 0L && nowMs >= endTs)

                        val timeLine = if (endText.isNotEmpty()) "$timeText – $endText" else timeText
                        val timeCol: Int = if (isPast) 0x66000000.toInt() else 0xFF5C6BC0.toInt()
                        val locCol: Int = if (isPast) 0x66000000.toInt() else 0xFFEF6C00.toInt()
                        val subCol: Int = if (isPast) 0x88000000.toInt() else PALETTE[i % PALETTE.size]

                        if (isNow && !nowShown) {
                            nowShown = true
                            views.setViewVisibility(R.id.widget_now_label, View.VISIBLE)
                            views.setViewVisibility(R.id.widget_now_subject, View.VISIBLE)
                            views.setViewVisibility(R.id.widget_now_time, View.VISIBLE)
                            views.setTextViewText(R.id.widget_now_subject, subject)
                            views.setTextViewText(R.id.widget_now_time, timeLine + if (isPast) "  ·  Done" else "")
                            if (location.isNotEmpty()) {
                                views.setViewVisibility(R.id.widget_now_location, View.VISIBLE)
                                views.setTextViewText(R.id.widget_now_location, location)
                            } else {
                                views.setViewVisibility(R.id.widget_now_location, View.GONE)
                            }
                            views.setTextColor(R.id.widget_now_subject, subCol)
                            views.setTextColor(R.id.widget_now_time, timeCol)
                            views.setTextColor(R.id.widget_now_location, locCol)
                            continue
                        }

                        val row = RemoteViews(context.packageName, R.layout.class_routine_widget_item)
                        row.setTextViewText(R.id.row_subject, subject)
                        row.setTextViewText(R.id.row_time, timeLine + if (isPast) "  ·  Done" else "")
                        if (location.isNotEmpty()) {
                            row.setViewVisibility(R.id.row_location, View.VISIBLE)
                            row.setTextViewText(R.id.row_location, location)
                        } else {
                            row.setViewVisibility(R.id.row_location, View.GONE)
                        }

                        // Duration pill on the right
                        val durMin = o.optInt("durationMinutes", 0)
                        val durText = when {
                            durMin > 0 -> {
                                val hours = durMin / 60.0
                                if (durMin % 60 == 0 && durMin >= 60) "${durMin / 60} hours"
                                else if (hours >= 1) {
                                    val formatted = String.format(java.util.Locale.US, "%.1f", hours)
                                    "${formatted} hours"
                                } else "$durMin min"
                            }
                            o.optString("durationText", "").isNotEmpty() -> o.optString("durationText")
                            else -> ""
                        }
                        if (showDuration && durText.isNotEmpty()) {
                            row.setViewVisibility(R.id.row_duration_box, View.VISIBLE)
                            row.setTextViewText(R.id.row_duration, durText)
                            row.setTextColor(R.id.row_duration, subCol)
                        } else {
                            row.setViewVisibility(R.id.row_duration_box, View.GONE)
                        }

                        row.setTextColor(R.id.row_subject, subCol)
                        row.setTextColor(R.id.row_time, timeCol)
                        row.setTextColor(R.id.row_location, locCol)
                        views.addView(R.id.widget_class_list, row)
                    }

                    val lastUpdated = prefs.getString("widget_last_updated", "") ?: ""
                    val t = lastUpdated.substringAfter("T", "").take(5)
                    views.setTextViewText(
                        R.id.widget_footer,
                        if (t.isNotEmpty()) "Updated $t" else "$count class(es) today"
                    )
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
            } catch (e: Exception) {
                Log.e(TAG, "render failed id=$appWidgetId", e)
                try {
                    views.removeAllViews(R.id.widget_class_list)
                    views.setViewVisibility(R.id.widget_now_label, View.GONE)
                    views.setViewVisibility(R.id.widget_now_subject, View.GONE)
                    views.setViewVisibility(R.id.widget_now_time, View.GONE)
                    views.setViewVisibility(R.id.widget_now_location, View.GONE)
                    views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                    views.setTextViewText(R.id.widget_empty, "Nothing to show")
                    manager.updateAppWidget(appWidgetId, views)
                } catch (_: Exception) {
                }
            }
        }

        /** Keep only rows flagged isToday (or current). */
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

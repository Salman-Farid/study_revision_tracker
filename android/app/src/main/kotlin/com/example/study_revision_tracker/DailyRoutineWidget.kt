package com.example.study_revision_tracker

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import java.util.Calendar

class DailyRoutineWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
        scheduleNextTick(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == ACTION_REFRESH ||
            action == ACTION_DAILY_TICK ||
            action == "com.example.study_revision_tracker.UPDATE_WIDGETS" ||
            action == AppWidgetManager.ACTION_APPWIDGET_UPDATE
        ) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, DailyRoutineWidget::class.java))
            for (id in ids) updateWidget(context, mgr, id)
            // Keep ticking while a block is active so countdown + next block update.
            scheduleNextTick(context)
            return
        }
        super.onReceive(context, intent)
    }

    companion object {
        const val ACTION_REFRESH = "com.example.study_revision_tracker.REFRESH_DAILY"
        const val ACTION_DAILY_TICK = "com.example.study_revision_tracker.DAILY_TICK"

        fun formatRemaining(ms: Long): String {
            if (ms <= 0) return "0m"
            val totalMin = ms / 60000L
            val h = totalMin / 60
            val m = totalMin % 60
            return if (h > 0) "${h}h ${m}m" else "${m}m"
        }

        /** Tick every 30s so we can promote the next block without Flutter. */
        private fun scheduleNextTick(context: Context) {
            try {
                val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val pi = PendingIntent.getBroadcast(
                    context, 1001,
                    Intent(context, DailyRoutineWidget::class.java).setAction(ACTION_DAILY_TICK),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                val at = System.currentTimeMillis() + 30_000L
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                } else {
                    am.setExact(AlarmManager.RTC_WAKEUP, at, pi)
                }
            } catch (_: Exception) {
            }
        }

        /**
         * Prefer live prefs; if the stored current block already ended,
         * pick the next future block from widget_daily_all_items.
         */
        fun resolveActiveBlock(prefs: android.content.SharedPreferences, nowMs: Long): Triple<String, String, Long>? {
            val prefSubject = prefs.getString("widget_daily_current_subject", "") ?: ""
            val prefEnd = prefs.getString("widget_daily_current_end_timestamp", "0")?.toLongOrNull() ?: 0L
            val prefTopic = prefs.getString("widget_daily_current_topic", "") ?: ""
            if (prefSubject.isNotEmpty() && prefEnd > nowMs) {
                return Triple(prefSubject, prefTopic, prefEnd)
            }

            val allJson = prefs.getString("widget_daily_all_items", "[]") ?: "[]"
            return try {
                val arr = JSONArray(allJson)
                var bestStart = Long.MAX_VALUE
                var best: Triple<String, String, Long>? = null
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    val start = o.optLong("startTimestamp", 0L)
                    val end = o.optLong("endTimestamp", 0L)
                    if (start <= 0L || end <= 0L) continue
                    // Active now, or next upcoming today
                    val isActive = nowMs in start until end
                    val isUpcoming = start > nowMs
                    if (!isActive && !isUpcoming) continue
                    if (start < bestStart) {
                        bestStart = start
                        best = Triple(
                            o.optString("subject", ""),
                            o.optString("topic", ""),
                            end
                        )
                    }
                }
                best
            } catch (_: Exception) {
                null
            }
        }
    }
}

private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
    try {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val hasData = prefs.getString("widget_daily_has_data", "false") == "true"
        var statusMessage = prefs.getString("widget_daily_status_message", "") ?: ""
        if (statusMessage.isBlank() || statusMessage.contains("Error", ignoreCase = true)) {
            statusMessage = "Nothing to show"
        }
        val currentType = prefs.getString("widget_daily_current_type", "") ?: ""
        val currentTime = prefs.getString("widget_daily_current_time", "") ?: ""
        val lastUpdated = prefs.getString("widget_last_updated", "") ?: ""
        val nowMs = System.currentTimeMillis()

        val active = DailyRoutineWidget.resolveActiveBlock(prefs, nowMs)
        val hasCurrent = active != null && active.third > nowMs

        val views = RemoteViews(context.packageName, R.layout.daily_routine_widget)

        if (hasCurrent && active != null) {
            views.setViewVisibility(R.id.widget_current_card, View.VISIBLE)
            views.setTextViewText(R.id.widget_current_subject, active.first)
            views.setTextViewText(R.id.widget_current_topic, active.second)
            views.setTextViewText(R.id.widget_current_type, currentType)
            views.setTextViewText(R.id.widget_current_time, currentTime)

            // Second-by-second countdown (12:30 → 12:29 → …).
            // setChronometerCountDown MUST be called BEFORE setChronometer
            // or some OEMs count up and show a minus sign.
            val remainingMs = (active.third - nowMs).coerceAtLeast(0L)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                views.setChronometerCountDown(R.id.widget_current_timer, true)
                views.setChronometer(
                    R.id.widget_current_timer,
                    SystemClock.elapsedRealtime() + remainingMs,
                    null,
                    true
                )
            } else {
                // Pre-N: static fallback with seconds.
                val totalSec = remainingMs / 1000
                val h = totalSec / 3600
                val m = (totalSec % 3600) / 60
                val s = totalSec % 60
                val text = if (h > 0) {
                    String.format(java.util.Locale.US, "%d:%02d:%02d", h, m, s)
                } else {
                    String.format(java.util.Locale.US, "%02d:%02d", m, s)
                }
                views.setTextViewText(R.id.widget_current_timer, text)
            }
        } else {
            views.setViewVisibility(R.id.widget_current_card, View.GONE)
        }

        val upcomingJson = prefs.getString("widget_daily_upcoming_items", "[]") ?: "[]"
        val hasUpcoming = try {
            JSONArray(upcomingJson).length() > 0
        } catch (_: Exception) { false }

        views.setViewVisibility(
            R.id.widget_upcoming_header,
            if (hasUpcoming && hasCurrent) View.VISIBLE else View.GONE
        )

        val adapterIntent = Intent(context, DailyRoutineWidgetService::class.java)
        adapterIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        adapterIntent.action = "android.appwidget.action.APPWIDGET_UPDATE"
        views.setRemoteAdapter(R.id.widget_upcoming_list, adapterIntent)
        views.setEmptyView(R.id.widget_upcoming_list, R.id.widget_empty)

        if (!hasData) {
            views.setViewVisibility(R.id.widget_upcoming_list, View.GONE)
            views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            views.setTextViewText(R.id.widget_empty_message, statusMessage)
        } else if (!hasUpcoming && !hasCurrent) {
            views.setViewVisibility(R.id.widget_upcoming_list, View.GONE)
            views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            views.setTextViewText(R.id.widget_empty_message, "No more blocks today")
        } else {
            views.setViewVisibility(R.id.widget_empty, View.GONE)
        }

        if (lastUpdated.isNotEmpty()) {
            val time = lastUpdated.substringAfter("T", "").take(5)
            if (time.isNotEmpty()) {
                views.setTextViewText(R.id.widget_updated, "Updated $time")
            }
        }

        val rootIntent = Intent(Intent.ACTION_VIEW, Uri.parse("study-revision-tracker://routine")).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            setPackage(context.packageName)
        }
        views.setOnClickPendingIntent(
            R.id.widget_root,
            PendingIntent.getActivity(
                context, 2, rootIntent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
        )

        appWidgetManager.updateAppWidget(appWidgetId, views)
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_upcoming_list)
    } catch (e: Exception) {
        android.util.Log.e("DailyRoutineWidget", "update error: ${e.message}")
    }
}

package com.pootustudycompanion.app

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
            action == "com.pootustudycompanion.app.UPDATE_WIDGETS" ||
            action == AppWidgetManager.ACTION_APPWIDGET_UPDATE
        ) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, DailyRoutineWidget::class.java))
            var anyActive = false
            for (id in ids) {
                updateWidget(context, mgr, id)
                if (hasActiveBlock(context)) anyActive = true
            }
            // Only keep ticking while a block is still running (stops infinite loop).
            if (anyActive) scheduleNextTick(context)
            return
        }
        super.onReceive(context, intent)
    }

    companion object {
        const val ACTION_REFRESH = "com.pootustudycompanion.app.REFRESH_DAILY"
        const val ACTION_DAILY_TICK = "com.pootustudycompanion.app.DAILY_TICK"
        private const val MAX_BLOCK_MS = 4L * 60L * 60L * 1000L // 4h safety cap

        data class ActiveBlock(
            val subject: String,
            val topic: String,
            val type: String,
            val timeText: String,
            val endMs: Long,
        )

        fun hasActiveBlock(context: Context): Boolean {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            return resolveActiveBlock(prefs, now)?.let { it.endMs > now } == true
        }

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
         * Resolve the block that is running now (preferred) or the next one today.
         * Reads type + time from all_items so labels never go stale.
         */
        fun resolveActiveBlock(prefs: android.content.SharedPreferences, nowMs: Long): ActiveBlock? {
            val allJson = prefs.getString("widget_daily_all_items", "[]") ?: "[]"
            try {
                val arr = JSONArray(allJson)
                var best: ActiveBlock? = null
                var bestStart = Long.MAX_VALUE
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    val start = o.optLong("startTimestamp", 0L)
                    val end = o.optLong("endTimestamp", 0L)
                    if (start <= 0L || end <= 0L || end <= start) continue
                    // Ignore absurd end times (corrupt data → infinite timer).
                    if (end - start > MAX_BLOCK_MS) continue
                    val isActive = nowMs in start until end
                    val isUpcoming = start > nowMs && (start - nowMs) < 12L * 60L * 60L * 1000L
                    if (!isActive && !isUpcoming) continue
                    // Prefer an active block; otherwise earliest upcoming.
                    val rank = if (isActive) start - 1_000_000_000_000L else start
                    if (rank < bestStart) {
                        bestStart = rank
                        best = ActiveBlock(
                            subject = o.optString("subject", ""),
                            topic = o.optString("topic", ""),
                            type = o.optString("type", ""),
                            timeText = run {
                                val a = o.optString("timeText", "")
                                val b = o.optString("endTimeText", "")
                                if (b.isNotEmpty()) "$a – $b" else a
                            },
                            endMs = end,
                        )
                    }
                }
                if (best != null) return best
            } catch (_: Exception) {
            }

            // Fallback: single "current" pref if it hasn't ended yet.
            val prefSubject = prefs.getString("widget_daily_current_subject", "") ?: ""
            val prefEnd = prefs.getString("widget_daily_current_end_timestamp", "0")?.toLongOrNull() ?: 0L
            if (prefSubject.isNotEmpty() && prefEnd > nowMs && (prefEnd - nowMs) <= MAX_BLOCK_MS) {
                return ActiveBlock(
                    subject = prefSubject,
                    topic = prefs.getString("widget_daily_current_topic", "") ?: "",
                    type = prefs.getString("widget_daily_current_type", "") ?: "",
                    timeText = prefs.getString("widget_daily_current_time", "") ?: "",
                    endMs = prefEnd,
                )
            }
            return null
        }
    }
}

private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
    try {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val hasData = prefs.getString("widget_daily_has_data", "false") == "true"
        var statusMessage = prefs.getString("widget_daily_status_message", "") ?: ""
        if (statusMessage.isBlank() || statusMessage.contains("Error", ignoreCase = true)) {
            statusMessage = "No Daily Routine Created, Tap To Create One"
        }
        val nowMs = System.currentTimeMillis()

        // Only show a live block when a daily routine actually exists for today.
        // Class routines must never leak into this widget.
        val active = if (hasData) DailyRoutineWidget.resolveActiveBlock(prefs, nowMs) else null
        val hasCurrent = active != null && active.endMs > nowMs

        val views = RemoteViews(context.packageName, R.layout.daily_routine_widget)

        if (hasCurrent && active != null) {
            views.setViewVisibility(R.id.widget_current_card, View.VISIBLE)
            views.setTextViewText(R.id.widget_current_subject, active.subject)
            views.setTextViewText(R.id.widget_current_topic, active.topic)
            // Use live type from the resolved block (not a stale pref).
            views.setTextViewText(R.id.widget_current_type, active.type.ifEmpty { "Study" })
            views.setTextViewText(R.id.widget_current_time, active.timeText)

            val remainingMs = (active.endMs - nowMs).coerceAtLeast(0L)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                views.setChronometerCountDown(R.id.widget_current_timer, true)
                views.setChronometer(
                    R.id.widget_current_timer,
                    SystemClock.elapsedRealtime() + remainingMs,
                    null,
                    true
                )
            } else {
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

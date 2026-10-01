package com.pootustudycompanion.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Periodic native refresh for all three home-screen widgets.
 * Uses AlarmManager so widgets stay current even when Flutter is closed.
 */
class WidgetTickReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        try {
            val mgr = AppWidgetManager.getInstance(context)

            val classIds = mgr.getAppWidgetIds(
                ComponentName(context, ClassRoutineWidget::class.java)
            )
            for (id in classIds) {
                ClassRoutineWidget.render(context, mgr, id)
            }

            val dailyIds = mgr.getAppWidgetIds(
                ComponentName(context, DailyRoutineWidget::class.java)
            )
            for (id in dailyIds) {
                val i = Intent(context, DailyRoutineWidget::class.java)
                    .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                context.sendBroadcast(i)
            }

            val revIds = mgr.getAppWidgetIds(
                ComponentName(context, RevisionWidget::class.java)
            )
            for (id in revIds) {
                val i = Intent(context, RevisionWidget::class.java)
                    .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                context.sendBroadcast(i)
            }

            Log.d(TAG, "widget tick: class=${classIds.size} daily=${dailyIds.size} rev=${revIds.size}")
        } catch (e: Exception) {
            Log.e(TAG, "widget tick failed: ${e.message}")
        }
        scheduleNext(context)
    }

    companion object {
        private const val TAG = "WidgetTickReceiver"
        const val ACTION_TICK = "com.pootustudycompanion.app.WIDGET_TICK"
        private const val REQ_CODE = 77001
        private const val PERIOD_MS = 10L * 60L * 1000L // 10 minutes

        fun scheduleNext(context: Context) {
            try {
                val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val pi = PendingIntent.getBroadcast(
                    context,
                    REQ_CODE,
                    Intent(context, WidgetTickReceiver::class.java).setAction(ACTION_TICK),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                val at = System.currentTimeMillis() + PERIOD_MS
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                } else {
                    am.setExact(AlarmManager.RTC_WAKEUP, at, pi)
                }
            } catch (e: Exception) {
                Log.e(TAG, "scheduleNext failed: ${e.message}")
            }
        }

        fun scheduleNow(context: Context) = scheduleNext(context)
    }
}

package com.example.study_revision_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews

class DailyRoutineWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        Log.d("DailyRoutineWidget", "onUpdate called with ${appWidgetIds.size} widgets")
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        Log.d("DailyRoutineWidget", "onReceive action=${intent?.action}")
        super.onReceive(context, intent)
        if (intent?.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            intent?.action == "com.example.study_revision_tracker.UPDATE_WIDGETS") {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, DailyRoutineWidget::class.java)
            )
            Log.d("DailyRoutineWidget", "Found ${ids.size} widget instances")
            for (id in ids) {
                updateAppWidget(context, appWidgetManager, id)
            }
        }
    }

    companion object {
        private const val TAG = "DailyRoutineWidget"

        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            try {
                Log.d(TAG, "updateAppWidget id=$appWidgetId")
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val views = RemoteViews(context.packageName, R.layout.daily_routine_widget)

                val hasData = prefs.getBoolean("widget_daily_has_data", false)
                val statusMessage = prefs.getString("widget_daily_status_message", "No routine set for today") ?: ""
                val currentSubject = prefs.getString("widget_daily_current_subject", "") ?: ""
                val currentTopic = prefs.getString("widget_daily_current_topic", "") ?: ""
                val currentType = prefs.getString("widget_daily_current_type", "") ?: ""
                val currentTime = prefs.getString("widget_daily_current_time", "") ?: ""
                val remaining = prefs.getString("widget_daily_remaining", "") ?: ""
                val nextSubject = prefs.getString("widget_daily_next_subject", "") ?: ""
                val nextTime = prefs.getString("widget_daily_next_time", "") ?: ""

                Log.d(TAG, "hasData=$hasData currentSubject='$currentSubject' currentType='$currentType' remaining='$remaining'")
                Log.d(TAG, "nextSubject='$nextSubject' nextTime='$nextTime'")

                if (hasData && currentSubject.isNotEmpty()) {
                    views.setViewVisibility(R.id.widget_current_card, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_empty_state, View.GONE)
                    views.setTextViewText(R.id.widget_current_subject, currentSubject)

                    if (currentTopic.isNotEmpty()) {
                        views.setViewVisibility(R.id.widget_current_topic, View.VISIBLE)
                        views.setTextViewText(R.id.widget_current_topic, currentTopic)
                    } else {
                        views.setViewVisibility(R.id.widget_current_topic, View.GONE)
                    }

                    val typeLabel = formatTypeLabel(currentType)
                    if (typeLabel.isNotEmpty()) {
                        views.setViewVisibility(R.id.widget_current_type, View.VISIBLE)
                        views.setTextViewText(R.id.widget_current_type, typeLabel)
                    } else {
                        views.setViewVisibility(R.id.widget_current_type, View.GONE)
                    }

                    views.setTextViewText(R.id.widget_current_time, currentTime)
                    views.setTextViewText(R.id.widget_remaining, remaining)
                    views.setViewVisibility(R.id.widget_status_badge, View.VISIBLE)

                    if (nextSubject.isNotEmpty()) {
                        views.setViewVisibility(R.id.widget_next_card, View.VISIBLE)
                        views.setTextViewText(R.id.widget_next_subject, nextSubject)
                        views.setTextViewText(R.id.widget_next_time, nextTime)
                    } else {
                        views.setViewVisibility(R.id.widget_next_card, View.GONE)
                    }
                } else if (hasData) {
                    views.setViewVisibility(R.id.widget_current_card, View.VISIBLE)
                    views.setTextViewText(R.id.widget_current_subject, statusMessage)
                    views.setViewVisibility(R.id.widget_current_topic, View.GONE)
                    views.setViewVisibility(R.id.widget_current_type, View.GONE)
                    views.setTextViewText(R.id.widget_current_time, "")
                    views.setTextViewText(R.id.widget_remaining, "")
                    views.setViewVisibility(R.id.widget_status_badge, View.GONE)
                    views.setViewVisibility(R.id.widget_next_card, View.GONE)
                    views.setViewVisibility(R.id.widget_empty_state, View.GONE)
                } else {
                    views.setViewVisibility(R.id.widget_current_card, View.GONE)
                    views.setViewVisibility(R.id.widget_next_card, View.GONE)
                    views.setViewVisibility(R.id.widget_status_badge, View.GONE)
                    views.setViewVisibility(R.id.widget_empty_state, View.VISIBLE)
                    views.setTextViewText(R.id.widget_empty_text, statusMessage)
                }

                val intent = Intent(Intent.ACTION_VIEW, Uri.parse("study-revision-tracker://routine"))
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                val pendingIntent = PendingIntent.getActivity(
                    context, 0, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
                Log.d(TAG, "Widget $appWidgetId updated successfully")
            } catch (e: Exception) {
                Log.e(TAG, "CRITICAL: updateAppWidget failed for id=$appWidgetId", e)
            }
        }

        private fun formatTypeLabel(type: String): String {
            return when (type) {
                "study" -> "Study"
                "revision" -> "Revision"
                "first_read" -> "First Read"
                "class" -> "Class"
                "break" -> "Break"
                "meal" -> "Meal"
                "nap" -> "Power Nap"
                "recall" -> "Active Recall"
                "question_practice" -> "Questions"
                "review" -> "Review"
                else -> type.replace("_", " ").replaceFirstChar { it.uppercase() }
            }
        }
    }
}

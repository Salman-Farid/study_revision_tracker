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
import org.json.JSONArray

class ClassRoutineWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        Log.d("ClassRoutineWidget", "onUpdate called with ${appWidgetIds.size} widgets")
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        Log.d("ClassRoutineWidget", "onReceive action=${intent?.action}")
        super.onReceive(context, intent)
        if (intent?.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            intent?.action == "com.example.study_revision_tracker.UPDATE_WIDGETS") {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, ClassRoutineWidget::class.java)
            )
            Log.d("ClassRoutineWidget", "Found ${ids.size} widget instances")
            for (id in ids) {
                updateAppWidget(context, appWidgetManager, id)
            }
        }
    }

    companion object {
        private const val TAG = "ClassRoutineWidget"

        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            try {
                Log.d(TAG, "updateAppWidget id=$appWidgetId")
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val views = RemoteViews(context.packageName, R.layout.class_routine_widget)

                val hasToday = prefs.getBoolean("widget_class_has_today", false)
                val statusMessage = prefs.getString("widget_class_status_message", "No classes today") ?: ""
                val currentSubject = prefs.getString("widget_class_current_subject", "") ?: ""
                val currentTime = prefs.getString("widget_class_current_time", "") ?: ""
                val currentLocation = prefs.getString("widget_class_current_location", "") ?: ""
                val currentRemaining = prefs.getString("widget_class_current_end_time", "") ?: ""
                val nextSubject = prefs.getString("widget_class_next_subject", "") ?: ""
                val nextTime = prefs.getString("widget_class_next_time", "") ?: ""
                val classesJson = prefs.getString("widget_class_items", "[]") ?: "[]"

                Log.d(TAG, "hasToday=$hasToday currentSubject='$currentSubject' currentTime='$currentTime'")
                Log.d(TAG, "currentLocation='$currentLocation' nextSubject='$nextSubject'")
                Log.d(TAG, "classesJson.length=${classesJson.length}")

                // Dump ALL keys for debugging
                val allKeys = prefs.all.keys.filter { it.startsWith("widget_") }
                Log.d(TAG, "All widget_ keys in SP: $allKeys")

                if (hasToday && currentSubject.isNotEmpty()) {
                    views.setViewVisibility(R.id.widget_current_card, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_empty_state, View.GONE)
                    views.setViewVisibility(R.id.widget_status_badge, View.VISIBLE)
                    views.setTextViewText(R.id.widget_current_subject, currentSubject)
                    views.setTextViewText(R.id.widget_current_time, currentTime)
                    views.setTextViewText(R.id.widget_remaining, currentRemaining)

                    if (currentLocation.isNotEmpty()) {
                        views.setViewVisibility(R.id.widget_current_location, View.VISIBLE)
                        views.setTextViewText(R.id.widget_current_location, currentLocation)
                    } else {
                        views.setViewVisibility(R.id.widget_current_location, View.GONE)
                    }

                    if (nextSubject.isNotEmpty()) {
                        views.setViewVisibility(R.id.widget_next_card, View.VISIBLE)
                        views.setTextViewText(R.id.widget_next_subject, nextSubject)
                        views.setTextViewText(R.id.widget_next_time, nextTime)
                    } else {
                        views.setViewVisibility(R.id.widget_next_card, View.GONE)
                    }
                } else if (hasToday) {
                    views.setViewVisibility(R.id.widget_current_card, View.GONE)
                    views.setViewVisibility(R.id.widget_status_badge, View.GONE)
                    views.setViewVisibility(R.id.widget_next_card, View.GONE)
                    views.setViewVisibility(R.id.widget_empty_state, View.VISIBLE)
                    views.setTextViewText(R.id.widget_empty_text, statusMessage)
                } else {
                    views.setViewVisibility(R.id.widget_current_card, View.GONE)
                    views.setViewVisibility(R.id.widget_status_badge, View.GONE)
                    views.setViewVisibility(R.id.widget_next_card, View.GONE)
                    views.setViewVisibility(R.id.widget_empty_state, View.VISIBLE)
                    views.setTextViewText(R.id.widget_empty_text, statusMessage)
                }

                // Populate today's class list
                views.removeAllViews(R.id.widget_classes_container)
                try {
                    val classes = JSONArray(classesJson)
                    val maxItems = minOf(classes.length(), 8)
                    Log.d(TAG, "Parsing $maxItems classes from JSON")
                    if (maxItems > 0 && hasToday) {
                        views.setViewVisibility(R.id.widget_classes_container, View.VISIBLE)
                        for (i in 0 until maxItems) {
                            val cls = classes.getJSONObject(i)
                            val subject = cls.optString("subject", "")
                            val time = cls.optString("timeText", "")
                            val location = cls.optString("location", "")
                            val isCurrent = cls.optBoolean("isCurrent", false)

                            Log.d(TAG, "Class $i: subject=$subject time=$time isCurrent=$isCurrent")

                            val itemView = RemoteViews(context.packageName, R.layout.class_routine_widget_item)
                            itemView.setTextViewText(R.id.item_time, time)
                            itemView.setTextViewText(R.id.item_subject, subject)

                            if (location.isNotEmpty()) {
                                itemView.setViewVisibility(R.id.item_location, View.VISIBLE)
                                itemView.setTextViewText(R.id.item_location, location)
                            } else {
                                itemView.setViewVisibility(R.id.item_location, View.GONE)
                            }

                            if (isCurrent) {
                                itemView.setInt(R.id.item_accent, "setBackgroundColor",
                                    context.getColor(R.color.widget_accent_green))
                                itemView.setViewVisibility(R.id.item_status_dot, View.VISIBLE)
                            } else {
                                itemView.setInt(R.id.item_accent, "setBackgroundColor",
                                    context.getColor(R.color.widget_accent_purple))
                                itemView.setViewVisibility(R.id.item_status_dot, View.GONE)
                            }

                            views.addView(R.id.widget_classes_container, itemView)
                        }
                    } else {
                        views.setViewVisibility(R.id.widget_classes_container, View.GONE)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error parsing classes JSON", e)
                    views.setViewVisibility(R.id.widget_classes_container, View.GONE)
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
    }
}

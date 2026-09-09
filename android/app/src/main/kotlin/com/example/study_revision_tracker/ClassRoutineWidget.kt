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

                val hasToday = prefs.getString("widget_class_has_today", "false")?.toBoolean() == true
                val statusMessage = prefs.getString("widget_class_status_message", "Nothing for today") ?: ""
                val currentSubject = prefs.getString("widget_class_current_subject", "") ?: ""
                val currentTime = prefs.getString("widget_class_current_time", "") ?: ""
                val currentLocation = prefs.getString("widget_class_current_location", "") ?: ""
                val currentRemaining = prefs.getString("widget_class_current_end_time", "") ?: ""
                val classesJson = prefs.getString("widget_class_items", "[]") ?: "[]"

                Log.d(TAG, "hasToday=$hasToday currentSubject='$currentSubject' currentTime='$currentTime'")

                // Ultra-low sizing check
                val widgetInfo = appWidgetManager.getAppWidgetInfo(appWidgetId)
                val isSmallWidget = (widgetInfo?.minWidth ?: 250) < 180

                if (hasToday && currentSubject.isNotEmpty()) {
                    views.setViewVisibility(R.id.widget_current_card, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_today_header, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_empty, View.GONE)
                    views.setTextViewText(R.id.widget_current_subject, currentSubject)
                    views.setTextViewText(R.id.widget_current_time, currentTime)
                    views.setTextViewText(R.id.widget_current_timer, currentRemaining)

                    if (currentLocation.isNotEmpty() && !isSmallWidget) {
                        views.setViewVisibility(R.id.widget_current_location, View.VISIBLE)
                        views.setTextViewText(R.id.widget_current_location, currentLocation)
                    } else {
                        views.setViewVisibility(R.id.widget_current_location, View.GONE)
                    }
                } else {
                    views.setViewVisibility(R.id.widget_current_card, View.GONE)
                    views.setViewVisibility(R.id.widget_today_header, View.GONE)
                    if (!hasToday) {
                        views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                        views.setTextViewText(R.id.widget_empty_message, statusMessage)
                    } else {
                        views.setViewVisibility(R.id.widget_empty, View.GONE)
                    }
                }

                // Class rows — rendered directly with RemoteViews.addView().
                // No ListView/adapter/service → no "Loading…" placeholder, ever.
                val hasClasses = try {
                    JSONArray(classesJson).length() > 0
                } catch (_: Exception) { false }

                views.removeAllViews(R.id.widget_class_list)
                if (hasToday && hasClasses) {
                    views.setViewVisibility(R.id.widget_class_list, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_empty, View.GONE)
                    try {
                        val classes = JSONArray(classesJson)
                        val maxItems = if (isSmallWidget) 3 else 6
                        for (i in 0 until minOf(classes.length(), maxItems)) {
                            val cls = classes.getJSONObject(i)
                            val row = RemoteViews(context.packageName, R.layout.class_routine_widget_item)
                            row.setTextViewText(R.id.item_subject, cls.optString("subject", ""))
                            val timeText = cls.optString("timeText", "")
                            val endTimeText = cls.optString("endTimeText", "")
                            row.setTextViewText(R.id.item_time, if (endTimeText.isNotEmpty()) "$timeText – $endTimeText" else timeText)

                            val location = cls.optString("location", "")
                            if (location.isNotEmpty()) {
                                row.setViewVisibility(R.id.item_location, View.VISIBLE)
                                row.setTextViewText(R.id.item_location, "· $location")
                            } else {
                                row.setViewVisibility(R.id.item_location, View.GONE)
                            }

                            if (cls.optBoolean("isCurrent", false)) {
                                row.setViewVisibility(R.id.item_now_badge, View.VISIBLE)
                                row.setInt(R.id.item_dot, "setBackgroundResource", R.drawable.dot_circle_now)
                            } else {
                                row.setViewVisibility(R.id.item_now_badge, View.GONE)
                                row.setInt(R.id.item_dot, "setBackgroundResource", R.drawable.dot_circle_upcoming)
                            }
                            views.addView(R.id.widget_class_list, row)
                        }
                        if (classes.length() > maxItems) {
                            val more = RemoteViews(context.packageName, R.layout.widget_more_row)
                            more.setTextViewText(R.id.more_text, "+${classes.length() - maxItems} more")
                            views.addView(R.id.widget_class_list, more)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "row build failed: ${e.message}")
                    }
                } else {
                    views.setViewVisibility(R.id.widget_class_list, View.GONE)
                    views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                    views.setTextViewText(R.id.widget_empty_message, if (hasToday) statusMessage else "No classes today")
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

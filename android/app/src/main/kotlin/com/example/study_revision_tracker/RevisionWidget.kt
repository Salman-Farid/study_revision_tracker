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

class RevisionWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        Log.d(TAG, "onUpdate called with ${appWidgetIds.size} widgets")
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        Log.d(TAG, "onReceive action=${intent?.action}")
        super.onReceive(context, intent)

        when (intent?.action) {
            ACTION_TOGGLE_OVERDUE -> toggleSection(context, PREF_TOGGLE_OVERDUE)
            ACTION_TOGGLE_TODAY -> toggleSection(context, PREF_TOGGLE_TODAY)
            ACTION_TOGGLE_UPCOMING -> toggleSection(context, PREF_TOGGLE_UPCOMING)
        }

        if (intent?.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            intent?.action == "com.example.study_revision_tracker.UPDATE_WIDGETS" ||
            intent?.action?.startsWith("com.example.study_revision_tracker.TOGGLE_") == true) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val ids = appWidgetManager.getAppWidgetIds(
                android.content.ComponentName(context, RevisionWidget::class.java)
            )
            Log.d(TAG, "Found ${ids.size} widget instances")
            for (id in ids) {
                updateAppWidget(context, appWidgetManager, id)
            }
        }
    }

    private fun toggleSection(context: Context, prefKey: String) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val current = prefs.getBoolean(prefKey, true)
        prefs.edit().putBoolean(prefKey, !current).apply()
        Log.d(TAG, "Toggled $prefKey from $current to ${!current}")
    }

    companion object {
        private const val TAG = "RevisionWidget"

        private const val ACTION_TOGGLE_OVERDUE = "com.example.study_revision_tracker.TOGGLE_OVERDUE"
        private const val ACTION_TOGGLE_TODAY = "com.example.study_revision_tracker.TOGGLE_TODAY"
        private const val ACTION_TOGGLE_UPCOMING = "com.example.study_revision_tracker.TOGGLE_UPCOMING"

        private const val PREF_TOGGLE_OVERDUE = "widget_revision_toggle_overdue"
        private const val PREF_TOGGLE_TODAY = "widget_revision_toggle_today"
        private const val PREF_TOGGLE_UPCOMING = "widget_revision_toggle_upcoming"

        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            try {
                Log.d(TAG, "updateAppWidget id=$appWidgetId")
                val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                val views = RemoteViews(context.packageName, R.layout.revision_widget)

                val hasData = prefs.getBoolean("widget_revision_has_data", false)
                val statusMessage = prefs.getString("widget_revision_status_message", "No revisions scheduled") ?: ""
                val overdueCount = prefs.getString("widget_revision_overdue_count", "0")?.toIntOrNull() ?: 0
                val todayCount = prefs.getString("widget_revision_today_count", "0")?.toIntOrNull() ?: 0
                val upcomingCount = prefs.getString("widget_revision_upcoming_count", "0")?.toIntOrNull() ?: 0

                // Read toggle states (default: overdue+today expanded, upcoming collapsed)
                val showOverdue = prefs.getBoolean(PREF_TOGGLE_OVERDUE, true)
                val showToday = prefs.getBoolean(PREF_TOGGLE_TODAY, true)
                val showUpcoming = prefs.getBoolean(PREF_TOGGLE_UPCOMING, false)

                Log.d(TAG, "hasData=$hasData overdue=$overdueCount today=$todayCount upcoming=$upcomingCount")
                Log.d(TAG, "toggles: overdue=$showOverdue today=$showToday upcoming=$showUpcoming")

                if (hasData) {
                    views.setViewVisibility(R.id.widget_stats_row, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_empty_state, View.GONE)

                    // --- Overdue section ---
                    if (overdueCount > 0) {
                        views.setViewVisibility(R.id.widget_overdue_container, View.VISIBLE)
                        views.setTextViewText(R.id.widget_overdue_count, overdueCount.toString())
                        setupSectionToggle(context, views, R.id.widget_overdue_container, ACTION_TOGGLE_OVERDUE, appWidgetId)

                        val overdueItemsJson = prefs.getString("widget_revision_overdue_items", "[]") ?: "[]"
                        views.removeAllViews(R.id.widget_overdue_section)
                        if (showOverdue) {
                            views.setViewVisibility(R.id.widget_overdue_section, View.VISIBLE)
                            addSectionHeader(context, views, R.id.widget_overdue_section, "Missed", overdueCount, R.color.widget_accent_red)
                            populateItems(context, views, R.id.widget_overdue_section, overdueItemsJson, true)
                        } else {
                            views.setViewVisibility(R.id.widget_overdue_section, View.GONE)
                        }
                    } else {
                        views.setViewVisibility(R.id.widget_overdue_container, View.GONE)
                        views.setViewVisibility(R.id.widget_overdue_section, View.GONE)
                    }

                    // --- Today section ---
                    if (todayCount > 0) {
                        views.setViewVisibility(R.id.widget_today_container, View.VISIBLE)
                        views.setTextViewText(R.id.widget_today_count, todayCount.toString())
                        setupSectionToggle(context, views, R.id.widget_today_container, ACTION_TOGGLE_TODAY, appWidgetId)

                        val todayItemsJson = prefs.getString("widget_revision_today_items", "[]") ?: "[]"
                        views.removeAllViews(R.id.widget_today_section)
                        if (showToday) {
                            views.setViewVisibility(R.id.widget_today_section, View.VISIBLE)
                            addSectionHeader(context, views, R.id.widget_today_section, "Due Today", todayCount, R.color.widget_primary)
                            populateItems(context, views, R.id.widget_today_section, todayItemsJson, false)
                        } else {
                            views.setViewVisibility(R.id.widget_today_section, View.GONE)
                        }
                    } else {
                        views.setViewVisibility(R.id.widget_today_container, View.GONE)
                        views.setViewVisibility(R.id.widget_today_section, View.GONE)
                    }

                    // --- Upcoming section ---
                    if (upcomingCount > 0) {
                        views.setViewVisibility(R.id.widget_upcoming_container, View.VISIBLE)
                        views.setTextViewText(R.id.widget_upcoming_count, upcomingCount.toString())
                        setupSectionToggle(context, views, R.id.widget_upcoming_container, ACTION_TOGGLE_UPCOMING, appWidgetId)

                        val upcomingItemsJson = prefs.getString("widget_revision_upcoming_items", "[]") ?: "[]"
                        views.removeAllViews(R.id.widget_upcoming_section)
                        if (showUpcoming) {
                            views.setViewVisibility(R.id.widget_upcoming_section, View.VISIBLE)
                            addSectionHeader(context, views, R.id.widget_upcoming_section, "Coming Soon", upcomingCount, R.color.widget_accent_green)
                            populateItems(context, views, R.id.widget_upcoming_section, upcomingItemsJson, false)
                        } else {
                            views.setViewVisibility(R.id.widget_upcoming_section, View.GONE)
                        }
                    } else {
                        views.setViewVisibility(R.id.widget_upcoming_container, View.GONE)
                        views.setViewVisibility(R.id.widget_upcoming_section, View.GONE)
                    }

                    // Hide legacy container
                    views.setViewVisibility(R.id.widget_items_container, View.GONE)

                } else {
                    views.setViewVisibility(R.id.widget_stats_row, View.GONE)
                    views.setViewVisibility(R.id.widget_overdue_section, View.GONE)
                    views.setViewVisibility(R.id.widget_today_section, View.GONE)
                    views.setViewVisibility(R.id.widget_upcoming_section, View.GONE)
                    views.setViewVisibility(R.id.widget_items_container, View.GONE)
                    views.setViewVisibility(R.id.widget_empty_state, View.VISIBLE)
                    views.setTextViewText(R.id.widget_empty_text, statusMessage)
                }

                // Tap intent — opens Today screen
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse("study-revision-tracker://today"))
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

        private fun setupSectionToggle(context: Context, views: RemoteViews, containerId: Int, action: String, appWidgetId: Int) {
            val toggleIntent = Intent(action)
            toggleIntent.component = android.content.ComponentName(context, RevisionWidget::class.java)
            toggleIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            val togglePending = PendingIntent.getBroadcast(
                context, action.hashCode(), toggleIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(containerId, togglePending)
        }

        private fun addSectionHeader(context: Context, views: RemoteViews, containerId: Int, title: String, count: Int, colorResId: Int) {
            val header = RemoteViews(context.packageName, R.layout.revision_widget_section_header)
            header.setTextViewText(R.id.section_title, "$title")
            header.setTextViewText(R.id.section_count, "$count items")
            header.setTextColor(R.id.section_title, context.getColor(colorResId))
            header.setTextColor(R.id.section_count, context.getColor(R.color.widget_text_muted))
            header.setInt(R.id.section_dot, "setBackgroundColor", context.getColor(colorResId))
            views.addView(containerId, header)
        }

        private fun populateItems(context: Context, views: RemoteViews, containerId: Int, itemsJson: String, isOverdueSection: Boolean) {
            try {
                val items = JSONArray(itemsJson)
                Log.d(TAG, "Populating $containerId with ${items.length()} items (overdue=$isOverdueSection)")
                for (i in 0 until items.length()) {
                    val item = items.getJSONObject(i)
                    val subjectName = item.optString("subjectName", "Unknown")
                    val topicName = item.optString("topicName", "")
                    val dayLabel = item.optString("dayLabel", "")
                    val isOverdue = item.optBoolean("isOverdue", false)
                    val scheduledDate = item.optString("scheduledDate", "")

                    val itemView = RemoteViews(context.packageName, R.layout.revision_widget_item)
                    itemView.setTextViewText(R.id.item_subject, subjectName)

                    if (topicName.isNotEmpty()) {
                        itemView.setViewVisibility(R.id.item_topic, View.VISIBLE)
                        itemView.setTextViewText(R.id.item_topic, topicName)
                    } else {
                        itemView.setViewVisibility(R.id.item_topic, View.GONE)
                    }

                    // Badge styling
                    val displayLabel = if (isOverdueSection && scheduledDate.isNotEmpty()) {
                        // For overdue, show the date
                        scheduledDate
                    } else {
                        dayLabel
                    }
                    itemView.setTextViewText(R.id.item_badge, displayLabel)

                    if (isOverdue) {
                        itemView.setInt(R.id.item_accent, "setBackgroundColor",
                            context.getColor(R.color.widget_accent_red))
                        itemView.setInt(R.id.item_badge, "setBackgroundResource",
                            R.drawable.widget_accent_red)
                        itemView.setTextColor(R.id.item_badge, context.getColor(android.R.color.white))
                    } else {
                        itemView.setInt(R.id.item_accent, "setBackgroundColor",
                            context.getColor(R.color.widget_primary))
                        itemView.setInt(R.id.item_badge, "setBackgroundResource",
                            R.drawable.widget_badge_background)
                        itemView.setTextColor(R.id.item_badge, context.getColor(R.color.widget_primary))
                    }

                    views.addView(containerId, itemView)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing items JSON for container $containerId", e)
            }
        }
    }
}

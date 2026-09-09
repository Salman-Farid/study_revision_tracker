package com.example.study_revision_tracker

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

class RevisionWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return RevisionWidgetFactory(applicationContext, intent)
    }
}

class RevisionWidgetFactory(
    private val context: Context,
    private val intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    private data class WidgetItem(
        val type: Int, // 0 = header, 1 = item
        val subject: String = "",
        val topic: String = "",
        val badge: String = "",
        val isOverdue: Boolean = false,
        val headerTitle: String = "",
        val headerColor: Int = 0
    )

    private val items = mutableListOf<WidgetItem>()

    override fun onCreate() {}

    override fun onDestroy() {
        items.clear()
    }

    override fun onDataSetChanged() {
        items.clear()
        try {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val showOverdue = prefs.getBoolean("widget_revision_toggle_overdue", true)
            val showUpcoming = prefs.getBoolean("widget_revision_toggle_upcoming", false)

            // Overdue section
            val overdueCount = prefs.getString("widget_revision_overdue_count", "0")?.toIntOrNull() ?: 0
            if (showOverdue && overdueCount > 0) {
                items.add(WidgetItem(
                    type = 0,
                    headerTitle = "Missed",
                    headerColor = context.getColor(R.color.widget_accent_red)
                ))
                val overdueJson = prefs.getString("widget_revision_overdue_items", "[]") ?: "[]"
                val arr = JSONArray(overdueJson)
                val maxItems = 5
                val showCount = minOf(arr.length(), maxItems)
                for (i in 0 until showCount) {
                    val obj = arr.getJSONObject(i)
                    items.add(WidgetItem(
                        type = 1,
                        subject = obj.optString("subjectName", "Unknown"),
                        topic = obj.optString("topicName", ""),
                        badge = obj.optString("scheduledDate", ""),
                        isOverdue = true
                    ))
                }
                if (arr.length() > maxItems) {
                    items.add(WidgetItem(
                        type = 0,
                        headerTitle = "+${arr.length() - maxItems} more",
                        headerColor = context.getColor(R.color.widget_text_muted)
                    ))
                }
            }

            // Upcoming section
            val upcomingCount = prefs.getString("widget_revision_upcoming_count", "0")?.toIntOrNull() ?: 0
            val todayCount = prefs.getString("widget_revision_today_count", "0")?.toIntOrNull() ?: 0
            if (showUpcoming && upcomingCount > 0) {
                val headerLabel = if (todayCount > 0) "Current" else "Coming Soon"
                items.add(WidgetItem(
                    type = 0,
                    headerTitle = headerLabel,
                    headerColor = context.getColor(R.color.widget_accent_green)
                ))
                val upcomingJson = prefs.getString("widget_revision_upcoming_items", "[]") ?: "[]"
                val arr = JSONArray(upcomingJson)
                val maxItems = 5
                val showCount = minOf(arr.length(), maxItems)
                for (i in 0 until showCount) {
                    val obj = arr.getJSONObject(i)
                    items.add(WidgetItem(
                        type = 1,
                        subject = obj.optString("subjectName", "Unknown"),
                        topic = obj.optString("topicName", ""),
                        badge = obj.optString("dayLabel", ""),
                        isOverdue = false
                    ))
                }
                if (arr.length() > maxItems) {
                    items.add(WidgetItem(
                        type = 0,
                        headerTitle = "+${arr.length() - maxItems} more",
                        headerColor = context.getColor(R.color.widget_text_muted)
                    ))
                }
            }
        } catch (e: Exception) {
            // Silently handle errors
        }
    }

    override fun getCount(): Int = items.size

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 2

    override fun getViewAt(position: Int): RemoteViews {
        val item = items[position]
        return if (item.type == 0) {
            // Header
            val view = RemoteViews(context.packageName, R.layout.revision_widget_list_header)
            view.setTextViewText(R.id.section_title, item.headerTitle)
            view.setInt(R.id.section_dot, "setBackgroundColor", item.headerColor)
            view.setTextViewText(R.id.section_count, "")
            view.setTextColor(R.id.section_title, item.headerColor)
            view
        } else {
            // Item
            val view = RemoteViews(context.packageName, R.layout.revision_widget_list_item)
            view.setTextViewText(R.id.item_subject, item.subject)
            if (item.topic.isNotEmpty()) {
                view.setViewVisibility(R.id.item_topic, android.view.View.VISIBLE)
                view.setTextViewText(R.id.item_topic, item.topic)
            } else {
                view.setViewVisibility(R.id.item_topic, android.view.View.GONE)
            }
            view.setTextViewText(R.id.item_badge, item.badge)
            if (item.isOverdue) {
                view.setTextColor(R.id.item_badge, context.getColor(R.color.widget_accent_red))
            } else {
                view.setTextColor(R.id.item_badge, context.getColor(R.color.widget_primary))
            }
            view
        }
    }
}

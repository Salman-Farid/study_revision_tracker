package com.example.study_revision_tracker

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

class RevisionWidgetFactory(private val context: Context, intent: Intent) : RemoteViewsService.RemoteViewsFactory {

    private val items = mutableListOf<Map<String, String>>()
    private var isMissedMode = true

    override fun onCreate() {}

    override fun onDataSetChanged() {
        items.clear()
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val toggleMode = prefs.getString("widget_revision_toggle_mode", "missed") ?: "missed"
        isMissedMode = toggleMode != "upcoming"

        val itemsJson = if (isMissedMode) {
            prefs.getString("widget_revision_overdue_items", "[]") ?: "[]"
        } else {
            prefs.getString("widget_revision_upcoming_items", "[]") ?: "[]"
        }

        try {
            val arr = JSONArray(itemsJson)
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                val item = mutableMapOf<String, String>()
                item["topicName"] = obj.optString("topicName", "Unknown")
                item["subjectName"] = obj.optString("subjectName", "")
                item["scheduledDate"] = obj.optString("scheduledDate", "")
                item["dayLabel"] = obj.optString("dayLabel", "")
                items.add(item)
            }
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        items.clear()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val item = items[position]
        val row = RemoteViews(context.packageName, R.layout.revision_widget_item)
        row.setTextViewText(R.id.item_name, item["topicName"] ?: "Unknown")
        row.setTextViewText(R.id.item_subject, item["subjectName"] ?: "")
        val dayLabel = if (isMissedMode) {
            item["scheduledDate"] ?: item["dayLabel"] ?: ""
        } else {
            item["dayLabel"] ?: ""
        }
        row.setTextViewText(R.id.item_day_badge, dayLabel)

        if (isMissedMode) {
            row.setInt(R.id.item_dot, "setBackgroundResource", R.drawable.dot_circle_overdue)
            row.setInt(R.id.item_day_badge, "setBackgroundResource", R.drawable.badge_overdue_bg)
            row.setTextColor(R.id.item_day_badge, android.graphics.Color.parseColor("#D93025"))
        } else {
            row.setInt(R.id.item_dot, "setBackgroundResource", R.drawable.dot_circle_today)
            row.setInt(R.id.item_day_badge, "setBackgroundResource", R.drawable.badge_today_bg)
            row.setTextColor(R.id.item_day_badge, android.graphics.Color.parseColor("#1A73E8"))
        }
        return row
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true
}

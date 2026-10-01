package com.pootustudycompanion.app

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

class DailyRoutineWidgetFactory(private val context: Context, intent: Intent) : RemoteViewsService.RemoteViewsFactory {

    private val items = mutableListOf<Map<String, String>>()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        items.clear()
        try {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val upcomingJson = prefs.getString("widget_daily_upcoming_items", "[]") ?: "[]"
            if (upcomingJson.isBlank() || upcomingJson == "null") return
            val arr = JSONArray(upcomingJson)
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                val item = mutableMapOf<String, String>()
                item["timeText"] = obj.optString("timeText", "")
                item["subject"] = obj.optString("subject", "Unknown")
                item["topic"] = obj.optString("topic", "")
                item["type"] = obj.optString("type", "")
                items.add(item)
            }
        } catch (_: Exception) {
            items.clear()
        }
    }

    override fun onDestroy() {
        items.clear()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews? {
        if (position < 0 || position >= items.size) return null
        return try {
            val item = items[position]
            val row = RemoteViews(context.packageName, R.layout.daily_routine_widget_item)
            row.setTextViewText(R.id.item_time, item["timeText"] ?: "")
            row.setTextViewText(R.id.item_subject, item["subject"] ?: "Unknown")
            row.setTextViewText(R.id.item_topic, item["topic"] ?: "")
            row.setTextViewText(R.id.item_type, item["type"] ?: "")
            row
        } catch (_: Exception) {
            null
        }
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true
}

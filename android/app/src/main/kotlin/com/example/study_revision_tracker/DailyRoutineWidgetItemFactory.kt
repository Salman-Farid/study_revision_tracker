package com.example.study_revision_tracker

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject

class DailyRoutineWidgetItemFactory(private val context: Context, intent: Intent) : RemoteViewsService.RemoteViewsFactory {

    private var items: List<JSONObject> = emptyList()

    override fun onCreate() {
        val itemsJson = intent.getStringExtra("upcoming_json") ?: "[]"
        try {
            val array = JSONArray(itemsJson)
            items = (0 until array.length()).map { array.getJSONObject(it) }
        } catch (_: Exception) {
            items = emptyList()
        }
    }

    override fun onDataSetChanged() {}

    override fun onDestroy() {}

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val item = items[position]
        val subject = item.optString("subject", "Unknown")
        val topic = item.optString("topic", "")
        val type = item.optString("type", "")
        val timeText = item.optString("timeText", "")

        val rv = RemoteViews(context.packageName, R.layout.daily_routine_widget_item)
        rv.setTextViewText(R.id.item_subject, subject)
        rv.setTextViewText(R.id.item_topic, topic)
        rv.setTextViewText(R.id.item_type, type)
        rv.setTextViewText(R.id.item_time, timeText)

        return rv
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false
}

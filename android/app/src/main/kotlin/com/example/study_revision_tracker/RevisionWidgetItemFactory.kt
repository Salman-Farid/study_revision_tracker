package com.example.study_revision_tracker

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject

class RevisionWidgetItemFactory(private val context: Context, intent: Intent) : RemoteViewsService.RemoteViewsFactory {

    private var items: List<JSONObject> = emptyList()
    private var isMissedMode: Boolean = true

    override fun onCreate() {
        isMissedMode = intent.getBooleanExtra("is_missed_mode", true)
        val itemsJson = intent.getStringExtra("items_json") ?: "[]"
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
        val topicName = item.optString("topic_name", "Unknown")
        val subjectName = item.optString("subject_name", "")
        val dayLabel = item.optString("day_label", "")
        val dayNumber = item.optInt("day_number", 0)

        val rv = RemoteViews(context.packageName, R.layout.revision_widget_item)

        rv.setTextViewText(R.id.item_name, topicName)
        rv.setTextViewText(R.id.item_subject, subjectName)
        rv.setTextViewText(R.id.item_day_badge, dayLabel)

        // Color coding: red for overdue, green for upcoming
        if (isMissedMode) {
            rv.setIntResource(R.id.item_dot, "setBackgroundResource", R.drawable.dot_circle_overdue)
            rv.setIntResource(R.id.item_day_badge, "setBackgroundResource", R.drawable.badge_overdue_bg)
        } else {
            rv.setIntResource(R.id.item_dot, "setBackgroundResource", R.drawable.dot_circle_today)
            rv.setIntResource(R.id.item_day_badge, "setBackgroundResource", R.drawable.badge_today_bg)
        }

        return rv
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false
}

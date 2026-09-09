package com.example.study_revision_tracker

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject

class ClassRoutineWidgetItemFactory(private val context: Context, intent: Intent) : RemoteViewsService.RemoteViewsFactory {

    private var items: List<JSONObject> = emptyList()

    override fun onCreate() {
        val itemsJson = intent.getStringExtra("class_items_json") ?: "[]"
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
        val timeText = item.optString("timeText", "")
        val endTimeText = item.optString("endTimeText", "")
        val location = item.optString("location", "")
        val isCurrent = item.optBoolean("isCurrent", false)

        val rv = RemoteViews(context.packageName, R.layout.class_routine_widget_item)
        rv.setTextViewText(R.id.item_subject, subject)
        rv.setTextViewText(R.id.item_time, "$timeText – $endTimeText")

        if (location.isNotEmpty()) {
            rv.setTextViewText(R.id.item_location, location)
            rv.setViewVisibility(R.id.item_location, android.view.View.VISIBLE)
        } else {
            rv.setViewVisibility(R.id.item_location, android.view.View.GONE)
        }

        // NOW badge for current class
        if (isCurrent) {
            rv.setViewVisibility(R.id.item_now_badge, android.view.View.VISIBLE)
            rv.setIntResource(R.id.item_dot, "setBackgroundResource", R.drawable.dot_circle_now)
        } else {
            rv.setViewVisibility(R.id.item_now_badge, android.view.View.GONE)
            rv.setIntResource(R.id.item_dot, "setBackgroundResource", R.drawable.dot_circle_upcoming)
        }

        return rv
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false
}

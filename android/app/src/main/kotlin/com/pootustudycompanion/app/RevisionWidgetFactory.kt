package com.pootustudycompanion.app

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Locale

class RevisionWidgetFactory(
    private val context: Context,
    intent: Intent,
) : RemoteViewsService.RemoteViewsFactory {

    private val items = mutableListOf<Map<String, String>>()
    private var toggleMode = RevisionWidget.MODE_TODAY

    override fun onCreate() {}

    override fun onDataSetChanged() {
        items.clear()
        try {
            val prefs =
                context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            toggleMode = RevisionWidget.normalizeMode(
                prefs.getString(RevisionWidget.KEY_TOGGLE_MODE, RevisionWidget.MODE_TODAY),
            )

            val itemsJson = when (toggleMode) {
                RevisionWidget.MODE_MISSED ->
                    prefs.getString("widget_revision_overdue_items", "[]") ?: "[]"
                RevisionWidget.MODE_UPCOMING ->
                    prefs.getString("widget_revision_upcoming_items", "[]") ?: "[]"
                else ->
                    prefs.getString("widget_revision_today_items", "[]") ?: "[]"
            }

            if (itemsJson.isBlank() || itemsJson == "null") return

            val arr = JSONArray(itemsJson)
            for (i in 0 until arr.length()) {
                val obj = arr.optJSONObject(i) ?: continue
                items.add(
                    mapOf(
                        "topicName" to obj.optString("topicName", "Unknown"),
                        "subjectName" to obj.optString("subjectName", ""),
                        "scheduledDate" to obj.optString("scheduledDate", ""),
                        "dayLabel" to obj.optString("dayLabel", ""),
                    ),
                )
            }
        } catch (_: Exception) {
            items.clear()
        }
    }

    override fun onDestroy() {
        items.clear()
    }

    override fun getCount(): Int = items.size

    private fun prettyDate(raw: String): String {
        if (raw.isEmpty()) return ""
        return try {
            val inFmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val outFmt = SimpleDateFormat("d MMM yyyy", Locale.US)
            val d = inFmt.parse(raw.substring(0, 10))
            if (d != null) outFmt.format(d) else raw
        } catch (_: Exception) {
            raw
        }
    }

    override fun getViewAt(position: Int): RemoteViews? {
        if (position < 0 || position >= items.size) return null
        return try {
            val item = items[position]
            val row = RemoteViews(context.packageName, R.layout.revision_widget_item)

            val topic = item["topicName"] ?: "Unknown"
            val subject = item["subjectName"] ?: ""
            val date = prettyDate(item["scheduledDate"] ?: "")
            val day = item["dayLabel"] ?: ""

            row.setTextViewText(R.id.item_date, date.ifEmpty { day })
            row.setTextViewText(R.id.item_name, topic)
            row.setTextViewText(R.id.item_subject, subject)

            val badge: String
            val dateColor: Int
            val badgeColor: Int
            // First-class setTextColor only — never setInt reflection.
            when (toggleMode) {
                RevisionWidget.MODE_MISSED -> {
                    badge = if (day.isNotEmpty() && day != "Missed") day else "Missed"
                    dateColor = android.graphics.Color.parseColor("#D93025")
                    badgeColor = android.graphics.Color.parseColor("#D93025")
                }
                RevisionWidget.MODE_UPCOMING -> {
                    badge = day
                    dateColor = android.graphics.Color.parseColor("#1E8E3E")
                    badgeColor = android.graphics.Color.parseColor("#1E8E3E")
                }
                else -> {
                    badge = day
                    dateColor = android.graphics.Color.parseColor("#1A73E8")
                    badgeColor = android.graphics.Color.parseColor("#1A73E8")
                }
            }

            row.setTextViewText(R.id.item_day_badge, badge)
            row.setTextColor(R.id.item_day_badge, badgeColor)
            row.setTextColor(R.id.item_date, dateColor)
            row
        } catch (_: Exception) {
            null
        }
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = false
}

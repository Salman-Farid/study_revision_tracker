package com.example.study_revision_tracker

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Locale

class RevisionWidgetFactory(private val context: Context, intent: Intent) : RemoteViewsService.RemoteViewsFactory {

    private val items = mutableListOf<Map<String, String>>()
    private var toggleMode = RevisionWidget.MODE_TODAY

    override fun onCreate() {}

    override fun onDataSetChanged() {
        items.clear()
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        toggleMode = RevisionWidget.normalizeMode(
            prefs.getString(RevisionWidget.KEY_TOGGLE_MODE, RevisionWidget.MODE_TODAY)
        )

        val itemsJson = when (toggleMode) {
            RevisionWidget.MODE_MISSED ->
                prefs.getString("widget_revision_overdue_items", "[]") ?: "[]"
            RevisionWidget.MODE_UPCOMING ->
                prefs.getString("widget_revision_upcoming_items", "[]") ?: "[]"
            else ->
                prefs.getString("widget_revision_today_items", "[]") ?: "[]"
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

    /** "2026-09-10" → "10 Sep 2026" */
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

    override fun getViewAt(position: Int): RemoteViews {
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
        val dateColor: String
        val badgeBg: Int
        val badgeColor: String
        val dotBg: Int

        when (toggleMode) {
            RevisionWidget.MODE_MISSED -> {
                badge = if (day.isNotEmpty() && day != "Missed") day else "Missed"
                dateColor = "#D93025"
                badgeBg = R.drawable.badge_overdue_bg
                badgeColor = "#D93025"
                dotBg = R.drawable.dot_circle_overdue
            }
            RevisionWidget.MODE_UPCOMING -> {
                badge = day
                dateColor = "#1E8E3E"
                badgeBg = R.drawable.badge_upcoming_bg
                badgeColor = "#1E8E3E"
                dotBg = R.drawable.dot_circle_today
            }
            else -> {
                // Today
                badge = day
                dateColor = "#1A73E8"
                badgeBg = R.drawable.badge_today_bg
                badgeColor = "#1A73E8"
                dotBg = R.drawable.dot_circle_today
            }
        }

        row.setTextViewText(R.id.item_day_badge, badge)
        row.setInt(R.id.item_dot, "setBackgroundResource", dotBg)
        row.setInt(R.id.item_day_badge, "setBackgroundResource", badgeBg)
        row.setTextColor(R.id.item_day_badge, android.graphics.Color.parseColor(badgeColor))
        row.setTextColor(R.id.item_date, android.graphics.Color.parseColor(dateColor))
        return row
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true
}

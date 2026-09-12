package com.example.study_revision_tracker

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import java.util.Locale

class ClassRoutineWidgetFactory(
    private val context: Context,
    intent: Intent,
) : RemoteViewsService.RemoteViewsFactory {

    private val items = mutableListOf<RowData>()
    private var showDuration = false

    private data class RowData(
        val subject: String,
        val timeLine: String,
        val location: String,
        val durationText: String,
        val subjectColor: Int,
        val timeColor: Int,
        val locationColor: Int,
    )

    override fun onCreate() {}

    override fun onDataSetChanged() {
        items.clear()
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        showDuration = prefs.getString("widget_class_show_duration", "false") == "true"

        var itemsJson = prefs.getString("widget_class_today_items", null)
        if (itemsJson == null) {
            val all = prefs.getString("widget_class_items", "[]") ?: "[]"
            itemsJson = filterToday(all)
        }

        val arr = try { JSONArray(itemsJson) } catch (_: Exception) { JSONArray() }
        val nowMs = System.currentTimeMillis()

        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val startTs = o.optLong("startTimestamp", 0L)
            val endTs = o.optLong("endTimestamp", 0L)
            val isNow = o.optBoolean("isCurrent", false) ||
                (startTs > 0L && endTs > 0L && nowMs in startTs until endTs)
            // Current class is shown in the NOW header — not as a list row.
            if (isNow) continue

            val isPast = o.optBoolean("isPast", false) || (endTs > 0L && nowMs >= endTs)
            val subject = o.optString("subject", "")
            val timeText = o.optString("timeText", "")
            val endText = o.optString("endTimeText", "")
            val location = o.optString("location", "")
            val timeLine = if (endText.isNotEmpty()) "$timeText – $endText" else timeText
            val suffix = if (isPast) "  ·  Done" else ""

            val paletteIndex = items.size
            val timeCol: Int = if (isPast) 0x66000000.toInt() else 0xFF5C6BC0.toInt()
            val locCol: Int = if (isPast) 0x66000000.toInt() else 0xFFEF6C00.toInt()
            val subCol: Int = if (isPast) 0x88000000.toInt() else PALETTE[paletteIndex % PALETTE.size]

            val durMin = o.optInt("durationMinutes", 0)
            val durText = when {
                durMin > 0 -> {
                    val hours = durMin / 60.0
                    if (durMin % 60 == 0 && durMin >= 60) "${durMin / 60} hours"
                    else if (hours >= 1) {
                        val formatted = String.format(Locale.US, "%.1f", hours)
                        "$formatted hours"
                    } else "$durMin min"
                }
                o.optString("durationText", "").isNotEmpty() -> o.optString("durationText")
                else -> ""
            }

            items.add(
                RowData(
                    subject = subject,
                    timeLine = timeLine + suffix,
                    location = location,
                    durationText = durText,
                    subjectColor = subCol,
                    timeColor = timeCol,
                    locationColor = locCol,
                )
            )
        }
    }

    override fun onDestroy() {
        items.clear()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val item = items[position]
        val row = RemoteViews(context.packageName, R.layout.class_routine_widget_item)
        row.setTextViewText(R.id.row_subject, item.subject)
        row.setTextViewText(R.id.row_time, item.timeLine)
        if (item.location.isNotEmpty()) {
            row.setViewVisibility(R.id.row_location, android.view.View.VISIBLE)
            row.setTextViewText(R.id.row_location, item.location)
        } else {
            row.setViewVisibility(R.id.row_location, android.view.View.GONE)
        }
        if (showDuration && item.durationText.isNotEmpty()) {
            row.setViewVisibility(R.id.row_duration_box, android.view.View.VISIBLE)
            row.setTextViewText(R.id.row_duration, item.durationText)
            row.setTextColor(R.id.row_duration, item.subjectColor)
        } else {
            row.setViewVisibility(R.id.row_duration_box, android.view.View.GONE)
        }
        row.setTextColor(R.id.row_subject, item.subjectColor)
        row.setTextColor(R.id.row_time, item.timeColor)
        row.setTextColor(R.id.row_location, item.locationColor)
        return row
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true

    private fun filterToday(allJson: String): String {
        return try {
            val src = JSONArray(allJson)
            val out = JSONArray()
            for (i in 0 until src.length()) {
                val o = src.getJSONObject(i)
                if (o.optBoolean("isToday", false) || o.optBoolean("isCurrent", false)) {
                    out.put(o)
                }
            }
            out.toString()
        } catch (_: Exception) {
            "[]"
        }
    }

    companion object {
        private val PALETTE = intArrayOf(
            0xFF1A73E8.toInt(),
            0xFF6A1B9A.toInt(),
            0xFFC62828.toInt(),
            0xFF00897B.toInt(),
            0xFFEF6C00.toInt(),
            0xFF2E7D32.toInt(),
            0xFFAD1457.toInt(),
            0xFF4527A0.toInt(),
        )
    }
}

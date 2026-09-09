package com.example.study_revision_tracker

import android.content.Intent
import android.widget.RemoteViewsService

class ClassRoutineWidgetListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return ClassRoutineWidgetItemFactory(applicationContext, intent)
    }
}

package com.example.study_revision_tracker

import android.content.Intent
import android.widget.RemoteViewsService

class ClassRoutineWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return ClassRoutineWidgetFactory(applicationContext, intent)
    }
}

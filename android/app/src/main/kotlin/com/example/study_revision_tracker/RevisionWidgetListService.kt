package com.example.study_revision_tracker

import android.content.Intent
import android.widget.RemoteViewsService

class RevisionWidgetListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return RevisionWidgetItemFactory(applicationContext, intent)
    }
}

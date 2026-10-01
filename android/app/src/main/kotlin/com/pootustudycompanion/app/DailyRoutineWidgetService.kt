package com.pootustudycompanion.app

import android.content.Intent
import android.widget.RemoteViewsService

class DailyRoutineWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return DailyRoutineWidgetFactory(applicationContext, intent)
    }
}

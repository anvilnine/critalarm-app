package app.critalarm.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle

/**
 * One topic, picked in [TopicWidgetConfigActivity], with "I'm up" or "Done"
 * for its incident.
 */
class TopicWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        val snapshot = WidgetSnapshotStore(context).read()
        for (id in appWidgetIds) WidgetRedraw.drawTopic(context, manager, id, snapshot)
        WidgetRedraw.refreshFrom(this, context)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        WidgetRedraw.drawTopic(context, manager, appWidgetId, WidgetSnapshotStore(context).read())
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val prefs = WidgetTopicPrefs(context)
        for (id in appWidgetIds) prefs.delete(id)
    }
}

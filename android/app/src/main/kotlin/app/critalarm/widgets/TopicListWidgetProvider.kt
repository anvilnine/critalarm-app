package app.critalarm.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Bundle

/** Every topic and its state, as many rows as the widget is tall. */
class TopicListWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        val snapshot = WidgetSnapshotStore(context).read()
        for (id in appWidgetIds) WidgetRedraw.drawList(context, manager, id, snapshot)
        WidgetRedraw.refreshFrom(this, context)
    }

    /** A resize changes how many rows fit. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        WidgetRedraw.drawList(context, manager, appWidgetId, WidgetSnapshotStore(context).read())
    }
}

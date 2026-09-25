package app.critalarm.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context

/**
 * The 1x1 open count. Also offered for the lock screen where the OS still
 * allows lock screen widgets.
 */
class OpenCountWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, appWidgetIds: IntArray) {
        val snapshot = WidgetSnapshotStore(context).read()
        for (id in appWidgetIds) WidgetRedraw.drawCount(context, manager, id, snapshot)
        WidgetRedraw.refreshFrom(this, context)
    }
}

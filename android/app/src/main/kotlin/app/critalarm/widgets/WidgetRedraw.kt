package app.critalarm.widgets

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context

/**
 * Draws every widget again after the snapshot changed, then fetches when the
 * snapshot is stale. The list widget draws its rows straight into its
 * RemoteViews with no collection adapter, so a redraw is always a full
 * updateAppWidget.
 */
object WidgetRedraw {
    /** Assumed until the launcher reports the list widget's height. */
    private const val DEFAULT_HEIGHT_DP = 110

    fun all(context: Context) {
        drawAll(context)
        WidgetRefresher.refreshIfStale(context) {}
    }

    fun drawAll(context: Context) {
        val app = context.applicationContext
        val manager = AppWidgetManager.getInstance(app) ?: return
        val snapshot = WidgetSnapshotStore(app).read()
        for (id in ids(app, manager, TopicListWidgetProvider::class.java)) drawList(app, manager, id, snapshot)
        for (id in ids(app, manager, TopicWidgetProvider::class.java)) drawTopic(app, manager, id, snapshot)
        for (id in ids(app, manager, OpenCountWidgetProvider::class.java)) drawCount(app, manager, id, snapshot)
    }

    fun drawList(context: Context, manager: AppWidgetManager, id: Int, snapshot: WidgetSnapshot?) {
        manager.updateAppWidget(id, WidgetViews.listViews(context, snapshot, heightDp(manager, id)))
    }

    fun drawTopic(context: Context, manager: AppWidgetManager, id: Int, snapshot: WidgetSnapshot?) {
        val topic = WidgetTopicPrefs(context).read(id)
        manager.updateAppWidget(id, WidgetViews.topicViews(context, snapshot, topic, id))
    }

    fun drawCount(context: Context, manager: AppWidgetManager, id: Int, snapshot: WidgetSnapshot?) {
        manager.updateAppWidget(id, WidgetViews.countViews(context, snapshot))
    }

    /**
     * Fetches when stale from inside a provider's onUpdate. goAsync keeps the
     * broadcast open until the refresher is done, and its 8 s budget keeps
     * that inside the time Android gives a broadcast receiver.
     */
    fun refreshFrom(receiver: BroadcastReceiver, context: Context) {
        val pending = receiver.goAsync()
        WidgetRefresher.refreshIfStale(context) { pending.finish() }
    }

    /** In portrait the widget is as tall as the max height the launcher reports. */
    private fun heightDp(manager: AppWidgetManager, id: Int): Int {
        val options = manager.getAppWidgetOptions(id)
        val max = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
        val min = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
        return when {
            max > 0 -> max
            min > 0 -> min
            else -> DEFAULT_HEIGHT_DP
        }
    }

    private fun ids(context: Context, manager: AppWidgetManager, provider: Class<*>): IntArray =
        manager.getAppWidgetIds(ComponentName(context, provider))
}

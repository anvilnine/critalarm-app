package app.critalarm.widgets

import android.content.Context

/**
 * Draws every widget again after the snapshot changed.
 *
 * There are no widgets yet, so all this does is fetch when the snapshot is
 * stale. The widget providers join here when they exist.
 */
object WidgetRedraw {
    fun all(context: Context) {
        WidgetRefresher.refreshIfStale(context) {}
    }
}

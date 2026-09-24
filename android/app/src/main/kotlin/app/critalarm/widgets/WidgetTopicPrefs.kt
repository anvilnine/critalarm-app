package app.critalarm.widgets

import android.content.Context

/**
 * Which topic each per-topic widget shows: `topic_for_widget.<appWidgetId>`
 * in the `critalarm_widgets` preferences, next to the snapshot.
 */
class WidgetTopicPrefs(context: Context) {
    private val preferences = context.applicationContext
        .getSharedPreferences(WidgetSnapshotStore.PREFS, Context.MODE_PRIVATE)

    fun read(appWidgetId: Int): String? = preferences.getString(key(appWidgetId), null)

    fun write(appWidgetId: Int, topic: String) {
        preferences.edit().putString(key(appWidgetId), topic).apply()
    }

    fun delete(appWidgetId: Int) {
        preferences.edit().remove(key(appWidgetId)).apply()
    }

    private fun key(appWidgetId: Int) = "topic_for_widget.$appWidgetId"
}

package app.critalarm.widgets

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.ListView
import app.critalarm.l10n.NativeText
import app.critalarm.l10n.NativeWords

/**
 * Picks the topic a per-topic widget shows, from the topics in the snapshot.
 * Backing out leaves no widget behind: the result stays CANCELED until a pick.
 */
class TopicWidgetConfigActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        val appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        // In the language picked in the app, also below Android 13.
        val words = NativeWords.of(this)
        title = words.text(NativeText.WIDGET_CHOOSE_TOPIC)
        val snapshot = WidgetSnapshotStore(this).read()
        val names = if (snapshot?.connected == true) snapshot.topics.map { it.name } else emptyList()
        val list = ListView(this)
        if (names.isEmpty()) {
            list.adapter = ArrayAdapter(
                this,
                android.R.layout.simple_list_item_1,
                listOf(words.text(NativeText.WIDGET_OPEN_APP_FIRST)),
            )
            list.setOnItemClickListener { _, _, _, _ -> finish() }
        } else {
            list.adapter = ArrayAdapter(this, android.R.layout.simple_list_item_1, names)
            list.setOnItemClickListener { _, _, position, _ -> pick(appWidgetId, names[position]) }
        }
        setContentView(list)
    }

    /**
     * Below Android 12 the launcher does not call onUpdate after this
     * activity, so the draw here is the widget's first.
     */
    private fun pick(appWidgetId: Int, topic: String) {
        WidgetTopicPrefs(this).write(appWidgetId, topic)
        WidgetRedraw.drawTopic(
            this,
            AppWidgetManager.getInstance(this),
            appWidgetId,
            WidgetSnapshotStore(this).read(),
        )
        setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId))
        finish()
    }
}

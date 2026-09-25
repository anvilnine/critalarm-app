package app.critalarm.widgets

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import app.critalarm.MainActivity
import app.critalarm.R
import app.critalarm.actions.IncidentActionReceiver
import app.critalarm.notifications.CritAlarmFace
import app.critalarm.notifications.FaceBitmap
import app.critalarm.storage.NativeConnectionStore

/**
 * Builds the RemoteViews for the three widgets from the snapshot. The words
 * come from [WidgetRows], the faces from [FaceBitmap].
 */
object WidgetViews {
    /** Small faces keep a list of 8 rows well under the RemoteViews binder limit. */
    private const val ROW_FACE_PX = 48
    private const val TOPIC_FACE_DP = 34
    private const val COUNT_FACE_DP = 24

    fun listViews(context: Context, snapshot: WidgetSnapshot?, heightDp: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_topic_list)
        if (snapshot?.locked == true) {
            views.setOnClickPendingIntent(android.R.id.background, paywallIntent(context))
            views.setTextViewText(R.id.list_count, "")
            views.setViewVisibility(R.id.rows, View.GONE)
            views.setViewVisibility(R.id.list_more, View.GONE)
            views.setViewVisibility(R.id.list_message, View.VISIBLE)
            views.setTextViewText(R.id.list_message, WidgetRows.LOCKED)
            return views
        }
        views.removeAllViews(R.id.rows)
        views.setOnClickPendingIntent(android.R.id.background, homeIntent(context))
        val message = message(snapshot)
        if (message != null || snapshot == null) {
            views.setTextViewText(R.id.list_count, "")
            views.setViewVisibility(R.id.rows, View.GONE)
            views.setViewVisibility(R.id.list_more, View.GONE)
            views.setViewVisibility(R.id.list_message, View.VISIBLE)
            views.setTextViewText(R.id.list_message, message)
            return views
        }
        views.setViewVisibility(R.id.rows, View.VISIBLE)
        views.setViewVisibility(R.id.list_message, View.GONE)
        views.setTextViewText(R.id.list_count, WidgetRows.countText(snapshot.openCount))
        val list = WidgetRows.listRows(snapshot, heightDp)
        for (topic in list.rows) views.addView(R.id.rows, rowViews(context, topic))
        if (list.more > 0) {
            views.setViewVisibility(R.id.list_more, View.VISIBLE)
            views.setTextViewText(R.id.list_more, WidgetRows.moreText(list.more))
        } else {
            views.setViewVisibility(R.id.list_more, View.GONE)
        }
        return views
    }

    private fun rowViews(context: Context, topic: WidgetTopic): RemoteViews {
        val row = RemoteViews(context.packageName, R.layout.widget_topic_row)
        val incident = topic.incident
        row.setImageViewBitmap(R.id.row_face, FaceBitmap.render(WidgetRows.face(incident), ROW_FACE_PX))
        row.setTextViewText(R.id.row_name, topic.name)
        row.setTextViewText(R.id.row_title, incident?.title ?: "")
        row.setViewVisibility(R.id.row_title, if (incident == null) View.GONE else View.VISIBLE)
        showState(row, incident, R.id.row_state, R.id.row_state_awake, R.id.row_state_quiet)
        showTimer(row, R.id.row_since, incident)
        row.setOnClickPendingIntent(R.id.row, topicIntent(context, topic.name))
        return row
    }

    fun topicViews(
        context: Context,
        snapshot: WidgetSnapshot?,
        topicName: String?,
        appWidgetId: Int,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_topic)
        if (snapshot?.locked == true) {
            views.setViewVisibility(R.id.topic_content, View.GONE)
            views.setViewVisibility(R.id.topic_message, View.VISIBLE)
            views.setTextViewText(R.id.topic_message, WidgetRows.LOCKED)
            views.setOnClickPendingIntent(android.R.id.background, paywallIntent(context))
            return views
        }
        val topic = snapshot?.topics?.firstOrNull { it.name == topicName }
        val message = message(snapshot) ?: if (topic == null) WidgetRows.TOPIC_NOT_FOUND else null
        if (message != null || topic == null) {
            views.setViewVisibility(R.id.topic_content, View.GONE)
            views.setViewVisibility(R.id.topic_message, View.VISIBLE)
            views.setTextViewText(R.id.topic_message, message)
            views.setOnClickPendingIntent(android.R.id.background, homeIntent(context))
            return views
        }
        views.setViewVisibility(R.id.topic_content, View.VISIBLE)
        views.setViewVisibility(R.id.topic_message, View.GONE)
        val incident = topic.incident
        val facePx = (TOPIC_FACE_DP * context.resources.displayMetrics.density).toInt()
        views.setImageViewBitmap(R.id.topic_face, FaceBitmap.render(WidgetRows.face(incident), facePx))
        showState(views, incident, R.id.topic_state, R.id.topic_state_awake, R.id.topic_state_quiet)
        showTimer(views, R.id.topic_since, incident)
        views.setTextViewText(R.id.topic_name, topic.name)
        views.setTextViewText(R.id.topic_title, incident?.title ?: WidgetRows.ALL_QUIET)
        views.setOnClickPendingIntent(android.R.id.background, topicIntent(context, topic.name))
        val button = WidgetRows.buttonTitle(incident)
        if (button == null || incident == null) {
            views.setViewVisibility(R.id.topic_button, View.GONE)
        } else {
            views.setViewVisibility(R.id.topic_button, View.VISIBLE)
            views.setTextViewText(R.id.topic_button, button)
            views.setOnClickPendingIntent(R.id.topic_button, actionIntent(context, incident, appWidgetId))
        }
        return views
    }

    fun countViews(context: Context, snapshot: WidgetSnapshot?): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_open_count)
        if (snapshot?.locked == true) {
            views.setOnClickPendingIntent(android.R.id.background, paywallIntent(context))
            views.setViewVisibility(R.id.count_content, View.GONE)
            views.setViewVisibility(R.id.count_message, View.VISIBLE)
            views.setTextViewText(R.id.count_message, WidgetRows.LOCKED_SHORT)
            return views
        }
        views.setOnClickPendingIntent(android.R.id.background, homeIntent(context))
        // No topics is still a count: zero, all quiet.
        val message = if (snapshot == null || !snapshot.connected) WidgetRows.NOT_CONNECTED else null
        if (message != null || snapshot == null) {
            views.setViewVisibility(R.id.count_content, View.GONE)
            views.setViewVisibility(R.id.count_message, View.VISIBLE)
            views.setTextViewText(R.id.count_message, message)
            return views
        }
        views.setViewVisibility(R.id.count_content, View.VISIBLE)
        views.setViewVisibility(R.id.count_message, View.GONE)
        val facePx = (COUNT_FACE_DP * context.resources.displayMetrics.density).toInt()
        views.setImageViewBitmap(R.id.count_face, FaceBitmap.render(WidgetRows.worstFace(snapshot), facePx))
        if (snapshot.openCount > 0) {
            views.setViewVisibility(R.id.count_number, View.VISIBLE)
            views.setTextViewText(R.id.count_number, snapshot.openCount.toString())
            views.setTextViewText(R.id.count_label, "open")
        } else {
            views.setViewVisibility(R.id.count_number, View.GONE)
            views.setTextViewText(R.id.count_label, WidgetRows.ALL_QUIET)
        }
        return views
    }

    /** The empty states every list shares, or null when there is something to list. */
    private fun message(snapshot: WidgetSnapshot?): String? = when {
        snapshot == null || !snapshot.connected -> WidgetRows.NOT_CONNECTED
        snapshot.topics.isEmpty() -> WidgetRows.NO_TOPICS
        else -> null
    }

    /**
     * Three text views per state word, one per colour, because a colour set
     * from code would not follow the launcher into dark mode. The resource
     * colours in the layout do.
     */
    private fun showState(views: RemoteViews, incident: WidgetIncident?, ringing: Int, awake: Int, quiet: Int) {
        val shown = when (WidgetRows.face(incident)) {
            CritAlarmFace.ALARMED -> ringing
            CritAlarmFace.ACKED -> awake
            else -> quiet
        }
        for (id in listOf(ringing, awake, quiet)) {
            views.setViewVisibility(id, if (id == shown) View.VISIBLE else View.GONE)
        }
        views.setTextViewText(shown, WidgetRows.stateWord(incident))
    }

    /**
     * A live count-up since the incident opened, like the iOS widget's timer.
     * The launcher ticks it, so nothing here has to redraw every second.
     */
    private fun showTimer(views: RemoteViews, id: Int, incident: WidgetIncident?) {
        val opened = WidgetRows.openedSeconds(incident)
        if (opened == null) {
            views.setChronometer(id, SystemClock.elapsedRealtime(), null, false)
            views.setViewVisibility(id, View.GONE)
            return
        }
        val base = WidgetRows.chronometerBase(opened, System.currentTimeMillis(), SystemClock.elapsedRealtime())
        views.setChronometer(id, base, null, true)
        views.setViewVisibility(id, View.VISIBLE)
    }

    private fun topicIntent(context: Context, topic: String): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            data = Uri.parse("critalarm://topics/${Uri.encode(topic)}")
            putExtra(MainActivity.EXTRA_TOPIC, topic)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(context, requestCode("topic:$topic"), intent, FLAGS)
    }

    private fun homeIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            data = Uri.parse("critalarm://home")
            putExtra(MainActivity.EXTRA_OPEN, MainActivity.OPEN_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(context, requestCode("home"), intent, FLAGS)
    }

    private fun paywallIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            data = Uri.parse("critalarm://paywall")
            putExtra(MainActivity.EXTRA_OPEN, MainActivity.OPEN_PAYWALL)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(context, requestCode("paywall"), intent, FLAGS)
    }

    /**
     * "I'm up" is the notification's Stop, "Done" its acknowledge (which the
     * receiver maps to close). The data URI keeps each widget's button apart.
     */
    private fun actionIntent(context: Context, incident: WidgetIncident, appWidgetId: Int): PendingIntent {
        val ack = incident.state == WidgetSnapshot.OPEN
        val intent = Intent(context, IncidentActionReceiver::class.java).apply {
            action = if (ack) IncidentActionReceiver.ACTION_STOP else IncidentActionReceiver.ACTION_ACKNOWLEDGE
            data = Uri.parse("critalarm://widgets/$appWidgetId/${Uri.encode(incident.id)}")
            putExtra(IncidentActionReceiver.EXTRA_INCIDENT_ID, incident.id)
            NativeConnectionStore(context).canonicalServer()?.let {
                putExtra(IncidentActionReceiver.EXTRA_SERVER, it.toString())
            }
            putExtra(IncidentActionReceiver.EXTRA_TITLE, incident.title)
        }
        val code = requestCode("${if (ack) "ack" else "close"}:$appWidgetId")
        return PendingIntent.getBroadcast(context, code, intent, FLAGS)
    }

    private fun requestCode(key: String) = "widget:$key".hashCode()

    private const val FLAGS = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
}

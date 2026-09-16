package app.critalarm.notifications

import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import app.critalarm.R
import app.critalarm.actions.IncidentActionReceiver
import app.critalarm.notifications.LiveUpdate.requestPromotion
import app.critalarm.notifications.LiveUpdate.shortCriticalText
import app.critalarm.push.FcmIncidentPayload
import app.critalarm.push.IncidentContent
import app.critalarm.push.IncidentContentFetcher
import app.critalarm.storage.TopicTimerStore

object StatusNotificationFactory {
    /** The face is drawn at this many pixels. Large enough for the shade. */
    private const val FACE_PX = 192

    fun notificationId(incidentId: String) = incidentId.hashCode() xor 0x5f3759df

    fun create(
        context: Context,
        payload: FcmIncidentPayload,
        content: IncidentContent = IncidentContentFetcher.fallback(payload),
        state: IncidentCardState = IncidentCardState.ACKED,
        openedAtMillis: Long = System.currentTimeMillis(),
    ): Notification {
        NotificationChannels.ensureCreated(context)
        val incidentId = payload.incidentId ?: ""
        val intent = Intent(context, IncidentActionReceiver::class.java).apply {
            action = IncidentActionReceiver.ACTION_ACKNOWLEDGE
            putExtra(IncidentActionReceiver.EXTRA_INCIDENT_ID, incidentId)
            putExtra(IncidentActionReceiver.EXTRA_SERVER, payload.server.toString())
        }
        val pending = PendingIntent.getBroadcast(
            context,
            notificationId(incidentId),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val title = NtfyEmoji.prefixTitle(content.title, content.tags)

        val builder = NotificationCompat.Builder(context, NotificationChannels.cardChannelId())
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setLargeIcon(FaceBitmap.render(state.face, FACE_PX))
            .setContentTitle(title)
            .setContentText(content.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(content.body))
            .setColor(state.accentColor)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setWhen(openedAtMillis)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .shortCriticalText(state.chipText)
            .requestPromotion()

        // The button closes the incident. IncidentActionRouter maps the
        // "acknowledge" trigger to IncidentAction.CLOSE, so the old
        // "Acknowledge" label named a different step than the one it ran. iOS
        // hit this and renamed it too, see IncidentActivityWidget.swift.
        if (state == IncidentCardState.ACKED) {
            builder.addAction(0, "Done", pending)
        }

        applyCountdown(context, builder, content, state, openedAtMillis)
        return builder.build()
    }

    /**
     * The bar. Unacked it counts down to the next ring, acked it counts down
     * the desk timer. Closed and expired have nothing left to wait for, so
     * they get no bar. No cached timers also means no bar.
     *
     * The topic comes off [IncidentContent], which is the only thing here that
     * carries one. A push does not: api.md 5.2 has no topic field and adding
     * one is a contract change. So a card built from the fallback content,
     * before GET /v1/incidents/{id} answers, gets no bar, and the refresh that
     * follows the fetch is what puts it there.
     */
    private fun applyCountdown(
        context: Context,
        builder: NotificationCompat.Builder,
        content: IncidentContent,
        state: IncidentCardState,
        openedAtMillis: Long,
    ) {
        if (state != IncidentCardState.OPEN && state != IncidentCardState.ACKED) return
        val topic = content.topic ?: return
        val timers = TopicTimerStore(context).timersFor(topic) ?: return
        val seconds =
            if (state == IncidentCardState.OPEN) timers.repeatIntervalS else timers.deskTimerS
        builder.setWhen(openedAtMillis + seconds * 1000L)
            .setChronometerCountDown(true)
            .setUsesChronometer(true)
    }
}

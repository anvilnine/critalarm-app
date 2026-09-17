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
import app.critalarm.storage.TopicTimers

object StatusNotificationFactory {
    /** The face is drawn at this many pixels. Large enough for the shade. */
    private const val FACE_PX = 192

    fun notificationId(incidentId: String) = incidentId.hashCode() xor 0x5f3759df

    /**
     * What the bar counts: from [startMillis] to [endMillis]. Null means no
     * bar at all.
     */
    data class Countdown(val startMillis: Long, val endMillis: Long)

    fun create(
        context: Context,
        payload: FcmIncidentPayload,
        content: IncidentContent = IncidentContentFetcher.fallback(payload),
        state: IncidentCardState = IncidentCardState.ACKED,
        ackedAtMillis: Long = System.currentTimeMillis(),
        deskTimerEndMillis: Long? = null,
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
            .setWhen(ackedAtMillis)
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

        applyCountdown(context, builder, content, state, ackedAtMillis, deskTimerEndMillis)
        return builder.build()
    }

    /**
     * Puts the bar on the card, or leaves the big text there when there is
     * nothing to count. Both readings hold at once: the chronometer set above
     * counts up from when the incident opened, and this counts the wait down.
     */
    private fun applyCountdown(
        context: Context,
        builder: NotificationCompat.Builder,
        content: IncidentContent,
        state: IncidentCardState,
        openedAtMillis: Long,
        deskTimerEndMillis: Long?,
    ) {
        val timers = content.topic?.let { TopicTimerStore(context).timersFor(it) }
        val countdown = countdownFor(state, timers, openedAtMillis, deskTimerEndMillis) ?: return
        val total = (countdown.endMillis - countdown.startMillis) / 1000L
        val elapsed = (System.currentTimeMillis() - countdown.startMillis) / 1000L
        val bar = LiveUpdate.countdownBar(elapsed, total, state.accentColor) ?: return
        builder.setStyle(bar)
    }

    /**
     * The bar. Unacked it counts down to the next ring, acked it counts down
     * the desk timer. Closed and expired have nothing left to wait for, so
     * they get no bar. No cached timers also means no bar.
     *
     * An acked card prefers [deskTimerEndMillis], the absolute instant the ack
     * response carried (api.md §3.2). The cached duration is the fallback,
     * because counting it from the device clock restarts a wait another device
     * may already be halfway through.
     *
     * The topic comes off [IncidentContent], which is the only thing here that
     * carries one. A push does not: api.md §5.2 has no topic field and adding
     * one is a contract change. So a card built from the fallback content,
     * before GET /v1/incidents/{id} answers, gets no bar unless the ack
     * response gave one, and the refresh that follows the fetch is what puts
     * it there.
     */
    fun countdownFor(
        state: IncidentCardState,
        timers: TopicTimers?,
        startMillis: Long,
        deskTimerEndMillis: Long?,
    ): Countdown? {
        if (state == IncidentCardState.ACKED && deskTimerEndMillis != null && deskTimerEndMillis > startMillis) {
            return Countdown(startMillis, deskTimerEndMillis)
        }
        val seconds = when (state) {
            IncidentCardState.OPEN -> timers?.repeatIntervalS
            IncidentCardState.ACKED -> timers?.deskTimerS
            IncidentCardState.CLOSED, IncidentCardState.EXPIRED -> null
        } ?: return null
        return Countdown(startMillis, startMillis + seconds * 1000L)
    }
}

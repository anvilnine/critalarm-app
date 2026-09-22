package app.critalarm.notifications

import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.app.NotificationCompat
import app.critalarm.MainActivity
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

    /**
     * The button's request code, kept apart from the content intent's. The two
     * are different PendingIntents and must not share a slot.
     */
    private const val ACTION_SALT = 0x41435401

    fun notificationId(incidentId: String) = incidentId.hashCode() xor 0x5f3759df

    /**
     * What the timer counts: from [startMillis] to [endMillis]. Null means
     * nothing to count down to.
     */
    data class Countdown(val startMillis: Long, val endMillis: Long)

    /**
     * The text a silenced card carries. `en.json` holds the same sentence for
     * the in-app screen; this copy is here because the card is built with no
     * Flutter engine running.
     */
    fun silencedText(seconds: Int) = "Stopped. Rings again in $seconds s. Tap I'm up to end it."

    /**
     * Builds the card for one incident state.
     *
     * [silencedInSeconds] non-null means the card is the silenced one: the text
     * counts to the next ring, and the one button is "I'm up", the only way out
     * of the loop. Otherwise an acked card is built, with "Done" on it.
     *
     * [countdownEndMillis] is the instant the chronometer counts down to, when
     * the rule found one. Null means nothing to count, and the timer counts up
     * from [ackedAtMillis] instead.
     */
    fun create(
        context: Context,
        payload: FcmIncidentPayload,
        content: IncidentContent = IncidentContentFetcher.fallback(payload),
        state: IncidentCardState = IncidentCardState.ACKED,
        ackedAtMillis: Long = System.currentTimeMillis(),
        silencedInSeconds: Int? = null,
        countdownEndMillis: Long? = null,
    ): Notification {
        NotificationChannels.ensureCreated(context)
        val incidentId = payload.incidentId ?: ""
        val immutable = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val title = NtfyEmoji.prefixTitle(content.title, content.tags)
        val body = silencedInSeconds?.let { silencedText(it) } ?: content.body

        val builder = NotificationCompat.Builder(context, NotificationChannels.cardChannelId())
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setLargeIcon(FaceBitmap.render(state.face, FACE_PX))
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setColor(state.accentColor)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(
                PendingIntent.getActivity(
                    context,
                    notificationId(incidentId),
                    incidentLaunchIntent(context, incidentId),
                    immutable,
                ),
            )
            .shortCriticalText(state.chipText)
            .requestPromotion()

        if (silencedInSeconds != null) {
            // "I'm up" is the acknowledge and the only way out of the loop.
            val imUp = Intent(context, IncidentActionReceiver::class.java).apply {
                action = IncidentActionReceiver.ACTION_STOP
                putExtra(IncidentActionReceiver.EXTRA_INCIDENT_ID, incidentId)
                putExtra(IncidentActionReceiver.EXTRA_SERVER, payload.server.toString())
                putExtra(IncidentActionReceiver.EXTRA_TITLE, content.title)
                putExtra(IncidentActionReceiver.EXTRA_BODY, content.body)
                putExtra(IncidentActionReceiver.EXTRA_HAND_OVER, true)
            }
            builder.addAction(
                0,
                "I'm up",
                PendingIntent.getBroadcast(
                    context,
                    notificationId(incidentId) xor ACTION_SALT,
                    imUp,
                    immutable,
                ),
            )
        } else if (state == IncidentCardState.ACKED) {
            // The button closes the incident. IncidentActionRouter maps the
            // "acknowledge" trigger to IncidentAction.CLOSE, so the old
            // "Acknowledge" label named a different step than the one it ran.
            // iOS hit this and renamed it too, see IncidentActivityWidget.swift.
            val done = Intent(context, IncidentActionReceiver::class.java).apply {
                action = IncidentActionReceiver.ACTION_ACKNOWLEDGE
                putExtra(IncidentActionReceiver.EXTRA_INCIDENT_ID, incidentId)
                putExtra(IncidentActionReceiver.EXTRA_SERVER, payload.server.toString())
            }
            builder.addAction(
                0,
                "Done",
                PendingIntent.getBroadcast(
                    context,
                    notificationId(incidentId) xor ACTION_SALT,
                    done,
                    immutable,
                ),
            )
        }

        applyChronometer(context, builder, content, state, ackedAtMillis, countdownEndMillis)
        return builder.build()
    }

    /**
     * Where a tap on the card goes: the incident screen for this id, the same
     * deep link every notification tap builds.
     */
    private fun incidentLaunchIntent(context: Context, incidentId: String): Intent =
        Intent(context, MainActivity::class.java).apply {
            data = Uri.parse("critalarm://incidents/${Uri.encode(incidentId)}")
            putExtra(MainActivity.EXTRA_INCIDENT_ID, incidentId)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

    /**
     * Sets the timer in the card's corner.
     *
     * When there is a wait to count, it counts down to the end of it, so the
     * card reads "9:32" and means it. Android advances a chronometer itself,
     * once a second, from the instant in setWhen. ProgressStyle does not: it is
     * painted once when the notification is built, so a bar would sit frozen at
     * whatever it was worth the moment the card went up and only move when
     * something re-posted the card. That is why the bar is gone and this is
     * here.
     *
     * [countdownEndMillis] is what the rule decided the card counts to. When it
     * is absent the card falls back to the cached timers, and with none of
     * those it counts up from [ackedAtMillis], which is what the card did before
     * it had a countdown.
     */
    private fun applyChronometer(
        context: Context,
        builder: NotificationCompat.Builder,
        content: IncidentContent,
        state: IncidentCardState,
        ackedAtMillis: Long,
        countdownEndMillis: Long?,
    ) {
        val timers = content.topic?.let { TopicTimerStore(context).timersFor(it) }
        val countdown = countdownEndMillis?.let { Countdown(ackedAtMillis, it) }
            ?: countdownFor(state, timers, ackedAtMillis, null)
        builder.setShowWhen(true).setUsesChronometer(true)
        if (countdown == null) {
            builder.setWhen(ackedAtMillis).setChronometerCountDown(false)
        } else {
            builder.setWhen(countdown.endMillis).setChronometerCountDown(true)
        }
    }

    /**
     * What the timer counts down to. Unacked that is the next ring, acked it is
     * the desk timer. Closed and expired have nothing left to wait for, so they
     * get no countdown. No cached timers also means no countdown.
     *
     * The instant the ack response carried beats the cached duration, because
     * counting it from the device clock restarts a wait another device may
     * already be halfway through.
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

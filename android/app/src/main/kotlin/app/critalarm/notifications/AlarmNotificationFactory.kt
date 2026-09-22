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

object AlarmNotificationFactory {
    /** The face is drawn at this many pixels, the same size the status card uses. */
    private const val FACE_PX = 192

    /**
     * Mixed into the full-screen request code so it lands in its own space.
     * The code used to be the notification id plus one, and two incident ids
     * that hash one apart would have shared a PendingIntent slot.
     */
    private const val FULL_SCREEN_SALT = 0x46530001

    /**
     * The same two reasons as [FULL_SCREEN_SALT]: each PendingIntent on this
     * card needs its own request-code space, or one overwrites another.
     */
    private const val SILENCE_SALT = 0x53490001
    private const val DELETE_SALT = 0x44450001

    fun notificationId(incidentId: String) = incidentId.hashCode()

    /**
     * [handOverToStatusCard] false means this alarm leaves nothing behind when
     * it stops. The onboarding demo is the one that says so: inc_demo is not
     * on the server, so an acked card for it would be ongoing, unswipeable,
     * and its Done button would close an incident that does not exist. The
     * flag rides the Stop button rather than being guessed from the id.
     */
    fun create(
        context: Context,
        payload: FcmIncidentPayload,
        content: IncidentContent = IncidentContentFetcher.fallback(payload),
        handOverToStatusCard: Boolean = true,
    ): Notification {
        NotificationChannels.ensureCreated(context)
        val incidentId = payload.incidentId ?: ""
        val id = notificationId(incidentId)
        val immutable = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

        val launch = Intent(context, MainActivity::class.java).apply {
            data = Uri.parse("critalarm://incidents/${Uri.encode(incidentId)}")
            putExtra(MainActivity.EXTRA_ALARM_INCIDENT_ID, incidentId)
            putExtra(MainActivity.EXTRA_INCIDENT_ID, incidentId)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        // The lock-screen takeover is a one-off surface. Leaving it in the
        // recents list after the alarm stops gives the user a second copy of a
        // screen that is already gone.
        val fullScreen = Intent(launch).apply {
            addFlags(Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
        }
        val title = NtfyEmoji.prefixTitle(content.title, content.tags)
        val (_, plainTags) = NtfyEmoji.split(content.tags)
        val resolvedBody =
            if (plainTags.isEmpty()) content.body else content.body + "\n" + plainTags.joinToString(", ")
        val body = resolvedBody

        // The status card that replaces this one is built inside a broadcast
        // receiver, with no network yet and nothing but the incident id to go
        // on. Handing it the text this card is already showing is what keeps
        // it from saying "Critical incident" when the ack fails and the
        // enrichment never lands.
        fun action(name: String) = Intent(context, IncidentActionReceiver::class.java).apply {
            action = name
            putExtra(IncidentActionReceiver.EXTRA_INCIDENT_ID, incidentId)
            putExtra(IncidentActionReceiver.EXTRA_SERVER, payload.server.toString())
            putExtra(IncidentActionReceiver.EXTRA_TITLE, content.title)
            putExtra(IncidentActionReceiver.EXTRA_BODY, content.body)
            putExtra(IncidentActionReceiver.EXTRA_HAND_OVER, handOverToStatusCard)
        }

        // "I'm up" is the acknowledge and the only way out of the loop.
        val imUp = action(IncidentActionReceiver.ACTION_STOP)
        // Stop silences and nothing more: the phone sets its own next ring for
        // the same incident. Swiping the card away does the same thing, which
        // is what the delete intent below is for.
        val silence = action(IncidentActionReceiver.ACTION_SILENCE)

        val builder = NotificationCompat.Builder(context, NotificationChannels.alarmChannelId())
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setLargeIcon(FaceBitmap.render(CritAlarmFace.ALARMED, FACE_PX))
            .setContentTitle(title)
            .setContentText(body)
            .setColor(CritAlarmPalette.CRIT)
            .shortCriticalText(IncidentCardState.OPEN.chipText)
            .requestPromotion()
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(PendingIntent.getActivity(context, id, launch, immutable))
            .addAction(0, "I'm up", PendingIntent.getBroadcast(context, id, imUp, immutable))
            .setDeleteIntent(
                PendingIntent.getBroadcast(context, id xor DELETE_SALT, silence, immutable),
            )
        builder.setFullScreenIntent(
            PendingIntent.getActivity(context, id xor FULL_SCREEN_SALT, fullScreen, immutable),
            true,
        )
        builder.addAction(
            0,
            "Stop",
            PendingIntent.getBroadcast(context, id xor SILENCE_SALT, silence, immutable),
        )

        if (body.length > MessageNotificationFactory.BIG_TEXT_THRESHOLD || body.contains('\n')) {
            builder.setStyle(NotificationCompat.BigTextStyle().bigText(body))
        }
        return builder.build()
    }
}

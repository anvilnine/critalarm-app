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

    fun notificationId(incidentId: String) = incidentId.hashCode()

    fun create(
        context: Context,
        payload: FcmIncidentPayload,
        content: IncidentContent = IncidentContentFetcher.fallback(payload),
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
        val body = if (plainTags.isEmpty()) content.body else content.body + "\n" + plainTags.joinToString(", ")

        // The status card that replaces this one is built inside a broadcast
        // receiver, with no network yet and nothing but the incident id to go
        // on. Handing it the text this card is already showing is what keeps
        // it from saying "Critical incident" when the ack fails and the
        // enrichment never lands.
        val stop = Intent(context, IncidentActionReceiver::class.java).apply {
            action = IncidentActionReceiver.ACTION_STOP
            putExtra(IncidentActionReceiver.EXTRA_INCIDENT_ID, incidentId)
            putExtra(IncidentActionReceiver.EXTRA_SERVER, payload.server.toString())
            putExtra(IncidentActionReceiver.EXTRA_TITLE, content.title)
            putExtra(IncidentActionReceiver.EXTRA_BODY, content.body)
        }

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
            .setFullScreenIntent(
                PendingIntent.getActivity(context, id + 1, fullScreen, immutable),
                true,
            )
            .addAction(0, "Stop", PendingIntent.getBroadcast(context, id, stop, immutable))

        if (body.length > MessageNotificationFactory.BIG_TEXT_THRESHOLD || body.contains('\n')) {
            builder.setStyle(NotificationCompat.BigTextStyle().bigText(body))
        }
        return builder.build()
    }
}

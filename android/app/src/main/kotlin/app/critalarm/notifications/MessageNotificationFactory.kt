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
import app.critalarm.push.FcmIncidentPayload
import app.critalarm.push.IncidentContent

/**
 * The notification for everything that is not the alarm: priority 1-3 on the
 * standard channel, priority 4 and non-critical priority 5 on the high channel.
 */
object MessageNotificationFactory {
    /** Bodies longer than this get BigTextStyle so they are readable expanded. */
    const val BIG_TEXT_THRESHOLD = 60

    /**
     * Kept apart from the other two cards by the salt.
     *
     * The alarm card is the plain hash of the incident id and the status card
     * is that hash xor its own salt. A push can carry an incident id and still
     * come here, and without a salt of its own this card would land on the id
     * of a ringing alarm card: it would replace the full-screen intent and the
     * Stop button while the service kept ringing, and the shade would have
     * nothing left to stop it with.
     *
     * A p4 forward carries no incident id (api.md §4.1), so its id is built
     * from the text instead. The server and the kind alone are the same for
     * every p4 from one server, so each forward replaced the last one.
     */
    fun notificationId(payload: FcmIncidentPayload): Int {
        val key = payload.incidentId
            ?: listOf(
                payload.server.toString(),
                payload.kind.wireValue,
                payload.title.orEmpty(),
                payload.body.orEmpty(),
            ).joinToString("|")
        return key.hashCode() xor MESSAGE_ID_SALT
    }

    /** Any constant will do, as long as it is neither 0 nor the status card's. */
    private const val MESSAGE_ID_SALT = 0x2c9277b5

    fun create(
        context: Context,
        payload: FcmIncidentPayload,
        content: IncidentContent,
        channelId: String,
        withAck: Boolean,
    ): Notification {
        NotificationChannels.ensureCreated(context)
        val id = notificationId(payload)
        val immutable = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val title = NtfyEmoji.prefixTitle(content.title, content.tags)
        val (_, plainTags) = NtfyEmoji.split(content.tags)
        val body = if (plainTags.isEmpty()) {
            content.body
        } else {
            content.body + "\n" + plainTags.joinToString(", ")
        }

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(PendingIntent.getActivity(context, id, tapIntent(context, payload, content), immutable))

        if (body.length > BIG_TEXT_THRESHOLD || body.contains('\n')) {
            builder.setStyle(NotificationCompat.BigTextStyle().bigText(body))
        }

        if (channelId == NotificationChannels.highChannelId()) {
            builder.setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
        } else {
            builder.setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
        }

        val incidentId = payload.incidentId
        if (withAck && incidentId != null) {
            val ack = Intent(context, IncidentActionReceiver::class.java).apply {
                action = IncidentActionReceiver.ACTION_STOP
                putExtra(IncidentActionReceiver.EXTRA_INCIDENT_ID, incidentId)
                putExtra(IncidentActionReceiver.EXTRA_SERVER, payload.server.toString())
                // Same reason as the alarm card: the status card that follows
                // has no other source for the text before its fetch answers.
                putExtra(IncidentActionReceiver.EXTRA_TITLE, content.title)
                putExtra(IncidentActionReceiver.EXTRA_BODY, content.body)
            }
            builder.addAction(
                0,
                "ACK",
                PendingIntent.getBroadcast(context, id, ack, immutable),
            )
        }
        return builder.build()
    }

    /**
     * Where a tap goes: the publisher's `X-Click` URL when there is one
     * (api.md §1.3), otherwise the matching screen in the app.
     */
    fun tapIntent(context: Context, payload: FcmIncidentPayload, content: IncidentContent): Intent {
        val click = content.click
        if (click != null) {
            val uri = runCatching { Uri.parse(click) }.getOrNull()
            if (uri != null && (uri.scheme == "http" || uri.scheme == "https")) {
                return Intent(Intent.ACTION_VIEW, uri).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
            }
        }
        return Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            payload.incidentId?.let {
                data = Uri.parse("critalarm://incidents/${Uri.encode(it)}")
                putExtra(MainActivity.EXTRA_INCIDENT_ID, it)
            } ?: content.topic?.let {
                data = Uri.parse("critalarm://topics/${Uri.encode(it)}")
                putExtra(MainActivity.EXTRA_TOPIC, it)
            }
        }
    }
}

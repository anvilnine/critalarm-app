package app.critalarm.notifications

import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import app.critalarm.R
import app.critalarm.actions.IncidentActionReceiver
import app.critalarm.push.FcmIncidentPayload
import app.critalarm.push.IncidentContent
import app.critalarm.push.IncidentContentFetcher

object StatusNotificationFactory {
    fun notificationId(incidentId: String) = incidentId.hashCode() xor 0x5f3759df

    fun create(
        context: Context,
        payload: FcmIncidentPayload,
        content: IncidentContent = IncidentContentFetcher.fallback(payload),
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
        val text = "${content.body} · open"
        return NotificationCompat.Builder(context, NotificationChannels.cardChannelId())
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setContentTitle(title)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .addAction(0, "Acknowledge", pending)
            .build()
    }
}

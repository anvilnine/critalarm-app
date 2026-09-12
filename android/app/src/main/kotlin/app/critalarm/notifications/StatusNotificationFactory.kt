package app.critalarm.notifications

import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import app.critalarm.R
import app.critalarm.actions.IncidentActionReceiver
import app.critalarm.push.FcmIncidentPayload

object StatusNotificationFactory {
    fun notificationId(incidentId: String) = incidentId.hashCode() xor 0x5f3759df

    fun create(context: Context, payload: FcmIncidentPayload): Notification {
        val intent = Intent(context, IncidentActionReceiver::class.java).apply {
            action = IncidentActionReceiver.ACTION_ACKNOWLEDGE
            putExtra(IncidentActionReceiver.EXTRA_INCIDENT_ID, payload.incidentId)
            putExtra(IncidentActionReceiver.EXTRA_SERVER, payload.server.toString())
        }
        val pending = PendingIntent.getBroadcast(
            context,
            notificationId(payload.incidentId),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val text = "${payload.title ?: "Critical incident"} · open"
        return NotificationCompat.Builder(context, NotificationChannels.statusChannelId())
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setContentTitle(payload.title ?: "Critical incident")
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

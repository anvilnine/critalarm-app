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

object AlarmNotificationFactory {
    fun notificationId(incidentId: String) = incidentId.hashCode()

    fun create(context: Context, payload: FcmIncidentPayload): Notification {
        NotificationChannels.ensureCreated(context)
        val launch = Intent(context, MainActivity::class.java).apply {
            data = Uri.parse("critalarm://incidents/${Uri.encode(payload.incidentId)}")
            putExtra(MainActivity.EXTRA_ALARM_INCIDENT_ID, payload.incidentId)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val stop = Intent(context, IncidentActionReceiver::class.java).apply {
            action = IncidentActionReceiver.ACTION_STOP
            putExtra(IncidentActionReceiver.EXTRA_INCIDENT_ID, payload.incidentId)
            putExtra(IncidentActionReceiver.EXTRA_SERVER, payload.server.toString())
        }
        val immutable = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return NotificationCompat.Builder(context, NotificationChannels.alarmChannelId())
            .setSmallIcon(R.drawable.ic_stat_alarm)
            .setContentTitle(payload.title ?: "Critical incident")
            .setContentText(payload.body ?: "Immediate attention required")
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(PendingIntent.getActivity(context, notificationId(payload.incidentId), launch, immutable))
            .setFullScreenIntent(PendingIntent.getActivity(context, notificationId(payload.incidentId), launch, immutable), true)
            .addAction(0, "Stop", PendingIntent.getBroadcast(context, notificationId(payload.incidentId), stop, immutable))
            .build()
    }
}

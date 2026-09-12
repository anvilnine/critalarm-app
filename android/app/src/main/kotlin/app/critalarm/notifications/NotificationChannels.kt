package app.critalarm.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.net.Uri
import app.critalarm.R

object NotificationChannels {
    fun alarmChannelId(version: Int = 1) = "critical_alarm_v$version"
    fun statusChannelId(version: Int = 1) = "incident_status_v$version"

    fun ensureCreated(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        val alarmSound = Uri.parse("android.resource://${context.packageName}/${R.raw.alarm}")
        val alarmAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val alarm = NotificationChannel(
            alarmChannelId(),
            "Critical alarms",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Audible on-call incident alarms"
            setSound(alarmSound, alarmAttributes)
            enableVibration(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            if (manager.isNotificationPolicyAccessGranted) setBypassDnd(true)
        }
        val status = NotificationChannel(
            statusChannelId(),
            "Incident status",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Ongoing incident status"
            setSound(null, null)
            enableVibration(false)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannels(listOf(alarm, status))
    }
}

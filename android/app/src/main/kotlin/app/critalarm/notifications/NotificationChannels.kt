package app.critalarm.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.net.Uri
import app.critalarm.R

/**
 * The four channels, one per delivery class in api.md §1.7.
 *
 * A channel's settings freeze the first time it is created, so the only way to
 * change one later is to create a new one. Every id carries a version for that.
 * Keep these in step with `lib/core/notifications/channel_ids.dart`.
 */
object NotificationChannels {
    /** Priority 1-3. Quiet; the app polls for these. */
    fun standardChannelId(version: Int = 1) = "message_standard_v$version"

    /** Priority 4, and priority 5 on a topic that is not critical. */
    fun highChannelId(version: Int = 1) = "message_high_v$version"

    /** Priority 5 on a critical topic. */
    fun alarmChannelId(version: Int = 1) = "critical_alarm_v$version"

    /** The ongoing card that stays up while an incident is open. */
    fun cardChannelId(version: Int = 1) = "incident_status_v$version"

    @Deprecated("Renamed to cardChannelId", ReplaceWith("cardChannelId(version)"))
    fun statusChannelId(version: Int = 1) = cardChannelId(version)

    fun allChannelIds(version: Int = 1) = listOf(
        standardChannelId(version),
        highChannelId(version),
        alarmChannelId(version),
        cardChannelId(version),
    )

    fun ensureCreated(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        val alarmSound = Uri.parse("android.resource://${context.packageName}/${R.raw.alarm}")
        val alarmAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val standard = NotificationChannel(
            standardChannelId(),
            "Messages",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Priority 1-3 messages"
            setSound(null, null)
            enableVibration(false)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
        }

        val high = NotificationChannel(
            highChannelId(),
            "Urgent messages",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Priority 4, and priority 5 on a topic that is not critical"
            setSound(
                android.media.RingtoneManager.getDefaultUri(
                    android.media.RingtoneManager.TYPE_NOTIFICATION,
                ),
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            enableVibration(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }

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

        val card = NotificationChannel(
            cardChannelId(),
            "Incident status",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Ongoing incident status"
            setSound(null, null)
            enableVibration(false)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }

        manager.createNotificationChannels(listOf(standard, high, alarm, card))
    }
}

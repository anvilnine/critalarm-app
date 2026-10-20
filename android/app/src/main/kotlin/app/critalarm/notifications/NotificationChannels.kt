package app.critalarm.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.net.Uri
import app.critalarm.R
import app.critalarm.l10n.NativeText
import app.critalarm.l10n.NativeWords

/**
 * The four incident channels, one per delivery class in api.md §1.7, plus the
 * reminders and offers channels.
 *
 * A channel's settings freeze the first time it is created, so the only way to
 * change one later is to create a new one. Every id carries a version for that.
 * Keep these in step with `lib/core/notifications/channel_ids.dart`.
 *
 * Names and descriptions are the one part Android lets an app change on a
 * channel that exists: creating it again with the same id updates them and
 * keeps the importance, sound and anything the person set. So every
 * [ensureCreated] writes them in the language picked in the app, and a
 * language switch calls it once more.
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

    /**
     * Local reminders and local Pro offers. Not in [allChannelIds]: the alarm
     * health check never looks at them. Keep in step with ChannelIds in
     * lib/core/notifications/channel_ids.dart.
     */
    const val REMINDERS_CHANNEL_ID = "reminders_v1"
    const val OFFERS_CHANNEL_ID = "offers_v1"

    fun allChannelIds(version: Int = 1) = listOf(
        standardChannelId(version),
        highChannelId(version),
        alarmChannelId(version),
        cardChannelId(version),
    )

    /** The words one channel shows in the system settings. */
    data class ChannelWords(val id: String, val name: String, val description: String)

    /**
     * The name and description of all six channels in [words]. Pure, so a
     * test can hold the ids still across languages.
     */
    fun channelWords(words: NativeWords): List<ChannelWords> = listOf(
        ChannelWords(standardChannelId(), words.text(NativeText.CHANNEL_MESSAGES), words.text(NativeText.CHANNEL_MESSAGES_DESCRIPTION)),
        ChannelWords(highChannelId(), words.text(NativeText.CHANNEL_URGENT), words.text(NativeText.CHANNEL_URGENT_DESCRIPTION)),
        ChannelWords(alarmChannelId(), words.text(NativeText.CHANNEL_ALARMS), words.text(NativeText.CHANNEL_ALARMS_DESCRIPTION)),
        ChannelWords(cardChannelId(), words.text(NativeText.CHANNEL_STATUS), words.text(NativeText.CHANNEL_STATUS_DESCRIPTION)),
        ChannelWords(REMINDERS_CHANNEL_ID, words.text(NativeText.CHANNEL_REMINDERS), words.text(NativeText.CHANNEL_REMINDERS_DESCRIPTION)),
        ChannelWords(OFFERS_CHANNEL_ID, words.text(NativeText.CHANNEL_OFFERS), words.text(NativeText.CHANNEL_OFFERS_DESCRIPTION)),
    )

    fun ensureCreated(context: Context, words: NativeWords = NativeWords.of(context)) {
        val text = channelWords(words).associateBy { it.id }
        fun name(id: String) = text.getValue(id).name
        fun about(id: String) = text.getValue(id).description
        val manager = context.getSystemService(NotificationManager::class.java)
        val alarmSound = Uri.parse("android.resource://${context.packageName}/${R.raw.alarm}")
        val alarmAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        val standard = NotificationChannel(
            standardChannelId(),
            name(standardChannelId()),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = about(standardChannelId())
            setSound(null, null)
            enableVibration(false)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
        }

        val high = NotificationChannel(
            highChannelId(),
            name(highChannelId()),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = about(highChannelId())
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
            name(alarmChannelId()),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = about(alarmChannelId())
            setSound(alarmSound, alarmAttributes)
            enableVibration(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            if (manager.isNotificationPolicyAccessGranted) setBypassDnd(true)
        }

        val card = NotificationChannel(
            cardChannelId(),
            name(cardChannelId()),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = about(cardChannelId())
            setSound(null, null)
            enableVibration(false)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }

        // Default importance and the default notification sound: a reminder
        // must never sound like an alarm. Private on the lock screen, with a
        // public version that hides the topic name.
        val reminders = NotificationChannel(
            REMINDERS_CHANNEL_ID,
            name(REMINDERS_CHANNEL_ID),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = about(REMINDERS_CHANNEL_ID)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
        }

        val offers = NotificationChannel(
            OFFERS_CHANNEL_ID,
            name(OFFERS_CHANNEL_ID),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = about(OFFERS_CHANNEL_ID)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
        }

        manager.createNotificationChannels(listOf(standard, high, alarm, card, reminders, offers))
    }
}

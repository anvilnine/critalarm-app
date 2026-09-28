package app.critalarm.localreminders

import android.app.NotificationManager
import android.content.Context
import app.critalarm.notifications.NotificationChannels
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

/** The Android half of Dart's NativeReminderScheduler. */
class LocalReminderChannel(
    private val context: Context,
    private val takeTap: () -> Map<String, Any>?,
) {
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "schedule" -> {
                val spec = (call.arguments as? Map<*, *>)?.let(LocalReminderSpec::fromArgs)
                if (spec == null) {
                    result.error("bad_args", "schedule needs id, kind and a time", null)
                } else {
                    result.success(LocalReminderAlarms.schedule(context, spec))
                }
            }
            "cancel" -> {
                val ids = (call.argument<List<Any>>("ids") ?: emptyList())
                    .mapNotNull { (it as? Number)?.toInt() }
                // Pending alarms only. Posted reminders stay in the shade.
                LocalReminderAlarms.cancelPending(context, ids)
                result.success(null)
            }
            "pending" -> result.success(
                LocalReminderSpecStore.all(context).map {
                    mapOf(
                        "id" to it.id,
                        "kind" to it.kind,
                        "year" to it.year,
                        "month" to it.month,
                        "day" to it.day,
                        "hour" to it.hour,
                        "minute" to it.minute,
                        "second" to it.second,
                    )
                },
            )
            "systemState" -> {
                val manager = context.getSystemService(NotificationManager::class.java)
                val channelOff = manager
                    ?.getNotificationChannel(NotificationChannels.REMINDERS_CHANNEL_ID)
                    ?.importance == NotificationManager.IMPORTANCE_NONE
                val allowed = (manager?.areNotificationsEnabled() ?: true) && !channelOff
                result.success(mapOf("notifications_allowed" to allowed))
            }
            "deviceTimeZone" -> {
                val zone = TimeZone.getDefault()
                result.success(
                    mapOf(
                        "name" to zone.id,
                        "offset_minutes" to zone.getOffset(System.currentTimeMillis()) / 60_000,
                    ),
                )
            }
            "takePendingTap" -> result.success(takeTap())
            else -> result.notImplemented()
        }
    }

    companion object {
        /** Matches NativeReminderScheduler.channelName in Dart. */
        const val NAME = "app.critalarm/local_reminders"
    }
}

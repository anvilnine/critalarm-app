package app.critalarm.alarm

import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.PowerManager
import app.critalarm.storage.AckQueueStore
import app.critalarm.storage.IncidentDeliveryStore
import app.critalarm.storage.PushEventLog

/** Read-only native alarm snapshot and narrowly scoped developer actions. */
internal object AlarmDebug {
    fun snapshot(context: Context): Map<String, Any?> {
        val deliveries = IncidentDeliveryStore(context)
        val ackQueue = AckQueueStore(context).debugEntries()
        val localAcked = ackQueue.mapNotNull { it["incident_id"] as? String }.toSet()
        val now = System.currentTimeMillis()
        val incidents = deliveries.debugEntries().map { entry ->
            val pending = entry.rearmFiresAtMillis != null && ScheduledAlarmReceiver.isScheduled(context, entry.incidentId)
            buildMap<String, Any> {
                put("id", entry.incidentId)
                entry.topic?.let { put("topic", it) }
                entry.ringUntilMillis?.let { put("ring_until", seconds(it)) }
                put("rearm_pending", pending)
                entry.rearmFiresAtMillis?.let { put("rearm_fires_at", seconds(it)) }
                put("acked_locally", entry.incidentId in localAcked)
                entry.deskTimerFiresAtMillis?.let { put("desk_timer_fires_at", seconds(it)) }
                put(
                    "phone_state",
                    DebugStateRule.phoneState(
                        DebugStateRule.Input(
                            active = entry.active,
                            acknowledged = entry.acknowledged,
                            closed = entry.closed,
                            inLocalAckedSet = entry.incidentId in localAcked,
                            live = AlarmForegroundService.isRinging(entry.incidentId),
                            rearmPending = pending,
                            ringUntilMillis = entry.ringUntilMillis,
                        ),
                        now,
                    ),
                )
            }
        }
        val scheduled = deliveries.debugEntries().mapNotNull { entry ->
            if (!ScheduledAlarmReceiver.isScheduled(context, entry.incidentId)) return@mapNotNull null
            buildMap<String, Any> {
                put("kind", "rearm")
                put("identifier", entry.incidentId)
                entry.rearmFiresAtMillis?.let { put("fires_at", seconds(it)) }
            }
        }

        return mapOf(
            "incidents" to incidents,
            "ack_queue" to ackQueue,
            "acked_set" to deliveries.debugEntries()
                .filter { it.acknowledged }
                .map { mapOf("incident_id" to it.incidentId, "marked_at" to (it.acknowledgedAtMillis?.let(::seconds))) },
            "scheduled" to scheduled,
            "permissions" to mapOf(
                "notifications" to notificationPermission(context),
                "alarmkit" to "unsupported",
                "battery_exempt" to batteryExempt(context),
            ),
            "ringing" to AlarmForegroundService.isRinging,
        )
    }

    fun cancelAllRearms(context: Context) {
        IncidentRearm.cancelAll(context)
        PushEventLog(context).record("debug_action", mapOf("action" to "cancel_all_rearms"))
    }

    fun clearContentCache(context: Context) {
        // Android keeps no incident-content namespace; this is deliberately a
        // no-op rather than touching delivery, notification, or sound caches.
        PushEventLog(context).record("debug_action", mapOf("action" to "clear_content_cache"))
    }

    fun clearAckedSet(context: Context) {
        IncidentDeliveryStore(context).clearAcknowledgedMarks()
        PushEventLog(context).record("debug_action", mapOf("action" to "clear_acked_set"))
    }

    private fun seconds(millis: Long): Int = (millis / 1_000L).toInt()

    private fun notificationPermission(context: Context): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return "authorized"
        val manager = context.getSystemService(NotificationManager::class.java) ?: return "unsupported"
        return if (manager.areNotificationsEnabled()) "authorized" else "denied"
    }

    private fun batteryExempt(context: Context): Boolean? =
        context.getSystemService(PowerManager::class.java)
            ?.isIgnoringBatteryOptimizations(context.packageName)
}

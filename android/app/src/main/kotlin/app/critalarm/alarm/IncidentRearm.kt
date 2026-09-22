package app.critalarm.alarm

import android.content.Context
import android.util.Log
import app.critalarm.push.IncidentPushKind
import app.critalarm.reminders.ReminderReceiver
import app.critalarm.storage.IncidentDeliveryStore
import app.critalarm.storage.NativeConnectionStore
import app.critalarm.storage.TopicTimerStore

/**
 * Sets the phone's own next ring for an incident the user silenced.
 *
 * [RearmRule] is the decision and has no Android in it. This reads the five
 * inputs off disk and hands the answer to [ScheduledAlarmReceiver]. Everything
 * it reads was written by a push or by Dart, so a re-arm only ever re-delivers
 * an incident the server opened.
 */
object IncidentRearm {
    private const val TAG = "CritAlarmAlarm"

    /**
     * Silence plus a new ring at `now + repeat_interval_s`, for the same id.
     * Answers the seconds until that ring, or null when nothing was set.
     */
    fun rearm(
        context: Context,
        incidentId: String,
        title: String? = null,
        body: String? = null,
        nowMillis: Long = System.currentTimeMillis(),
    ): Int? {
        val deliveries = IncidentDeliveryStore(context)
        val topic = deliveries.topicOf(incidentId)
        val timers = topic?.let { TopicTimerStore(context).timersFor(it) }
        val quietHours = QuietHoursWindow.read(context)
        val ringUntil = deliveries.ringUntilMillis(incidentId)

        val allowed = RearmRule.canRearm(
            incidentId = incidentId,
            // Only an incident the alarm path already rang reaches here, and
            // that path runs on open, repeat and reopen alone.
            kind = IncidentPushKind.REPEAT,
            criticalOn = criticalOn(context, topic),
            ackedLocally = deliveries.isAcknowledged(incidentId),
            ringUntilMillis = ringUntil,
            nowMillis = nowMillis,
            quietHoursHold = quietHours.holdsRing(
                minuteOfDay = QuietHoursWindow.minuteOfDay(nowMillis),
                priority = QuietHoursWindow.CRITICAL_PRIORITY,
            ),
        )
        if (!allowed) {
            Log.i(TAG, "rearm_skipped incident_id=$incidentId")
            if (ringUntil != null && nowMillis >= ringUntil) endRingWindow(context, incidentId)
            return null
        }

        val intervalS = timers?.repeatIntervalS ?: RearmRule.DEFAULT_REPEAT_INTERVAL_S
        val at = RearmRule.nextRingAtMillis(
            nowMillis = nowMillis,
            repeatIntervalS = intervalS,
            ringUntilMillis = ringUntil,
        )
        if (at == null) {
            Log.i(TAG, "rearm_skipped reason=past_ring_until incident_id=$incidentId")
            endRingWindow(context, incidentId)
            return null
        }

        val seconds = ((at - nowMillis) / 1000L).toInt()
        val set = ScheduledAlarmReceiver.scheduleAt(
            context = context,
            incidentId = incidentId,
            server = serverOf(context),
            title = title.orEmpty(),
            body = body,
            atMillis = at,
        )
        if (!set) return null
        Log.i(TAG, "rearm_set incident_id=$incidentId in_s=$seconds")
        return seconds
    }

    /**
     * `ring_until` has passed, so this phone will never ring for the incident
     * again. Nobody acked it and nobody closed it, so the only thing to drop
     * is the active flag. Reminders that were waiting for the phone to go
     * quiet go out now, rather than waiting for an ack that is not coming.
     */
    private fun endRingWindow(context: Context, incidentId: String) {
        IncidentDeliveryStore(context).deactivate(incidentId)
        ReminderReceiver.releaseHeld(context)
        Log.i(TAG, "ring_window_over incident_id=$incidentId")
    }

    /** Drops a pending re-arm. Safe to call when there is none. */
    fun cancel(context: Context, incidentId: String) {
        ScheduledAlarmReceiver.cancel(context, incidentId)
        Log.i(TAG, "rearm_cancelled incident_id=$incidentId")
    }

    /**
     * Whether the topic still rings.
     *
     * Dart caches the switch under `topic_critical.<topic>` every time it
     * lists topics. An incident whose topic this device has never listed reads
     * as on: the push that rang it was a priority-5 alarm push, which the
     * server only sends for a critical topic, and the server is still
     * repeating anyway.
     */
    private fun criticalOn(context: Context, topic: String?): Boolean {
        if (topic.isNullOrEmpty()) return true
        val preferences =
            context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val key = "flutter.topic_critical.$topic"
        if (!preferences.contains(key)) return true
        return preferences.getBoolean(key, true)
    }

    /** One server connection per app in v1, so the re-arm rings against it. */
    private fun serverOf(context: Context): String =
        NativeConnectionStore(context).canonicalServer()?.toString().orEmpty()
}

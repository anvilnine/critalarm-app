package app.critalarm.alarm

import android.content.Context
import android.util.Log
import app.critalarm.localreminders.LocalReminderReceiver
import app.critalarm.push.IncidentPushKind
import app.critalarm.storage.IncidentDeliveryStore

/**
 * Sets the phone's own rings for an incident the user silenced.
 *
 * Since the chain, every ring from now to `ring_until` is already set when
 * the incident first rings ([AlarmChains]). Stop sets the chain again from
 * now, so the next ring lands one interval after the press, the way a single
 * re-arm did. [RearmRule] is still the decision; this only reads the answer
 * back for the card.
 */
object IncidentRearm {
    private const val TAG = "CritAlarmAlarm"

    /**
     * Silence plus the chain from `now + repeat_interval_s`, for the same id.
     * Answers the seconds until the first of those rings, or null when
     * nothing was set.
     */
    fun rearm(
        context: Context,
        incidentId: String,
        title: String? = null,
        body: String? = null,
        nowMillis: Long = System.currentTimeMillis(),
    ): Int? {
        val at = AlarmChain.of(context).setRingChain(
            incidentId = incidentId,
            nowMillis = nowMillis,
            title = title,
            body = body,
        )
        if (at == null) {
            Log.i(TAG, "rearm_skipped incident_id=$incidentId")
            val ringUntil = IncidentDeliveryStore(context).ringUntilMillis(incidentId)
            if (ringUntil != null && nowMillis >= ringUntil) endRingWindow(context, incidentId)
            return null
        }
        val seconds = ((at - nowMillis) / 1000L).toInt()
        Log.i(TAG, "rearm_set incident_id=$incidentId in_s=$seconds")
        return seconds
    }

    /**
     * `ring_until` has passed, so this phone will never ring for the incident
     * again. Nobody acked it and nobody closed it, so the only thing to drop
     * is the active flag. Reminders that were waiting for the phone to go
     * quiet go out now, rather than waiting for an ack that is not coming.
     */
    internal fun endRingWindow(context: Context, incidentId: String) {
        AlarmChain.of(context).cancelChain(incidentId)
        IncidentDeliveryStore(context).deactivate(incidentId)
        LocalReminderReceiver.releaseHeld(context)
        Log.i(TAG, "ring_window_over incident_id=$incidentId")
    }

    /**
     * Drops every ring this phone set for the incident: the whole chain, and
     * the single re-arm an older version of the app may have left. Safe to
     * call when there is none.
     */
    fun cancel(context: Context, incidentId: String) {
        ScheduledAlarmReceiver.cancel(context, incidentId)
        AlarmChain.of(context).cancelChain(incidentId)
        Log.i(TAG, "rearm_cancelled incident_id=$incidentId")
    }

    /**
     * What a state push does to this phone's own rings: the old single
     * re-arm always goes, and the chain goes unless the push is the server's
     * `ack` for this phone's own "I'm up" ([AlarmChains.onStatePush]).
     */
    fun onStatePush(context: Context, incidentId: String, kind: IncidentPushKind) {
        ScheduledAlarmReceiver.cancel(context, incidentId)
        val kept = AlarmChain.of(context).onStatePush(incidentId, kind)
        Log.i(TAG, "state_push_rings incident_id=$incidentId kind=${kind.wireValue} desk_chain_kept=$kept")
    }

    internal fun cancelAll(context: Context) {
        AlarmChain.of(context).cancelAll()
    }
}

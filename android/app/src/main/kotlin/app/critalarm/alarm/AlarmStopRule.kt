package app.critalarm.alarm

/**
 * Whether cancelling one incident may stop the alarm service.
 *
 * Android runs one [AlarmForegroundService] for the whole app, so stopping it
 * stops whatever is ringing right now, not the incident that was named. That
 * turned a cancel aimed at an old incident into silence on a live alarm:
 * incident B is acked and then expires on the server overnight, incident A
 * fires, the user taps the lock screen, launch-time reconcile cancels B, and
 * the ring for A dies with it.
 *
 * Crit Alarm rings until someone acknowledges it, so this is the one decision
 * that may never be a guess.
 */
object AlarmStopRule {
    /**
     * True only when [incidentId] is the incident the service is ringing for.
     * A null [ringingIncidentId] means nothing is ringing and there is nothing
     * to stop.
     *
     * "Stop whatever is ringing" does not come through here. That is
     * `stopRinging`, which means the noise rather than a row in a table, and
     * it stops the service without asking.
     */
    fun stopsService(incidentId: String, ringingIncidentId: String?): Boolean =
        ringingIncidentId != null && ringingIncidentId == incidentId
}

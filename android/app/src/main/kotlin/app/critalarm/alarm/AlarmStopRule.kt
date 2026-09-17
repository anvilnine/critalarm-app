package app.critalarm.alarm

/**
 * Which incident the alarm service rings, and when it may stop.
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
     * What the service rings next once [incidentId] is stopped, given every
     * un-acked incident it is holding in [ringing], oldest first.
     *
     * Null means there is nothing left, so the service stops. Anything else is
     * an incident nobody has acknowledged yet and the service hands over to it
     * rather than going quiet. Without this, incident A rang, incident B
     * arrived and took the service, the user stopped B, and A went silent
     * unacknowledged: if the server had passed `max_ring_s` for A, it never
     * rang again and the user never learned it happened.
     *
     * Stopping an incident the service is not holding leaves the ring alone,
     * which is the reconcile case above.
     */
    fun nextRinging(incidentId: String, ringing: List<String>): String? =
        ringing.filterNot { it == incidentId }.lastOrNull()

    /**
     * True when a start the service could not read may call `stopSelf`.
     *
     * Only when nothing is ringing. `stopSelf(startId)` stops the service when
     * `startId` is the most recent start, and a malformed start always is, so
     * a junk payload arriving mid-alarm used to kill a live alarm. Ignoring the
     * bad start costs nothing: the service is already up and already ringing
     * the incident it was told about.
     */
    fun stopsOnBadStart(ringingIncidentId: String?): Boolean = ringingIncidentId == null
}

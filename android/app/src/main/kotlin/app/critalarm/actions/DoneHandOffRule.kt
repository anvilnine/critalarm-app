package app.critalarm.actions

/**
 * Whether the app may hand a close to the receiver on behalf of a Done
 * button it says was pressed.
 *
 * The app only says so because a link carried a marker, and a link can be
 * forged by any app on the phone. So the marker proves nothing. What this
 * phone itself recorded does: the close goes ahead only for an incident
 * that is acknowledged here and quiet, which is exactly the incident whose
 * card carries Done.
 *
 * Every input is read from what native already keeps
 * (`IncidentDeliveryStore`, `AlarmForegroundService`). Nothing comes from
 * Dart but the id.
 */
object DoneHandOffRule {
    /**
     * - [acknowledged]: `acknowledged:<id>`, set by the ack and dropped by a
     *   reopen.
     * - [closed]: `closed:<id>`. A closed incident has no card and nothing
     *   left to close.
     * - [active]: `active:<id>`, set when a push rings the incident and
     *   dropped by the ack. Open and not acknowledged, silenced or not.
     * - [ringing]: the alarm service is ringing for this incident now.
     * - [rearmPending]: the phone has set its own next ring for it.
     *
     * An id this phone has never seen has none of them set, and is refused.
     */
    fun mayClose(
        acknowledged: Boolean,
        closed: Boolean,
        active: Boolean,
        ringing: Boolean,
        rearmPending: Boolean,
    ): Boolean = acknowledged && !closed && !active && !ringing && !rearmPending
}

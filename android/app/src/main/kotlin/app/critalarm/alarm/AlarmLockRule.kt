package app.critalarm.alarm

/**
 * When MainActivity's window shows over the lock screen.
 *
 * The alarm screen has to show over the lock screen: that is how a ringing
 * phone gets answered. The same window then holds Home, topics and Settings,
 * so it may only stay there while an alarm needs it. Before this rule the
 * flag was turned on for any start that carried `alarm_incident_id`, from any
 * app, and never turned off.
 *
 * "Owes an ack" means the alarm service holds the incident, ringing now or
 * waiting behind another one, or the delivery store has it open and not
 * acknowledged (the ring was silenced and comes back on its own).
 */
object AlarmLockRule {
    /** A start that names [incidentId] turns the flag on only for a real alarm. */
    fun showsFor(incidentId: String?, owesAck: Boolean): Boolean =
        !incidentId.isNullOrEmpty() && owesAck

    /**
     * The alarm screen let go of [released]: it was acknowledged, closed, or
     * the screen was left. The window stays over the lock screen only for
     * another alarm: one ringing now ([ringingNow]), or a newer one the window
     * was opened for ([shownFor]) that still owes an ack. That second case is
     * the old screen closing after a new alarm already took the window.
     */
    fun keepsOnRelease(
        released: String,
        shownFor: String,
        ringingNow: String?,
        shownForOwesAck: Boolean,
    ): Boolean =
        (ringingNow != null && ringingNow != released) ||
            (shownFor != released && shownForOwesAck)

    /**
     * Checked as the window starts, resumes and stops, for an alarm answered
     * somewhere Dart did not see, such as the notification's own button.
     */
    fun keepsOnCheck(ringingNow: String?, shownForOwesAck: Boolean): Boolean =
        ringingNow != null || shownForOwesAck
}

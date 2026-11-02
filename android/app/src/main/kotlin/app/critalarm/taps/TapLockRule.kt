package app.critalarm.taps

import app.critalarm.alarm.AlarmLockRule

/**
 * Whether a start that names an alarm shows MainActivity over the lock
 * screen. Both have to hold: the intent carries the app's own mark
 * ([TapGate.admit] said yes), and [AlarmLockRule] still says the incident
 * needs its alarm screen. [owesAck] is only asked for a signed start.
 *
 * Pure, so a JVM test can reach it.
 */
object TapLockRule {
    fun showsFor(signed: Boolean, incidentId: String?, owesAck: (String) -> Boolean): Boolean {
        if (!signed || incidentId.isNullOrEmpty()) return false
        return AlarmLockRule.showsFor(incidentId, owesAck(incidentId))
    }
}

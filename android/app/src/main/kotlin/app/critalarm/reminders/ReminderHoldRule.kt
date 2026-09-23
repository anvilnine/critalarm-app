package app.critalarm.reminders

/**
 * Whether a reminder may go out right now.
 *
 * A reminder is the app's own notification, so it can wait. While an alarm
 * is under way it would land on top of the one thing the user has to answer,
 * so it is held and posted once the last incident is acknowledged.
 *
 * Nothing here is Android. The two inputs come from
 * `AlarmForegroundService.isRinging` (the service is holding an incident)
 * and the `active:` flags in `IncidentDeliveryStore` (an incident is open on
 * this phone, so a re-arm can still bring the ring back).
 */
object ReminderHoldRule {

    /** True while a reminder has to wait. */
    fun holdsReminder(alarmRinging: Boolean, activeIncidentIds: Collection<String>): Boolean =
        alarmRinging || activeIncidentIds.isNotEmpty()

    /** The held reminders to post now, oldest id first, or none while it holds. */
    fun released(
        heldIds: Collection<Int>,
        alarmRinging: Boolean,
        activeIncidentIds: Collection<String>,
    ): List<Int> =
        if (holdsReminder(alarmRinging, activeIncidentIds)) emptyList() else heldIds.sorted()
}

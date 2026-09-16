package app.critalarm.storage

import android.content.Context

/**
 * What this device knows about one incident, kept on disk because the cards are
 * built with no Flutter engine running.
 *
 * Two flags and two instants. The flags are what a late network answer checks
 * before it puts a card back: a fetch started at 0s can land at 10s, by which
 * time the user may have stopped the alarm, closed the incident, or both.
 */
class IncidentDeliveryStore(context: Context) {
    private val preferences = context.getSharedPreferences("incident_delivery", Context.MODE_PRIVATE)

    fun isActive(incidentId: String) = preferences.getBoolean("active:$incidentId", false)
    fun isAcknowledged(incidentId: String) = preferences.getBoolean("acknowledged:$incidentId", false)

    /** True once a close has gone through. A closed incident has no card at all. */
    fun isClosed(incidentId: String) = preferences.getBoolean("closed:$incidentId", false)

    /** When the user stopped the alarm, or null when they have not. */
    fun acknowledgedAtMillis(incidentId: String): Long? =
        preferences.getLong("acked_at:$incidentId", 0L).takeIf { it > 0L }

    /**
     * The desk timer end the server sent back with the ack, or null when it
     * sent none. An absolute instant beats counting a cached duration from the
     * device clock: a 409 means another device acked earlier and the wait is
     * already part spent.
     */
    fun deskTimerFiresAtMillis(incidentId: String): Long? =
        preferences.getLong("desk_timer_fires_at:$incidentId", 0L).takeIf { it > 0L }

    fun activate(incidentId: String, reopen: Boolean = false) {
        preferences.edit().putBoolean("active:$incidentId", true).apply {
            if (reopen) {
                remove("acknowledged:$incidentId")
                remove("closed:$incidentId")
                remove("acked_at:$incidentId")
                remove("desk_timer_fires_at:$incidentId")
            }
        }.apply()
    }

    fun markAcknowledged(incidentId: String, atMillis: Long = System.currentTimeMillis()) {
        preferences.edit()
            .putBoolean("acknowledged:$incidentId", true)
            .putLong("acked_at:$incidentId", atMillis)
            .remove("active:$incidentId")
            .apply()
    }

    /**
     * A closed incident is also an acknowledged one, so a repeat push that
     * crosses the close still gets dropped instead of ringing.
     */
    fun markClosed(incidentId: String) {
        preferences.edit()
            .putBoolean("closed:$incidentId", true)
            .putBoolean("acknowledged:$incidentId", true)
            .remove("active:$incidentId")
            .apply()
    }

    fun rememberDeskTimerFiresAt(incidentId: String, millis: Long) {
        preferences.edit().putLong("desk_timer_fires_at:$incidentId", millis).apply()
    }
}

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

    /**
     * Every incident this device has acked and not closed, which is every
     * incident with a status card still up.
     *
     * Read off the `acknowledged:` keys, the same prefix style the getters
     * above use. Dart asks for this on launch and takes down the cards the
     * server says are over.
     */
    fun acknowledgedIncidentIds(): List<String> = preferences.all.keys
        .filter { it.startsWith("acknowledged:") }
        .map { it.removePrefix("acknowledged:") }
        .filter { it.isNotEmpty() && isAcknowledged(it) && !isClosed(it) }

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
    fun markClosed(incidentId: String, atMillis: Long = System.currentTimeMillis()) {
        preferences.edit()
            .putBoolean("closed:$incidentId", true)
            .putBoolean("acknowledged:$incidentId", true)
            // Dated, because [prune] reads this to tell an incident that
            // finished weeks ago from one that finished a minute ago. A close
            // that follows an ack keeps the ack's instant.
            .putLong("acked_at:$incidentId", acknowledgedAtMillis(incidentId) ?: atMillis)
            .remove("active:$incidentId")
            .apply()
    }

    fun rememberDeskTimerFiresAt(incidentId: String, millis: Long) {
        preferences.edit().putLong("desk_timer_fires_at:$incidentId", millis).apply()
    }

    /**
     * Drops every key of every incident past the retention window. See
     * [DeliveryRetention] for the window and why it is that long.
     *
     * Called on launch, from the same channel call that reads
     * [acknowledgedIncidentIds], because that list is the thing that grew: a
     * purged incident answers 404 for good, and each one cost another server
     * call on every cold start.
     */
    fun prune(nowMillis: Long = System.currentTimeMillis()) {
        val stale = incidentIds().filter { incidentId ->
            DeliveryRetention.isStale(
                acknowledged = isAcknowledged(incidentId),
                closed = isClosed(incidentId),
                ackedAtMillis = acknowledgedAtMillis(incidentId),
                nowMillis = nowMillis,
            )
        }
        if (stale.isEmpty()) return
        val edit = preferences.edit()
        for (incidentId in stale) {
            for (prefix in PREFIXES) edit.remove("$prefix$incidentId")
        }
        edit.apply()
    }

    /** Every incident this store holds anything about. */
    private fun incidentIds(): Set<String> = preferences.all.keys
        .mapNotNull { key ->
            PREFIXES.firstOrNull { key.startsWith(it) }?.let { key.removePrefix(it) }
        }
        .filter { it.isNotEmpty() }
        .toSet()

    private companion object {
        val PREFIXES = listOf(
            "active:",
            "acknowledged:",
            "closed:",
            "acked_at:",
            "desk_timer_fires_at:",
        )
    }
}

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

    /**
     * Every incident this device has open and has not acked: the `active:`
     * flag is set when a push rings one and removed by the ack. While one is
     * in here the phone can still ring for it, even when nothing is playing
     * this second, because a re-arm is waiting.
     */
    fun activeIncidentIds(): List<String> = preferences.all.keys
        .filter { it.startsWith("active:") }
        .map { it.removePrefix("active:") }
        .filter { it.isNotEmpty() && isActive(it) }

    fun activate(incidentId: String, reopen: Boolean = false) {
        preferences.edit().putBoolean("active:$incidentId", true).apply {
            if (reopen) {
                remove("acknowledged:$incidentId")
                remove("closed:$incidentId")
                remove("acked_at:$incidentId")
                remove("desk_timer_fires_at:$incidentId")
                remove("local_acked_at:$incidentId")
            }
        }.apply()
    }

    /**
     * Drops the active flag and nothing else. For an incident this phone can
     * no longer ring for because `ring_until` has passed: it was never acked
     * and it was never closed, so neither of those belongs here.
     */
    fun deactivate(incidentId: String) {
        preferences.edit().remove("active:$incidentId").apply()
    }

    fun markAcknowledged(incidentId: String, atMillis: Long = System.currentTimeMillis()) {
        preferences.edit()
            .putBoolean("acknowledged:$incidentId", true)
            .putLong("acked_at:$incidentId", atMillis)
            .remove("active:$incidentId")
            .apply()
    }

    fun markLocallyAcknowledged(incidentId: String, atMillis: Long = System.currentTimeMillis()) {
        markAcknowledged(incidentId, atMillis)
        preferences.edit().putLong("local_acked_at:$incidentId", atMillis).apply()
    }

    fun locallyAcknowledgedAtMillis(incidentId: String): Long? =
        preferences.getLong("local_acked_at:$incidentId", 0L).takeIf { it > 0L }

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
     * The last instant this phone may ring for the incident on its own, from
     * `ring_until` on the alarm push (api.md §5.2), or null when no push
     * carried one. The re-arm needs it with no network call, so it is written
     * here the moment the push lands.
     *
     * Null is also the answer for the onboarding demo, which no server sent.
     */
    fun ringUntilMillis(incidentId: String): Long? =
        preferences.getLong("ring_until:$incidentId", 0L).takeIf { it > 0L }

    /**
     * Which topic the incident is on, learned from the content fetch. The push
     * itself does not carry it (api.md §5.2), and it is what the re-arm reads
     * the repeat interval and the critical switch from.
     */
    fun topicOf(incidentId: String): String? =
        preferences.getString("topic:$incidentId", null)?.takeIf(String::isNotEmpty)

    fun rememberRingUntil(incidentId: String, millis: Long) {
        preferences.edit().putLong("ring_until:$incidentId", millis).apply()
    }

    fun rememberTopic(incidentId: String, topic: String) {
        if (topic.isEmpty()) return
        preferences.edit().putString("topic:$incidentId", topic).apply()
    }

    internal data class DebugEntry(
        val incidentId: String,
        val active: Boolean,
        val acknowledged: Boolean,
        val closed: Boolean,
        val acknowledgedAtMillis: Long?,
        val locallyAcknowledgedAtMillis: Long?,
        val deskTimerFiresAtMillis: Long?,
        val ringUntilMillis: Long?,
        val rearmFiresAtMillis: Long?,
        val topic: String?,
    )

    internal fun debugEntries(): List<DebugEntry> = incidentIds().map { incidentId ->
        DebugEntry(
            incidentId, isActive(incidentId), isAcknowledged(incidentId), isClosed(incidentId),
            acknowledgedAtMillis(incidentId), locallyAcknowledgedAtMillis(incidentId),
            deskTimerFiresAtMillis(incidentId), ringUntilMillis(incidentId),
            rearmFiresAtMillis(incidentId), topicOf(incidentId),
        )
    }

    internal fun rememberRearmFiresAt(incidentId: String, millis: Long) {
        preferences.edit().putLong("rearm_fires_at:$incidentId", millis).apply()
    }

    internal fun clearRearm(incidentId: String) {
        preferences.edit().remove("rearm_fires_at:$incidentId").apply()
    }

    internal fun clearAcknowledgedMarks() {
        val edit = preferences.edit()
        incidentIds().forEach { incidentId ->
            edit.remove("local_acked_at:$incidentId")
        }
        edit.apply()
    }

    internal fun rearmFiresAtMillis(incidentId: String): Long? =
        preferences.getLong("rearm_fires_at:$incidentId", 0L).takeIf { it > 0L }

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
            "ring_until:",
            "topic:",
            "rearm_fires_at:",
            "local_acked_at:",
        )
    }
}

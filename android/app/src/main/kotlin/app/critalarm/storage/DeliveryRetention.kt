package app.critalarm.storage

/**
 * How long [IncidentDeliveryStore] keeps what it knows about a finished
 * incident.
 *
 * The flags are there to stop a late push putting a card back: a repeat that
 * crosses an ack, or a content fetch that answers after a close. Both of those
 * windows are minutes. api.md 2.3 caps a topic's ring with max_ring_s, 1800 in
 * the example config, and the server stops repeating once an incident is
 * acked, so a week is far past anything that can still arrive.
 *
 * Without a window nothing is ever removed. Every incident this device has
 * ever acked stays in the list Dart walks on launch, one server call at a
 * time, and the SharedPreferences file grows with it.
 */
object DeliveryRetention {
    /** Seven days, in milliseconds. */
    const val WINDOW_MS = 7L * 24 * 60 * 60 * 1000

    /**
     * True when this incident's keys can go.
     *
     * A row goes only once the incident is closed, and [ackedAtMillis] is when
     * the user stopped the alarm. Null means the row was written by a build
     * that did not record the instant, which makes it older than anything this
     * one wrote.
     *
     * A ringing incident is never stale, whatever the clock says, and neither
     * is an acked one the server has not finished with. That row is a card
     * still on the lock screen: launch reconcile reads the id off
     * [IncidentDeliveryStore.acknowledgedIncidentIds] to take the card down,
     * and dropping the acked flag lets the next repeat push ring an incident
     * the user already answered. Reconcile closes the row when the server says
     * the incident is over, and the window runs from there.
     */
    fun isStale(
        acknowledged: Boolean,
        closed: Boolean,
        ackedAtMillis: Long?,
        nowMillis: Long,
    ): Boolean {
        if (!acknowledged || !closed) return false
        val ackedAt = ackedAtMillis ?: return true
        return nowMillis - ackedAt >= WINDOW_MS
    }
}

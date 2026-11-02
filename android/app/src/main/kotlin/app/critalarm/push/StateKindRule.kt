package app.critalarm.push

/**
 * What a state push does to this device (api.md §5.2).
 *
 * `ack`, `close` and `expire` arrive when the incident was answered somewhere
 * else. Every one of them stops the ring and drops the local re-arm; they
 * differ only in what is left on screen. None of them rings, and none of them
 * posts a new notification.
 */
object StateKindRule {
    enum class Card {
        /** The acked card, chip "AWAKE". The incident is still open. */
        ACKED,

        /** Nothing. The incident is over. */
        NONE,
    }

    /** True when this device has to act on the push at all. */
    fun applies(kind: IncidentPushKind): Boolean = kind.isStateChange

    /** Always false. A state push is a report, never a page. */
    fun rings(kind: IncidentPushKind): Boolean = false

    /** Null when the kind is not a state change. */
    fun cardFor(kind: IncidentPushKind): Card? = when (kind) {
        IncidentPushKind.ACK -> Card.ACKED
        IncidentPushKind.CLOSE, IncidentPushKind.EXPIRE -> Card.NONE
        else -> null
    }

    /** True when the id should be marked acknowledged and not closed. */
    fun marksAcknowledgedOnly(kind: IncidentPushKind): Boolean = kind == IncidentPushKind.ACK

    /**
     * True when a state push leaves this phone's chain alone.
     *
     * Only this phone's own "I'm up" sets a desk timer chain, so an `ack`
     * that finds one is the server's report of that same tap. Cancelling it
     * would leave nothing to ring when the desk timer runs out while the
     * phone is offline. An `ack` from another phone finds a ring chain, or
     * none, and every `close` and `expire` ends the incident: those cancel.
     */
    fun keepsDeskChain(kind: IncidentPushKind, chainIsDesk: Boolean): Boolean =
        kind == IncidentPushKind.ACK && chainIsDesk
}

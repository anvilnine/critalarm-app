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
}

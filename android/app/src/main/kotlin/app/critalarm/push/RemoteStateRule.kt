package app.critalarm.push

import org.json.JSONObject

/**
 * What this phone does when it learns an incident is over from anything other
 * than a state push: Dart asking after a list read, or Stop asking the server
 * once (api.md §3.2).
 *
 * Every phone on a topic rings for the same incident. Once it is acknowledged,
 * closed or expired anywhere, this phone has to go quiet and drop the ring it
 * set for itself. Only a state the server named does that. A failed check, a
 * timeout or a word this app does not know leaves the ring alone, because a
 * phone that stops ringing for an incident nobody handled is the worse
 * mistake.
 *
 * Dart reads the same three words in
 * `lib/core/alarm/handled_elsewhere_rule.dart`, and iOS in
 * `RemoteStateCheck` (`ios/Shared/Ack/NativeAckSender.swift`).
 */
object RemoteStateRule {
    /** The state push this word stands for, or null when it does not end the ring. */
    fun kindForState(state: String?): IncidentPushKind? = when (state) {
        "acked" -> IncidentPushKind.ACK
        "closed" -> IncidentPushKind.CLOSE
        "expired" -> IncidentPushKind.EXPIRE
        else -> null
    }

    /** The `state` of a `GET /v1/incidents/{id}` answer, or null when it has none. */
    fun stateOf(json: String): String? = runCatching {
        JSONObject(json).optString("state").takeIf { it.isNotEmpty() }
    }.getOrNull()

    /**
     * True when this phone is ringing for the incident, holds it to ring next,
     * or has a ring set for it. Only then is there anything to stop.
     *
     * An alarm push whose ring window is still open and that nobody answered
     * here counts too: the ring can be between two repeats, with nothing
     * scheduled on the phone yet.
     */
    fun isLiveHere(
        holding: Boolean,
        rearmPending: Boolean,
        active: Boolean,
        acknowledged: Boolean,
        closed: Boolean,
        ringUntilMillis: Long?,
        nowMillis: Long,
    ): Boolean {
        if (holding) return true
        if (acknowledged || closed) return false
        if (rearmPending) return true
        return active && ringUntilMillis != null && nowMillis < ringUntilMillis
    }
}

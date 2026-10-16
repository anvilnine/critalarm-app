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

    /**
     * True when an answer may end the ring: it carries the moment its
     * question went out ([checkedAtMillis]), and no push armed a ring for the
     * incident at or after that moment. A push after the question can be a
     * reopen the answer knew nothing about. No arm time on record means no
     * push came since this build, so nothing can have reopened it.
     */
    fun mayApply(checkedAtMillis: Long?, ringArmedAtMillis: Long?): Boolean {
        if (checkedAtMillis == null) return false
        return ringArmedAtMillis == null || ringArmedAtMillis < checkedAtMillis
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

/**
 * One blocking call with a deadline over all of it: connect, headers and
 * body. `HttpURLConnection` timeouts apply to each step on its own, so a slow
 * server could hold a broadcast receiver past the time Android gives it.
 * Past [timeoutMs] the answer is null and [onTimeout] runs, which is where
 * the caller disconnects. A call that throws also answers null.
 */
object CallDeadline {
    fun <T> run(timeoutMs: Long, onTimeout: () -> Unit, call: () -> T?): T? {
        val answer = java.util.concurrent.atomic.AtomicReference<T?>(null)
        val worker = Thread {
            try {
                answer.set(call())
            } catch (_: Throwable) {
                answer.set(null)
            }
        }
        worker.isDaemon = true
        worker.start()
        worker.join(timeoutMs)
        if (worker.isAlive) {
            try {
                onTimeout()
            } finally {
                worker.interrupt()
            }
            return null
        }
        return answer.get()
    }
}

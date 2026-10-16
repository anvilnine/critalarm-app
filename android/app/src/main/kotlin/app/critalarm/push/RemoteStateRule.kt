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

    /** What applying a state the server named did, in the words Dart reads. */
    enum class Outcome(val wire: String) {
        /** The answer was for the ring going now, and a ring was stopped. */
        STOPPED("stopped"),

        /** The answer was for the ring going now, and nothing was set to ring. */
        NOTHING("nothing"),

        /** A push armed a ring since the question went out, or no generation came with it. */
        REFUSED("refused"),
    }

    /**
     * Whether an answer may end the ring. The caller read the incident's ring
     * generation ([expectedGeneration]) before its question went out; every
     * push that arms a ring moves the generation on, and Stop's own re-arm
     * does not. A changed generation means a push, which can be a reopen,
     * came after the question, so the answer may be about the stage before.
     * No clock is read: a phone whose clock jumps cannot fool this.
     */
    fun decide(expectedGeneration: Long?, currentGeneration: Long, live: Boolean): Outcome = when {
        expectedGeneration == null || expectedGeneration != currentGeneration -> Outcome.REFUSED
        !live -> Outcome.NOTHING
        else -> Outcome.STOPPED
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

/**
 * One lock per incident. Push arming, Stop's re-arm and every guarded stop
 * take it, so reading the ring generation and cancelling can never interleave
 * with a push that arms a new ring.
 */
object RingLocks {
    private val locks = java.util.concurrent.ConcurrentHashMap<String, Any>()

    fun of(incidentId: String): Any = locks.getOrPut(incidentId) { Any() }
}

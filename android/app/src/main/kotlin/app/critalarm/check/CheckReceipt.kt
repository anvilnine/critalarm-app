package app.critalarm.check

import java.net.URI
import java.net.URLEncoder
import org.json.JSONObject

/** The relay this device registered with, and the device's own credential. */
data class RelayDevice(val relay: URI, val deviceId: String, val deviceToken: String) {
    // The token is a secret and stays out of any log line.
    override fun toString() = "RelayDevice(relay=$relay)"

    companion object {
        /**
         * Built from what Dart keeps in its preferences.
         *
         * [apiSession] is `base|relay|mode|credential`, written by
         * `SharedPrefsApiSessionStore`. The relay is the second part. The
         * fourth is the credential for the user's own server, which on a
         * self-hosted phone is not the device token, so it is not used here.
         * [deviceId] and [deviceToken] are what `DeviceIdentityStore` saved
         * when the relay registered this device (api.md §4.2).
         */
        fun parse(apiSession: String?, deviceId: String?, deviceToken: String?): RelayDevice? {
            val parts = apiSession?.split('|') ?: return null
            if (parts.size != 4) return null
            val relay = runCatching { URI(parts[1]) }.getOrNull()
                ?.takeIf { (it.scheme == "http" || it.scheme == "https") && !it.host.isNullOrBlank() }
                ?: return null
            if (deviceId.isNullOrBlank() || deviceToken.isNullOrBlank()) return null
            return RelayDevice(relay = relay, deviceId = deviceId, deviceToken = deviceToken)
        }
    }
}

/** One HTTP request, as plain values. */
data class CheckReceiptRequest(
    val method: String,
    val url: String,
    val headers: Map<String, String>,
    val body: String,
) {
    // The url holds the check id and a header holds the token.
    override fun toString() = "CheckReceiptRequest($method)"
}

/** What the relay answered to a receipt. Times are epoch seconds. */
data class CheckReceiptAnswer(val counted: Boolean, val nextDueAt: Long?, val noticeAfter: Long?)

/**
 * The receipt for a weekly check, api.md §4.5:
 *
 * ```
 * POST /relay/v1/devices/{device_id}/checks/{check_id}/receipt
 * Authorization: Bearer dv_...
 * { "attempt":1, "received_at":1759800004 }
 * ```
 *
 * Everything here is a pure function, so it is tested off a device.
 */
object CheckReceipt {
    /**
     * How many times the receipt is sent before it is dropped, and the wait
     * before each try. A round stays open for 24 hours and has up to three
     * pushes, so a receipt that cannot get out now is better dropped than
     * kept: the next push of the round brings another chance.
     */
    val TRY_DELAYS_MS = listOf(0L, 3_000L, 10_000L)

    const val CONNECT_TIMEOUT_MS = 8_000
    const val READ_TIMEOUT_MS = 8_000

    /**
     * Whether a receipt may go to [relay]. The receipt carries the device
     * token, so it only ever goes out over https. [plainHttpHosts] is the one
     * exception and comes from `PlainHttpRelays`, which is empty in every
     * build but the debug one.
     */
    fun maySend(relay: URI, plainHttpHosts: Set<String>): Boolean = when (relay.scheme?.lowercase()) {
        "https" -> true
        "http" -> relay.host?.lowercase() in plainHttpHosts
        else -> false
    }

    /** How one receipt ended. */
    enum class Outcome { SENT, REFUSED, DROPPED, CANCELLED }

    /**
     * Sends one receipt: up to [TRY_DELAYS_MS] tries, then it is dropped.
     *
     * [post] makes the call and answers the status and the body, or a null
     * status when nothing came back. [isCancelled] belongs to this one
     * receipt and is asked before every try. [onAnswer] gets what a 200
     * carried. Nothing here is shared between two receipts.
     */
    fun send(
        request: CheckReceiptRequest,
        post: (CheckReceiptRequest) -> Pair<Int?, String?>,
        isCancelled: () -> Boolean,
        sleep: (Long) -> Unit = { Thread.sleep(it) },
        onTry: (index: Int, status: Int?) -> Unit = { _, _ -> },
        onAnswer: (CheckReceiptAnswer?) -> Unit = {},
    ): Outcome {
        for ((index, delay) in TRY_DELAYS_MS.withIndex()) {
            if (delay > 0) {
                try {
                    sleep(delay)
                } catch (_: InterruptedException) {
                    return Outcome.CANCELLED
                }
            }
            if (isCancelled()) return Outcome.CANCELLED
            val (status, body) = post(request)
            onTry(index, status)
            if (status == 200) {
                onAnswer(parseAnswer(body))
                return Outcome.SENT
            }
            if (!shouldRetry(status)) return Outcome.REFUSED
        }
        return Outcome.DROPPED
    }

    fun request(device: RelayDevice, push: CheckPush, receivedAtSeconds: Long): CheckReceiptRequest {
        val base = device.relay.toString().trimEnd('/')
        val body = JSONObject()
        // `attempt` is a note. It is sent only when the push carried one.
        push.attempt?.let { body.put("attempt", it) }
        body.put("received_at", receivedAtSeconds)
        return CheckReceiptRequest(
            method = "POST",
            url = "$base/relay/v1/devices/${segment(device.deviceId)}" +
                "/checks/${segment(push.checkId)}/receipt",
            headers = mapOf(
                "Authorization" to "Bearer ${device.deviceToken}",
                "Accept" to "application/json",
                "Content-Type" to "application/json",
            ),
            body = body.toString(),
        )
    }

    /**
     * Whether a try that ended this way is worth another. No answer at all and
     * a server error are. Any other answer is final: 200 is done, 404 means
     * the relay knows no such check for this device, 401 means the credential
     * is dead, and asking again changes none of them.
     */
    fun shouldRetry(status: Int?): Boolean = status == null || status == 429 || status >= 500

    /** Reads `counted`, `next_due_at` and `notice_after`. Null when it is not that. */
    fun parseAnswer(body: String?): CheckReceiptAnswer? {
        val json = runCatching { JSONObject(body ?: return null) }.getOrNull() ?: return null
        if (!json.has("counted")) return null
        return CheckReceiptAnswer(
            counted = json.optBoolean("counted", false),
            nextDueAt = json.seconds("next_due_at"),
            noticeAfter = json.seconds("notice_after"),
        )
    }

    /**
     * The record Dart reads, with the arrival written into it. What an
     * earlier receipt answer left there stays until a newer answer replaces
     * it. The check id is never part of it.
     */
    fun withArrival(existing: String?, receivedAtSeconds: Long): String =
        record(existing).put("received_at", receivedAtSeconds).toString()

    /**
     * The record with a receipt answer written into it. `notice_after` is the
     * second at which this device will have missed two rounds in a row, and
     * the phone raises its own notice when its clock passes it (api.md §4.5).
     */
    fun withAnswer(existing: String?, answer: CheckReceiptAnswer, nowSeconds: Long): String {
        val json = record(existing)
        if (answer.noticeAfter != null) {
            json.put("notice_after", answer.noticeAfter)
            json.put("notice_after_seen_at", nowSeconds)
        }
        if (answer.nextDueAt != null) json.put("next_due_at", answer.nextDueAt)
        return json.toString()
    }

    private fun record(existing: String?): JSONObject =
        runCatching { JSONObject(existing ?: "{}") }.getOrNull() ?: JSONObject()

    private fun JSONObject.seconds(key: String): Long? =
        if (has(key) && !isNull(key)) optLong(key).takeIf { it > 0 } else null

    /** One path segment. `URLEncoder` writes a space as `+`, which a path does not. */
    private fun segment(value: String): String =
        URLEncoder.encode(value, "UTF-8").replace("+", "%20")
}

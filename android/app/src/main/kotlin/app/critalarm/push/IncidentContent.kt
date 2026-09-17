package app.critalarm.push

import android.content.Context
import android.util.Log
import app.critalarm.storage.NativeConnectionStore
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.time.Instant

/** What the app shows for one incident, after the content has been resolved. */
data class IncidentContent(
    val title: String,
    val body: String,
    val tags: List<String> = emptyList(),
    val click: String? = null,
    val topic: String? = null,
)

/**
 * Fills in the title and body a `relay_content: none` push leaves out.
 *
 * api.md §3.2 says `GET /v1/incidents/{id}` is the route for exactly this. The
 * call is given ten seconds; past that the notification goes up with the
 * fallback text rather than making the user wait for an alarm.
 */
object IncidentContentFetcher {
    const val TIMEOUT_MS = 10_000

    /**
     * The same fetch, run from a broadcast receiver's thread.
     *
     * A manifest-declared receiver fired from a notification action gets about
     * ten seconds, and the ack POST already spends up to ten of them, so this
     * path cannot afford the full budget above. Five seconds of it is the most
     * the enrichment may take.
     */
    const val ACTION_CONNECT_TIMEOUT_MS = 2_000
    const val ACTION_READ_TIMEOUT_MS = 3_000

    private const val TAG = "CritAlarmFetch"

    fun fallback(payload: FcmIncidentPayload) = IncidentContent(
        title = payload.title ?: if (payload.isIncident) "Critical incident" else "Alert",
        body = payload.body ?: if (payload.isIncident) {
            "Immediate attention required"
        } else {
            "Open Crit Alarm to see details"
        },
    )

    /** Resolved content, or the fallback when the push carries nothing and the
     *  fetch does not land inside [TIMEOUT_MS]. */
    fun resolve(context: Context, payload: FcmIncidentPayload): IncidentContent {
        if (!payload.needsContentFetch) {
            return IncidentContent(
                title = payload.title ?: fallback(payload).title,
                body = payload.body ?: fallback(payload).body,
            )
        }
        val incidentId = payload.incidentId ?: return fallback(payload)
        return fetch(context, payload.server, incidentId) ?: fallback(payload)
    }

    fun fetch(
        context: Context,
        server: URI,
        incidentId: String,
        connectTimeoutMs: Int = TIMEOUT_MS,
        readTimeoutMs: Int = TIMEOUT_MS,
    ): IncidentContent? {
        val credentials = NativeConnectionStore(context).credentialsFor(server) ?: run {
            Log.w(TAG, "incident_fetch_missing_session incident_id=$incidentId")
            return null
        }
        val encoded = URLEncoder.encode(incidentId, StandardCharsets.UTF_8).replace("+", "%20")
        val url = credentials.first.toString().trimEnd('/') + "/v1/incidents/" + encoded
        return try {
            val connection = URL(url).openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.setRequestProperty("Authorization", "Bearer ${credentials.second}")
            connection.setRequestProperty("Accept", "application/json")
            connection.connectTimeout = connectTimeoutMs
            connection.readTimeout = readTimeoutMs
            val status = connection.responseCode
            if (status !in 200..299) {
                Log.w(TAG, "incident_fetch_failed_$status incident_id=$incidentId")
                connection.disconnect()
                return null
            }
            val text = connection.inputStream.bufferedReader().use { it.readText() }
            connection.disconnect()
            Log.i(TAG, "incident_fetch_ok incident_id=$incidentId")
            parse(text)
        } catch (error: Exception) {
            Log.w(TAG, "incident_fetch_failed incident_id=$incidentId reason=${error.javaClass.simpleName}")
            null
        }
    }

    /** Reads the newest message out of an incident object (api.md §3.2). */
    fun parse(json: String): IncidentContent? {
        val incident = runCatching { JSONObject(json) }.getOrNull() ?: return null
        val topic = incident.optString("topic").takeIf { it.isNotEmpty() }
        val messages = incident.optJSONArray("messages")
        if (messages == null || messages.length() == 0) return null
        val message = messages.optJSONObject(messages.length() - 1) ?: return null
        val tagsArray = message.optJSONArray("tags")
        val tags = buildList {
            for (i in 0 until (tagsArray?.length() ?: 0)) {
                tagsArray?.optString(i)?.takeIf { it.isNotEmpty() }?.let(::add)
            }
        }
        return IncidentContent(
            title = message.optString("title").takeIf { it.isNotEmpty() } ?: topic ?: "Critical incident",
            body = message.optString("message").takeIf { it.isNotEmpty() } ?: "Immediate attention required",
            tags = tags,
            click = message.optString("click").takeIf { it.isNotEmpty() },
            topic = topic,
        )
    }

    /**
     * When the desk timer rings, read off an ack response (api.md §3.2:
     * `POST /v1/incidents/{id}/ack` answers the incident plus
     * `desk_timer_fires_at`).
     *
     * Accepts unix seconds, unix milliseconds and an ISO-8601 string, the three
     * shapes NullableDateTimeConverter in lib/core/models/date_time_converter.dart
     * already accepts, so Kotlin and Dart read the same answer the same way.
     * Null when the field is absent, which is what a 409 body carries.
     */
    fun parseDeskTimerFiresAt(json: String): Long? {
        val incident = runCatching { JSONObject(json) }.getOrNull() ?: return null
        if (incident.isNull(DESK_TIMER_FIRES_AT)) return null
        val millis = when (val raw = incident.opt(DESK_TIMER_FIRES_AT)) {
            is Number -> epochMillis(raw.toLong())
            is String -> raw.toLongOrNull()?.let(::epochMillis)
                ?: runCatching { Instant.parse(raw).toEpochMilli() }.getOrNull()
            else -> null
        }
        return millis?.takeIf { it > 0L }
    }

    private const val DESK_TIMER_FIRES_AT = "desk_timer_fires_at"

    /** Ten digits or fewer is seconds. Anything longer is already milliseconds. */
    private fun epochMillis(value: Long) = if (value < 10_000_000_000L) value * 1000L else value
}

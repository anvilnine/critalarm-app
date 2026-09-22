package app.critalarm.storage

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * The same queue Dart uses, written from the native side.
 *
 * An ack tapped from a notification is handled here, with no Flutter engine
 * running. When the send fails the entry goes on this list, which is the exact
 * shape `AckQueue` in Dart reads, so the next app launch retries it.
 *
 * Keep the field names in step with `lib/core/ack/ack_queue_entry.dart`.
 */
class AckQueueStore(context: Context) {
    private val preferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    fun enqueue(action: String, incidentId: String, alarmFiredAtMs: Long? = null) {
        val now = System.currentTimeMillis()
        val entry = JSONObject().apply {
            put("id", "$now-native-$incidentId-$action")
            put("action", action)
            put("incident_id", incidentId)
            put("enqueued_at_ms", now)
            put("attempts", 1)
            // Wait the same two seconds the Dart queue waits after one failure.
            put("next_attempt_at_ms", now + FIRST_RETRY_MS)
            if (alarmFiredAtMs != null) put("alarm_fired_at_ms", alarmFiredAtMs)
        }
        val existing = runCatching { JSONArray(preferences.getString(KEY, "[]")) }.getOrNull() ?: JSONArray()
        existing.put(entry)
        preferences.edit().putString(KEY, existing.toString()).apply()
    }

    fun pendingCount(): Int =
        runCatching { JSONArray(preferences.getString(KEY, "[]")).length() }.getOrDefault(0)

    internal fun debugEntries(): List<Map<String, Any>> {
        val entries = runCatching { JSONArray(preferences.getString(KEY, "[]")) }.getOrNull() ?: return emptyList()
        return (0 until entries.length()).mapNotNull { index ->
            val entry = entries.optJSONObject(index) ?: return@mapNotNull null
            val action = entry.optString("action").takeIf(String::isNotEmpty) ?: return@mapNotNull null
            val incidentId = entry.optString("incident_id").takeIf(String::isNotEmpty) ?: return@mapNotNull null
            val attempts = entry.optInt("attempts", -1).takeIf { it >= 0 } ?: return@mapNotNull null
            val next = entry.optLong("next_attempt_at_ms", 0L).takeIf { it > 0 } ?: return@mapNotNull null
            buildMap {
                put("action", action)
                put("incident_id", incidentId)
                put("attempts", attempts)
                put("next_attempt_at", (next / 1_000L).toInt())
                entry.optString("last_error").takeIf(String::isNotEmpty)?.let { put("last_error", it) }
            }
        }
    }

    companion object {
        /** `AckQueue.storageKey` in Dart, with the shared_preferences prefix. */
        const val KEY = "flutter.ack_queue_v1"
        const val FIRST_RETRY_MS = 2_000L
    }
}

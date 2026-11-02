package app.critalarm.storage

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * Push events recorded while Dart was not running.
 *
 * Analytics is opt-in and the switch for it lives in Dart, so the native side
 * never reports anything itself. It writes what happened here, and Dart drains
 * the list on the next launch and reports it only if the user turned analytics
 * on. The list is capped so a phone that was offline for a week does not come
 * back with thousands of rows.
 *
 * Dart's preferences cannot be read before the first unlock after a reboot,
 * so nothing is recorded then. A push that lands before the unlock still
 * rings; it just leaves no row.
 */
class PushEventLog(context: Context) {
    private val preferences: SharedPreferences? =
        if (BootStorage.isUnlocked(context)) {
            context.getSharedPreferences(BootStorage.FLUTTER, Context.MODE_PRIVATE)
        } else {
            null
        }

    fun record(name: String, params: Map<String, String>) {
        val preferences = preferences ?: return
        val existing = runCatching { JSONArray(preferences.getString(KEY, "[]")) }.getOrNull() ?: JSONArray()
        val row = JSONObject().apply {
            put("name", name)
            put("at_ms", System.currentTimeMillis())
            params.forEach { (key, value) -> put(key, value) }
        }
        val trimmed = JSONArray()
        val start = maxOf(0, existing.length() - (MAX_ROWS - 1))
        for (i in start until existing.length()) trimmed.put(existing.get(i))
        trimmed.put(row)
        preferences.edit().putString(KEY, trimmed.toString()).apply()
    }

    /**
     * Stores the token FCM handed out while Dart was not running. False
     * before the first unlock, when there is nowhere it may go: a token is
     * never written to device-protected storage.
     */
    fun recordPendingToken(token: String): Boolean {
        val preferences = preferences ?: return false
        preferences.edit().putString(PENDING_TOKEN_KEY, token).apply()
        return true
    }

    internal fun recent(): List<Map<String, Any>> {
        val preferences = preferences ?: return emptyList()
        val rows = runCatching { JSONArray(preferences.getString(KEY, "[]")) }.getOrNull() ?: return emptyList()
        return (rows.length() - 1 downTo 0).mapNotNull { index ->
            rows.optJSONObject(index)?.let { row ->
                buildMap {
                    row.keys().forEach { key -> put(key, row.get(key)) }
                }
            }
        }
    }

    companion object {
        /** Read by `PushEventDrain` in Dart. The `flutter.` prefix is what the
         *  shared_preferences plugin puts on every key it owns. */
        const val KEY = "flutter.pending_push_events"
        const val PENDING_TOKEN_KEY = "flutter.pending_push_token"
        const val MAX_ROWS = 50
    }
}

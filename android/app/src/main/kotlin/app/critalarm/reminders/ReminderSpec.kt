package app.critalarm.reminders

import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.TimeZone

/** One button on a reminder. */
data class ReminderActionSpec(val id: String, val title: String, val opensApp: Boolean)

/**
 * One reminder as Dart's NativeReminderScheduler sends it.
 *
 * The fire time is wall-clock fields. They become an instant with the zone
 * the phone is in when the alarm is set, and again whenever it is re-armed
 * after a reboot or a zone change, so it keeps its clock time.
 */
data class ReminderSpec(
    val id: Int,
    val kind: String,
    val channelId: String,
    val year: Int,
    val month: Int,
    val day: Int,
    val hour: Int,
    val minute: Int,
    val second: Int,
    val title: String,
    val body: String,
    val hiddenPreview: String,
    val faceAsset: String,
    val actions: List<ReminderActionSpec>,
    val payload: Map<String, String>,
) {
    fun triggerAtMillis(zone: TimeZone = TimeZone.getDefault()): Long =
        Calendar.getInstance(zone).apply {
            clear()
            set(year, month - 1, day, hour, minute, second)
        }.timeInMillis

    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("kind", kind)
        put("channel", channelId)
        put("year", year)
        put("month", month)
        put("day", day)
        put("hour", hour)
        put("minute", minute)
        put("second", second)
        put("title", title)
        put("body", body)
        put("hidden_preview", hiddenPreview)
        put("face_asset", faceAsset)
        put(
            "actions",
            JSONArray().apply {
                actions.forEach {
                    put(
                        JSONObject()
                            .put("id", it.id)
                            .put("title", it.title)
                            .put("opens_app", it.opensApp),
                    )
                }
            },
        )
        put("payload", JSONObject(payload))
    }

    companion object {
        fun fromJson(json: JSONObject): ReminderSpec {
            val actions = json.optJSONArray("actions") ?: JSONArray()
            val payload = json.optJSONObject("payload") ?: JSONObject()
            return ReminderSpec(
                id = json.getInt("id"),
                kind = json.getString("kind"),
                channelId = json.getString("channel"),
                year = json.getInt("year"),
                month = json.getInt("month"),
                day = json.getInt("day"),
                hour = json.getInt("hour"),
                minute = json.getInt("minute"),
                second = json.optInt("second", 0),
                title = json.optString("title"),
                body = json.optString("body"),
                hiddenPreview = json.optString("hidden_preview"),
                faceAsset = json.optString("face_asset"),
                actions = (0 until actions.length()).map { index ->
                    val item = actions.getJSONObject(index)
                    ReminderActionSpec(
                        id = item.getString("id"),
                        title = item.optString("title"),
                        opensApp = item.optBoolean("opens_app", true),
                    )
                },
                payload = payload.keys().asSequence().associateWith { payload.optString(it) },
            )
        }

        /** Null when a field the scheduler needs is missing. */
        fun fromArgs(args: Map<*, *>): ReminderSpec? {
            fun int(key: String): Int? = (args[key] as? Number)?.toInt()
            fun text(key: String): String = args[key] as? String ?: ""
            val actions = (args["actions"] as? List<*>).orEmpty().mapNotNull { raw ->
                val item = raw as? Map<*, *> ?: return@mapNotNull null
                val id = item["id"] as? String ?: return@mapNotNull null
                ReminderActionSpec(
                    id = id,
                    title = item["title"] as? String ?: "",
                    opensApp = item["opens_app"] as? Boolean ?: true,
                )
            }
            val payload = (args["payload"] as? Map<*, *>).orEmpty().entries
                .filter { it.key != null && it.value != null }
                .associate { "${it.key}" to "${it.value}" }
            return ReminderSpec(
                id = int("id") ?: return null,
                kind = args["kind"] as? String ?: return null,
                channelId = args["channel"] as? String ?: return null,
                year = int("year") ?: return null,
                month = int("month") ?: return null,
                day = int("day") ?: return null,
                hour = int("hour") ?: return null,
                minute = int("minute") ?: return null,
                second = int("second") ?: 0,
                title = text("title"),
                body = text("body"),
                hiddenPreview = text("hidden_preview"),
                faceAsset = text("face_asset"),
                actions = actions,
                payload = payload,
            )
        }
    }
}

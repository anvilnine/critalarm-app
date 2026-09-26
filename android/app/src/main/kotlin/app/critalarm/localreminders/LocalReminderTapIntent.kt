package app.critalarm.localreminders

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import app.critalarm.MainActivity
import org.json.JSONObject

/**
 * The intents a reminder's body and buttons carry, and reading one back in
 * MainActivity. Separate from the incident tap extras, so the two can never
 * be mistaken for each other.
 */
object LocalReminderTapIntent {
    const val OPEN = "open"
    private const val EXTRA_KIND = "reminder_kind"
    private const val EXTRA_ACTION = "reminder_action"
    private const val EXTRA_PAYLOAD = "reminder_payload"

    private var sequence = 0

    fun open(context: Context, spec: LocalReminderSpec, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            // Only here to keep two PendingIntents apart. Nothing reads it,
            // and flutter_deeplinking_enabled is off in the manifest.
            data = Uri.parse("critalarm://reminders/${spec.id}/$action")
            putExtra(LocalReminderAlarms.EXTRA_ID, spec.id)
            putExtra(EXTRA_KIND, spec.kind)
            putExtra(EXTRA_ACTION, action)
            putExtra(EXTRA_PAYLOAD, JSONObject(spec.payload).toString())
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun inBackground(context: Context, spec: LocalReminderSpec, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, LocalReminderActionReceiver::class.java).apply {
            putExtra(LocalReminderAlarms.EXTRA_ID, spec.id)
            putExtra(LocalReminderActionReceiver.EXTRA_ACTION, action)
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * The reminder tap on [intent], read once, in the shape Dart's
     * NativeReminderScheduler.decodeTap reads. Null for anything else and
     * for an intent replayed from the recents list.
     */
    fun read(context: Context, intent: Intent?): Map<String, Any>? {
        if (intent == null) return null
        if ((intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) return null
        val kind = intent.getStringExtra(EXTRA_KIND) ?: return null
        val action = intent.getStringExtra(EXTRA_ACTION) ?: OPEN
        val id = intent.getIntExtra(LocalReminderAlarms.EXTRA_ID, -1)
        val payloadJson = intent.getStringExtra(EXTRA_PAYLOAD)
        intent.removeExtra(EXTRA_KIND)
        intent.removeExtra(EXTRA_ACTION)
        intent.removeExtra(EXTRA_PAYLOAD)
        intent.removeExtra(LocalReminderAlarms.EXTRA_ID)
        // A button press does not clear the notification by itself.
        if (id >= 0) context.getSystemService(NotificationManager::class.java)?.cancel(id)

        val payload = mutableMapOf<String, String>()
        payloadJson?.let { raw ->
            runCatching {
                val json = JSONObject(raw)
                json.keys().forEach { key -> payload[key] = json.optString(key) }
            }
        }
        sequence += 1
        return mapOf(
            "kind" to kind,
            "action" to action,
            "tap_id" to "r$sequence",
            "payload" to payload,
        )
    }
}

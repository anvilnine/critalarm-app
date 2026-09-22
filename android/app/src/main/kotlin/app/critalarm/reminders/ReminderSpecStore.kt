package app.critalarm.reminders

import android.content.Context
import org.json.JSONObject

/**
 * The reminders AlarmManager holds, kept so they can be listed for Dart and
 * re-armed after a reboot. AlarmManager itself forgets everything on a
 * reboot and has no way to list what it holds.
 */
object ReminderSpecStore {
    private const val FILE = "critalarm_reminders"

    private fun prefs(context: Context) =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun put(context: Context, spec: ReminderSpec) {
        prefs(context).edit().putString(spec.id.toString(), spec.toJson().toString()).apply()
    }

    fun get(context: Context, id: Int): ReminderSpec? =
        prefs(context).getString(id.toString(), null)?.let(::parse)

    fun remove(context: Context, id: Int) {
        prefs(context).edit().remove(id.toString()).apply()
    }

    fun all(context: Context): List<ReminderSpec> =
        prefs(context).all.values.mapNotNull { (it as? String)?.let(::parse) }

    private fun parse(raw: String): ReminderSpec? =
        runCatching { ReminderSpec.fromJson(JSONObject(raw)) }.getOrNull()
}

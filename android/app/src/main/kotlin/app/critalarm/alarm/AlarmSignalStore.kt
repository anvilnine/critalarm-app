package app.critalarm.alarm

import android.content.Context
import org.json.JSONArray

/**
 * Reads the per-topic flash and strong vibration switches Dart wrote.
 *
 * The foreground service runs with no Dart engine, so it reads the same
 * `SharedPreferences` file the `shared_preferences` plugin writes, where every
 * key is prefixed `flutter.`, the way [app.critalarm.sound.AlarmSoundStore]
 * reads the sound choice. Each switch is one row holding a JSON list of topic
 * names. A topic that is not in the list is off. The Dart side is
 * `lib/core/alarm/alarm_signal_store.dart`; keep the keys in step.
 */
object AlarmSignalStore {
    private const val PREFS = "FlutterSharedPreferences"
    private const val FLASH_KEY = "flutter.alarm_flash_topics"
    private const val VIBRATION_KEY = "flutter.alarm_strong_vibration_topics"

    /** The topics that have each switch on. */
    data class Saved(
        val flashTopics: Set<String> = emptySet(),
        val vibrationTopics: Set<String> = emptySet(),
    ) {
        /** False on a phone where nobody turned either switch on for any topic. */
        val anyOn: Boolean get() = flashTopics.isNotEmpty() || vibrationTopics.isNotEmpty()
    }

    fun read(context: Context): Saved {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return Saved(
            flashTopics = parseTopics(prefs.getString(FLASH_KEY, null)),
            vibrationTopics = parseTopics(prefs.getString(VIBRATION_KEY, null)),
        )
    }

    /**
     * One row to a set of topic names. Anything that is not a JSON list of
     * names reads as empty, which is off. Pure, so the JVM tests can run it.
     */
    fun parseTopics(raw: String?): Set<String> {
        if (raw.isNullOrEmpty()) return emptySet()
        return runCatching {
            val list = JSONArray(raw)
            (0 until list.length())
                .mapNotNull { list.opt(it) as? String }
                .filter(String::isNotEmpty)
                .toSet()
        }.getOrDefault(emptySet())
    }
}

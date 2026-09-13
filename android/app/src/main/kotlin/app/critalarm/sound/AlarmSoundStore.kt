package app.critalarm.sound

import android.content.Context
import android.content.res.AssetFileDescriptor
import android.util.Log
import io.flutter.FlutterInjector
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** Where the bytes for one sound live. */
sealed interface AlarmSoundSource {
    /** A bundled sound, read straight out of the apk. */
    data class Asset(val assetPath: String) : AlarmSoundSource

    /** A sound the user imported, sitting in the app's own folder. */
    data class Imported(val path: String) : AlarmSoundSource
}

/**
 * Reads the sound choice Dart wrote.
 *
 * The foreground service runs with no Dart engine, so it cannot ask the app
 * which sound to play. It reads the same `SharedPreferences` file the
 * `shared_preferences` plugin writes, where every key is prefixed `flutter.`.
 */
object AlarmSoundStore {
    const val FALLBACK_ID = "classic_siren"

    /** Where imported sounds are copied to. Also used by the import call. */
    fun soundsDir(context: Context): File =
        File(context.filesDir, "sounds").apply { mkdirs() }

    private const val PREFS = "FlutterSharedPreferences"
    private const val DEFAULT_KEY = "flutter.alarm_sound_default"
    private const val PER_TOPIC_KEY = "flutter.alarm_sound_per_topic"
    private const val USER_LIST_KEY = "flutter.alarm_sound_user_list"
    private const val TAG = "CritAlarmSound"

    /**
     * Which sound rings.
     *
     * [topic] is null for an incident push, because api.md §5.2 carries no
     * topic on one. That falls through to the default, which is what the
     * picker calls "rings for every topic that has not picked its own".
     */
    fun soundIdFor(context: Context, topic: String?): String {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val fallback = prefs.getString(DEFAULT_KEY, null)?.takeIf(String::isNotEmpty)
            ?: FALLBACK_ID
        if (topic.isNullOrEmpty()) return fallback
        val raw = prefs.getString(PER_TOPIC_KEY, null) ?: return fallback
        return runCatching { JSONObject(raw).optString(topic, "") }
            .getOrNull()?.takeIf(String::isNotEmpty) ?: fallback
    }

    /**
     * Turns a sound id into something MediaPlayer can open.
     *
     * An imported sound whose file has gone missing falls back to the bundled
     * default, so the alarm always rings with something.
     */
    fun resolve(context: Context, soundId: String): AlarmSoundSource {
        if (soundId.startsWith("user_")) {
            val path = importedPath(context, soundId)
            if (path != null && File(path).exists()) return AlarmSoundSource.Imported(path)
            Log.w(TAG, "sound_missing sound_id=$soundId falling_back_to=$FALLBACK_ID")
            return AlarmSoundSource.Asset(assetPathFor(FALLBACK_ID))
        }
        return AlarmSoundSource.Asset(assetPathFor(soundId))
    }

    fun assetPathFor(soundId: String) = "assets/sounds/$soundId.ogg"

    private fun importedPath(context: Context, soundId: String): String? {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(USER_LIST_KEY, null) ?: return null
        return runCatching {
            val list = JSONArray(raw)
            (0 until list.length())
                .map(list::getJSONObject)
                .firstOrNull { it.optString("id") == soundId }
                ?.optString("path")
                ?.takeIf(String::isNotEmpty)
        }.getOrNull()
    }

    /**
     * Opens a bundled asset. Flutter stores assets under `flutter_assets/`,
     * and the loader knows the exact key. In a service started straight off an
     * FCM message the loader may not be up yet, so the plain prefix is the
     * fallback.
     */
    fun openAsset(context: Context, assetPath: String): AssetFileDescriptor {
        val key = runCatching {
            FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(assetPath)
        }.getOrNull() ?: "flutter_assets/$assetPath"
        return runCatching { context.assets.openFd(key) }
            .getOrElse { context.assets.openFd("flutter_assets/$assetPath") }
    }
}

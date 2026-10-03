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
     * The sound to ring for [topic], and its id.
     *
     * [topic] is null for an incident push, because api.md §5.2 carries no
     * topic on one. That goes straight to the default, which is what the
     * picker calls "rings for every topic that has not picked its own".
     *
     * The topic's own choice comes first, then the default. A choice whose
     * file is gone (an imported or pack sound) is skipped, the same way the
     * picker moves a topic back to the default when its sound goes, and only
     * when both are gone does the bundled classic siren ring. A file that is
     * there but will not decode falls back later, in AlarmPlayer, through
     * [app.critalarm.alarm.AlarmFallback].
     */
    fun resolveForTopic(context: Context, topic: String?): Pair<String, AlarmSoundSource> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val defaultId = prefs.getString(DEFAULT_KEY, null)?.takeIf(String::isNotEmpty) ?: FALLBACK_ID
        val topicId = topicSoundId(prefs.getString(PER_TOPIC_KEY, null), topic)
        val picked = resolveChain(soundsDir(context), listOfNotNull(topicId, defaultId)) {
            importedPath(context, it)
        }
        if (picked.first != (topicId ?: defaultId)) {
            Log.w(TAG, "sound_missing sound_id=${topicId ?: defaultId} falling_back_to=${picked.first}")
        }
        return picked
    }

    /** The topic's own sound id from the per-topic JSON, or null. */
    private fun topicSoundId(raw: String?, topic: String?): String? {
        if (topic.isNullOrEmpty() || raw == null) return null
        return runCatching { JSONObject(raw).optString(topic, "") }
            .getOrNull()?.takeIf(String::isNotEmpty)
    }

    /**
     * The first of [soundIds] whose file is there, then the classic siren.
     * Pure, so the JVM tests can run it.
     */
    fun resolveChain(
        soundsDir: File,
        soundIds: List<String>,
        importedPath: (String) -> String?,
    ): Pair<String, AlarmSoundSource> {
        for (id in soundIds.distinct()) {
            val resolved = resolveIn(soundsDir, id, importedPath)
            if (!resolved.fellBack) return id to resolved.source
        }
        return FALLBACK_ID to AlarmSoundSource.Asset(assetPathFor(FALLBACK_ID))
    }

    /** What [resolveIn] picked, and whether that was the fallback. */
    data class Resolved(val source: AlarmSoundSource, val fellBack: Boolean)

    /**
     * One id to a source: no Android, no log, so the JVM tests can run it.
     * [importedPath] looks a user sound's path up by id.
     */
    fun resolveIn(soundsDir: File, soundId: String, importedPath: (String) -> String?): Resolved {
        val fallback = Resolved(AlarmSoundSource.Asset(assetPathFor(FALLBACK_ID)), fellBack = true)
        if (soundId.startsWith("user_")) {
            val path = importedPath(soundId)
            if (path != null && File(path).exists()) {
                return Resolved(AlarmSoundSource.Imported(path), fellBack = false)
            }
            return fallback
        }
        if (SoundPackRules.isPackSound(soundId)) {
            // A pack sound rings from its copy in the sounds folder, never from
            // the pack, which Play may move or drop.
            if (SoundPackRules.isSafeName(soundId) && SoundPackRules.isInstalled(soundsDir, soundId)) {
                val path = SoundPackRules.installedFile(soundsDir, soundId).path
                return Resolved(AlarmSoundSource.Imported(path), fellBack = false)
            }
            return fallback
        }
        return Resolved(AlarmSoundSource.Asset(assetPathFor(soundId)), fellBack = false)
    }

    // Android plays the .ogg of every bundled sound. The rule lives in
    // BundledSounds.extensionFor (lib/core/sound/bundled_sounds.dart); keep the two in step.
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

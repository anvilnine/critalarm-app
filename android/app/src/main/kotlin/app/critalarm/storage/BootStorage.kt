package app.critalarm.storage

import android.content.Context
import android.content.SharedPreferences
import android.os.UserManager
import android.util.Log
import java.net.URI

/**
 * What the alarm reads before the first unlock after a reboot.
 *
 * Android keeps an app's normal files locked until the person unlocks the
 * phone once. Only device-protected storage can be read before that, so a
 * phone that restarts overnight can ring from nothing else. Opening a normal
 * preferences file then throws, and a throw there takes the ring down with it.
 *
 * Three kinds of file:
 *
 * - [MOVED]: files with nothing secret in them that the ring path writes
 *   itself. They live in device-protected storage for good. [prefs] moves an
 *   old copy across the first time it runs with the phone unlocked.
 * - [MIRROR]: a copy of the few keys the ring reads out of the preferences
 *   Dart writes ([BootMirror]). That file also holds the session, the device
 *   token and the ack queue, so it stays where it is and only the copy moves.
 * - Everything else stays in normal storage. No token and no account data is
 *   ever written to device-protected storage.
 */
object BootStorage {
    /** [IncidentDeliveryStore]: flags, instants, the topic and the chain of each incident. */
    const val INCIDENTS = "incident_delivery"

    /** The alarm volume from before a ring, so it goes back after one. */
    const val RING_VOLUME = "critalarm_ring_volume"

    /** The language picked in the app, for the alarm card's words. */
    const val LOCALE = "critalarm_locale"

    /** [BootMirror]'s copy of Dart's preferences. */
    const val MIRROR = "critalarm_boot_mirror"

    /** The file Dart's `shared_preferences` plugin writes. Never moved. */
    const val FLUTTER = "FlutterSharedPreferences"

    /** Files that live in device-protected storage for good. */
    val MOVED = listOf(INCIDENTS, RING_VOLUME, LOCALE)

    /** Every file in device-protected storage. The key test reads this list. */
    val FILES = MOVED + MIRROR

    private const val TAG = "CritAlarmBoot"
    private val LOCK = Any()
    private val movedThisProcess = mutableSetOf<String>()

    @Volatile
    private var unlockSeen = false

    /** True once the person has unlocked the phone since it started. */
    fun isUnlocked(context: Context): Boolean {
        if (unlockSeen) return true
        val unlocked = runCatching {
            context.getSystemService(UserManager::class.java)?.isUserUnlocked ?: true
        }.getOrDefault(true)
        if (unlocked) unlockSeen = true
        return unlocked
    }

    fun deviceContext(context: Context): Context {
        val app = context.applicationContext ?: context
        return if (app.isDeviceProtectedStorage) app else app.createDeviceProtectedStorageContext()
    }

    /**
     * One of the [MOVED] files, in device-protected storage. With the phone
     * unlocked, the first call in a process merges in whatever an older
     * version left in normal storage and deletes that copy.
     */
    fun prefs(context: Context, name: String): SharedPreferences {
        val device = deviceContext(context)
        val target = device.getSharedPreferences(name, Context.MODE_PRIVATE)
        if (name in MOVED && isUnlocked(context)) moveOnce(context, name, target)
        return target
    }

    /**
     * Dart's preferences for a read on the ring path: the real file once the
     * phone is unlocked, [BootMirror]'s copy before. Both hold the same key
     * names, so a reader does not care which it got. Read only: nothing on
     * the ring path writes Dart's file.
     */
    fun flutterPrefs(context: Context): SharedPreferences {
        val app = context.applicationContext ?: context
        if (isUnlocked(app)) return app.getSharedPreferences(FLUTTER, Context.MODE_PRIVATE)
        return deviceContext(app).getSharedPreferences(MIRROR, Context.MODE_PRIVATE)
    }

    private fun moveOnce(context: Context, name: String, target: SharedPreferences) {
        synchronized(LOCK) {
            if (name in movedThisProcess) return
            movedThisProcess += name
            val app = context.applicationContext ?: context
            if (app.isDeviceProtectedStorage) return
            runCatching {
                val old = app.getSharedPreferences(name, Context.MODE_PRIVATE)
                val moved = BootMigration.merge(from = old, to = target)
                app.deleteSharedPreferences(name)
                if (moved > 0) Log.i(TAG, "boot_storage_moved file=$name keys=$moved")
            }.onFailure { Log.w(TAG, "boot_storage_move_failed file=$name error=$it") }
        }
    }
}

/** Moving a file's keys from normal storage into device-protected storage. Pure. */
object BootMigration {
    /**
     * Copies every key of [from] that [to] does not have yet, then empties
     * [from]. A key [to] already holds was written since the reboot, so it is
     * newer and stays. Answers how many keys were copied.
     */
    fun merge(from: SharedPreferences, to: SharedPreferences): Int {
        val missing = from.all.filterKeys { !to.contains(it) }
        if (missing.isNotEmpty()) {
            val edit = to.edit()
            missing.forEach { (key, value) -> putValue(edit, key, value) }
            edit.commit()
        }
        if (from.all.isNotEmpty()) from.edit().clear().commit()
        return missing.size
    }

    /** One value, whatever its type. Null removes the key. */
    @Suppress("UNCHECKED_CAST")
    fun putValue(edit: SharedPreferences.Editor, key: String, value: Any?) {
        when (value) {
            null -> edit.remove(key)
            is Boolean -> edit.putBoolean(key, value)
            is Int -> edit.putInt(key, value)
            is Long -> edit.putLong(key, value)
            is Float -> edit.putFloat(key, value)
            is String -> edit.putString(key, value)
            is Set<*> -> edit.putStringSet(key, value as Set<String>)
        }
    }
}

/**
 * The few keys of Dart's preferences the ring reads, copied into
 * device-protected storage so they can be read before the first unlock.
 *
 * Every key keeps its name, so [BootStorage.flutterPrefs] can hand either
 * file to the same reader. The one exception is the server address: the
 * session holds it next to the device token, so only the address is copied,
 * under [SERVER_KEY].
 *
 * Nothing here is a token or account data: topic switches and timers, quiet
 * hours, the ring switches and the sound ids.
 */
object BootMirror {
    /** The server address alone, cut out of the session. */
    const val SERVER_KEY = "server_address"

    /** Where Dart keeps the session: `server|...|token`. Never copied whole. */
    const val SESSION_KEY = "flutter.api_session"

    /** Single keys the ring reads. */
    val KEYS = setOf(
        "flutter.quiet_hours_enabled",
        "flutter.quiet_hours_start_minutes",
        "flutter.quiet_hours_end_minutes",
        "flutter.quiet_hours_critical_rings",
        "flutter.alarm_sound_default",
        "flutter.alarm_sound_per_topic",
        "flutter.ring_bright_screen",
        "flutter.ring_vibrate",
        "flutter.quiet_alarm",
    )

    /** One key per topic: the critical switch, the timers and the challenge flag. */
    val PREFIXES = listOf(
        "flutter.topic_critical.",
        "flutter.topic_timers.",
        "flutter.topic_challenge_owed.",
    )

    private const val TAG = "CritAlarmBoot"

    /** True for a key of Dart's whose change has to reach the copy. */
    fun follows(key: String?): Boolean =
        key == null || key == SESSION_KEY || key in KEYS || PREFIXES.any(key::startsWith)

    /** What the copy holds for [all], everything Dart has written. */
    fun mirrorOf(all: Map<String, *>): Map<String, Any> {
        val out = mutableMapOf<String, Any>()
        for ((key, value) in all) {
            if (value == null) continue
            if (key in KEYS || PREFIXES.any(key::startsWith)) out[key] = value
        }
        serverAddress(all[SESSION_KEY] as? String)?.let { out[SERVER_KEY] = it }
        return out
    }

    /** The address in front of the session's first `|`, when it is one. */
    fun serverAddress(session: String?): String? {
        val raw = session?.substringBefore('|')?.trim()?.takeIf(String::isNotEmpty) ?: return null
        val uri = runCatching { URI(raw) }.getOrNull() ?: return null
        if (uri.scheme != "http" && uri.scheme != "https") return null
        if (uri.host.isNullOrBlank() || uri.userInfo != null) return null
        return raw
    }

    /**
     * Brings [to] in line with [from]: every followed key copied, every key
     * that is gone from [from] removed. Writes only when something changed,
     * and answers whether it did.
     */
    fun copy(from: SharedPreferences, to: SharedPreferences): Boolean {
        val wanted = mirrorOf(from.all)
        val held = to.all
        val stale = held.keys - wanted.keys
        val changed = wanted.filter { (key, value) -> held[key] != value }
        if (stale.isEmpty() && changed.isEmpty()) return false
        val edit = to.edit()
        stale.forEach(edit::remove)
        changed.forEach { (key, value) -> BootMigration.putValue(edit, key, value) }
        edit.commit()
        return true
    }

    /** Refreshes the copy from Dart's file. Does nothing before the first unlock. */
    fun sync(context: Context) {
        if (!BootStorage.isUnlocked(context)) return
        runCatching {
            val app = context.applicationContext ?: context
            val from = app.getSharedPreferences(BootStorage.FLUTTER, Context.MODE_PRIVATE)
            val to = BootStorage.deviceContext(app).getSharedPreferences(BootStorage.MIRROR, Context.MODE_PRIVATE)
            if (copy(from, to)) Log.i(TAG, "boot_mirror_synced keys=${to.all.size}")
        }.onFailure { Log.w(TAG, "boot_mirror_sync_failed error=$it") }
    }

    /**
     * Held here because [SharedPreferences] keeps its listeners weakly. One
     * per process is enough.
     */
    @Volatile
    private var listener: SharedPreferences.OnSharedPreferenceChangeListener? = null

    /**
     * Syncs now, then again every time Dart writes a key the copy follows.
     * Dart writes through the same in-process file, so its changes arrive
     * here.
     */
    fun follow(context: Context) {
        sync(context)
        if (listener != null || !BootStorage.isUnlocked(context)) return
        val app = context.applicationContext ?: context
        val watch = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            if (follows(key)) sync(app)
        }
        listener = watch
        runCatching {
            app.getSharedPreferences(BootStorage.FLUTTER, Context.MODE_PRIVATE)
                .registerOnSharedPreferenceChangeListener(watch)
        }
    }
}

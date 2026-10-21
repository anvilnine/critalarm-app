package app.critalarm.alarm

import android.content.Context
import app.critalarm.storage.BootStorage

/**
 * Whether this build was asked to ring quietly.
 *
 * The foreground service runs with no Dart engine, so it cannot ask the app.
 * Dart writes the flag on every launch into the same `SharedPreferences` file
 * the `shared_preferences` plugin uses, the way [app.critalarm.sound.AlarmSoundStore]
 * reads the sound choice. A build without `--dart-define=QUIET_ALARM=true`
 * writes false, so a store build can only ever read false.
 */
object QuietAlarm {
    private const val KEY = "flutter.quiet_alarm"

    /** Seconds a quiet ring lasts before it stops itself. */
    const val RING_SECONDS = 5

    fun isOn(context: Context): Boolean = runCatching {
        BootStorage.flutterPrefs(context).getBoolean(KEY, false)
    }.getOrDefault(false)
}

package app.critalarm.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import app.critalarm.storage.BootStorage

/** [AlarmStream] on the phone's alarm stream. */
class AudioManagerStream(private val audioManager: AudioManager) : AlarmStream {
    override val volume: Int get() = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)
    override val max: Int get() = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
    override fun set(volume: Int) = audioManager.setStreamVolume(AudioManager.STREAM_ALARM, volume, 0)
}

/**
 * [SavedVolume] in the app's own preferences file. Written with commit, so
 * the value is on disk before the stream is raised. Device-protected, so a
 * ring before the first unlock can save and restore it too.
 */
class PrefsSavedVolume internal constructor(private val prefs: SharedPreferences) : SavedVolume {
    constructor(context: Context) : this(BootStorage.prefs(context, PREFS))

    override fun read(): Int? = if (prefs.contains(KEY)) prefs.getInt(KEY, 0) else null

    override fun write(volume: Int) {
        prefs.edit().putInt(KEY, volume).commit()
    }

    override fun clear() {
        prefs.edit().remove(KEY).commit()
    }

    internal companion object {
        const val PREFS = BootStorage.RING_VOLUME
        const val KEY = "volume_before_ring"
    }
}

/**
 * Keeps the alarm stream at its maximum while a ring plays. Listens for the
 * system's volume broadcast and also looks once a second, for phones that do
 * not send it. Main thread only.
 */
class RingVolumeWatch(private val context: Context, private val volume: RingVolume) {
    private val main = Handler(Looper.getMainLooper())
    private var receiver: BroadcastReceiver? = null

    private val poll = object : Runnable {
        override fun run() {
            check("poll")
            main.postDelayed(this, POLL_MS)
        }
    }

    fun start() {
        if (receiver != null) return
        val watching = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val stream = intent.getIntExtra(EXTRA_STREAM, AudioManager.STREAM_ALARM)
                if (stream == AudioManager.STREAM_ALARM) check("broadcast")
            }
        }
        val filter = IntentFilter(VOLUME_CHANGED)
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(watching, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                context.registerReceiver(watching, filter)
            }
        }.onFailure { Log.w(TAG, "alarm_volume_watch_failed error=$it") }
        receiver = watching
        main.postDelayed(poll, POLL_MS)
    }

    fun stop() {
        main.removeCallbacks(poll)
        receiver?.let { runCatching { context.unregisterReceiver(it) } }
        receiver = null
    }

    private fun check(source: String) {
        runCatching { if (volume.holdAtMax()) Log.i(TAG, "alarm_volume_put_back source=$source") }
            .onFailure { Log.w(TAG, "alarm_volume_put_back_failed error=$it") }
    }

    companion object {
        private const val TAG = "CritAlarmAlarm"
        private const val POLL_MS = 1000L

        /** `AudioManager.VOLUME_CHANGED_ACTION`, which the SDK hides. */
        private const val VOLUME_CHANGED = "android.media.VOLUME_CHANGED_ACTION"
        private const val EXTRA_STREAM = "android.media.EXTRA_VOLUME_STREAM_TYPE"

        fun ringVolume(context: Context): RingVolume = RingVolume(
            AudioManagerStream(context.getSystemService(AudioManager::class.java)),
            PrefsSavedVolume(context),
        )

        /**
         * App start: a volume saved by a ring that never ended (the process
         * died mid-ring) goes back on the alarm stream.
         */
        fun recoverOnLaunch(context: Context) {
            runCatching {
                if (ringVolume(context).recover(ringing = AlarmForegroundService.isRinging)) {
                    Log.i(TAG, "alarm_volume_recovered")
                }
            }.onFailure { Log.w(TAG, "alarm_volume_recover_failed error=$it") }
        }
    }
}

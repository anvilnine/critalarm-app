package app.critalarm.alarm

import android.content.Context
import android.media.AudioAttributes
import android.media.audiofx.AudioEffect
import android.media.audiofx.HapticGenerator
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.annotation.RequiresApi

/**
 * The vibration that goes with a ring, when "Vibrate with the alarm" is on.
 * Started again with the sound on every ring, so the two stay in step. Main
 * thread only.
 */
class RingHaptics(private val context: Context) {
    private var generator: AudioEffect? = null

    /** Only a vibration this class started is cancelled, never the channel's own. */
    private var vibrating = false

    fun pickMode(): HapticMode = HapticPattern.mode(
        switchOn = RingSwitches.vibrate(context),
        sdk = Build.VERSION.SDK_INT,
        generatorAvailable = { Build.VERSION.SDK_INT >= HapticPattern.GENERATOR_SDK && generatorAvailable() },
    )

    /**
     * The sound began playing on [sessionId]. [waveform] is the pattern made
     * from it, or null when there was no decoded sound to read.
     */
    fun onSoundStarted(mode: HapticMode, sessionId: Int, waveform: Waveform?) {
        stop()
        if (mode == HapticMode.OFF) return
        if (mode == HapticMode.GENERATOR && Build.VERSION.SDK_INT >= HapticPattern.GENERATOR_SDK) {
            if (attachGenerator(sessionId)) return
        }
        vibrate(waveform?.takeUnless { it.isStill || it.durationMs <= 0 } ?: HapticPattern.PULSE, mode)
    }

    fun stop() {
        generator?.let { effect ->
            runCatching { effect.enabled = false }
            runCatching { effect.release() }
        }
        generator = null
        if (vibrating) runCatching { vibrator()?.cancel() }
        vibrating = false
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun generatorAvailable(): Boolean = runCatching { HapticGenerator.isAvailable() }.getOrDefault(false)

    @RequiresApi(Build.VERSION_CODES.S)
    private fun attachGenerator(sessionId: Int): Boolean = try {
        generator = HapticGenerator.create(sessionId).also { it.enabled = true }
        Log.i(TAG, "alarm_haptics mode=generator")
        true
    } catch (error: Exception) {
        Log.w(TAG, "alarm_haptics_generator_failed error=$error")
        generator = null
        false
    }

    private fun vibrate(waveform: Waveform, mode: HapticMode) {
        val target = vibrator() ?: return
        if (!target.hasVibrator()) return
        val effect = VibrationEffect.createWaveform(waveform.timings, waveform.amplitudes, 0)
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                target.vibrate(effect, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM))
            } else {
                @Suppress("DEPRECATION")
                target.vibrate(effect, ALARM_AUDIO)
            }
            vibrating = true
            Log.i(TAG, "alarm_haptics mode=pattern picked=$mode segments=${waveform.timings.size} ms=${waveform.durationMs}")
        }.onFailure { Log.w(TAG, "alarm_haptics_failed error=$it") }
    }

    private fun vibrator(): Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        context.getSystemService(VibratorManager::class.java)?.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Vibrator::class.java)
    }

    private companion object {
        const val TAG = "CritAlarmAlarm"

        val ALARM_AUDIO: AudioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
    }
}

/**
 * The two ring switches from Settings. Dart keeps them in the same
 * preferences file the `shared_preferences` plugin uses, so they are read
 * with no Flutter engine running. Both default to on.
 */
object RingSwitches {
    private const val PREFS = "FlutterSharedPreferences"
    const val BRIGHT_SCREEN_KEY = "flutter.ring_bright_screen"
    const val VIBRATE_KEY = "flutter.ring_vibrate"

    fun brightScreen(context: Context): Boolean = read(context, BRIGHT_SCREEN_KEY)

    fun vibrate(context: Context): Boolean = read(context, VIBRATE_KEY)

    private fun read(context: Context, key: String): Boolean = runCatching {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(key, true)
    }.getOrDefault(true)
}

package app.critalarm.alarm

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.media.AudioAttributes
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

/**
 * The camera flash and the strong vibration that go with a ring.
 *
 * Both are extras. Neither touches the sound, and nothing here can fail the
 * ring: every call into the camera or the vibrator is caught and logged.
 *
 * This is the only class that turns either one on, and [stop] is the only way
 * they go off. Every path that ends a ring reaches [stop], directly or through
 * [update] with both false:
 *
 * - [AlarmForegroundService.onDestroy], which covers every stop of the
 *   service: acknowledge and Stop (the last held incident going), Silence,
 *   `stopRinging`, an ack, close or expire push, and the system taking the
 *   service down.
 * - The quiet build's ring running out, through [AlarmPlayer]'s callback.
 * - A handover to an incident whose topic has them off, through [update].
 *
 * The torch needs no camera permission: `setTorchMode` works without one. The
 * camera itself is never opened.
 */
class RingSignals(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())
    private var flashing = false
    private var torchLit = false
    private var flashSkipLogged = false
    private var vibrating = false

    private val blink = object : Runnable {
        override fun run() {
            if (!flashing) return
            val next = !torchLit
            setTorch(next)
            main.postDelayed(
                this,
                if (next) RingSignalRule.FLASH_ON_MS else RingSignalRule.FLASH_OFF_MS,
            )
        }
    }

    /**
     * Starts what is wanted and stops what is not. Safe to call again with
     * the same values, from any thread.
     */
    fun update(flash: Boolean, vibration: Boolean) {
        onMain {
            if (flash) startFlash() else stopFlash("not_wanted")
            if (vibration) startVibration() else stopVibration("not_wanted")
        }
    }

    /** Turns both off and lets go of the torch. Safe to call more than once, from any thread. */
    fun stop(reason: String) {
        onMain {
            stopFlash(reason)
            stopVibration(reason)
        }
    }

    private fun onMain(action: () -> Unit) {
        AlarmPlayerRules.onMain(Looper.getMainLooper().isCurrentThread, { main.post(it) }, action)
    }

    private fun startFlash() {
        if (flashing) return
        if (torchCameraId(context) == null) {
            Log.i(TAG, "alarm_flash_skipped reason=no_flash_unit")
            return
        }
        flashing = true
        torchLit = false
        flashSkipLogged = false
        Log.i(TAG, "alarm_flash_started flashes_per_second=${RingSignalRule.flashesPerSecond}")
        blink.run()
    }

    private fun stopFlash(reason: String) {
        if (!flashing) return
        flashing = false
        main.removeCallbacks(blink)
        // Always asked for, whatever this class believes the light is doing,
        // so no path can leave it on.
        setTorch(false)
        Log.i(TAG, "alarm_flash_stopped reason=$reason")
    }

    /**
     * Turns the light on or off. Another app holding the camera makes this
     * throw: the flash is skipped for that blink, logged once, and tried
     * again on the next one, so it starts as soon as the camera is free. The
     * ring carries on either way.
     */
    private fun setTorch(on: Boolean) {
        try {
            val id = torchCameraId(context) ?: return
            context.getSystemService(CameraManager::class.java).setTorchMode(id, on)
            torchLit = on
            flashSkipLogged = false
        } catch (error: Exception) {
            torchLit = false
            if (!flashSkipLogged) {
                flashSkipLogged = true
                Log.w(TAG, "alarm_flash_skipped reason=${error.javaClass.simpleName} on=$on")
            }
        }
    }

    private fun startVibration() {
        if (vibrating) return
        try {
            val vibrator = vibrator()
            if (vibrator == null || !vibrator.hasVibrator()) {
                Log.i(TAG, "alarm_vibration_skipped reason=no_vibrator")
                return
            }
            // Full strength where the phone can set one. Elsewhere the phone
            // only has on and off, and on is all it has.
            val hasAmplitude = vibrator.hasAmplitudeControl()
            val effect = if (hasAmplitude) {
                VibrationEffect.createWaveform(
                    RingSignalRule.VIBRATION_TIMINGS_MS,
                    RingSignalRule.VIBRATION_AMPLITUDES,
                    RingSignalRule.VIBRATION_REPEAT_FROM,
                )
            } else {
                VibrationEffect.createWaveform(
                    RingSignalRule.VIBRATION_ON_OFF_TIMINGS_MS,
                    RingSignalRule.VIBRATION_REPEAT_FROM,
                )
            }
            // Marked as an alarm, so it runs from the service with the app in
            // the background and is not held back by silent mode.
            if (Build.VERSION.SDK_INT >= 33) {
                vibrator.vibrate(
                    effect,
                    VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM),
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(
                    effect,
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
            }
            vibrating = true
            Log.i(TAG, "alarm_vibration_started amplitude_control=$hasAmplitude")
        } catch (error: Exception) {
            Log.w(TAG, "alarm_vibration_skipped reason=${error.javaClass.simpleName}")
        }
    }

    private fun stopVibration(reason: String) {
        if (!vibrating) return
        vibrating = false
        runCatching { vibrator()?.cancel() }
            .onFailure { Log.w(TAG, "alarm_vibration_stop_failed error=$it") }
        Log.i(TAG, "alarm_vibration_stopped reason=$reason")
    }

    private fun vibrator(): Vibrator? =
        if (Build.VERSION.SDK_INT >= 31) {
            context.getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Vibrator::class.java)
        }

    companion object {
        private const val TAG = "CritAlarmAlarm"

        /**
         * The camera whose flash the torch uses, or null on a phone with no
         * flash unit. The back camera when there is a choice. Reading this
         * opens no camera and needs no permission.
         */
        fun torchCameraId(context: Context): String? = runCatching {
            val manager = context.getSystemService(CameraManager::class.java) ?: return null
            val withFlash = manager.cameraIdList.filter { id ->
                manager.getCameraCharacteristics(id)
                    .get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            }
            withFlash.firstOrNull { id ->
                manager.getCameraCharacteristics(id).get(CameraCharacteristics.LENS_FACING) ==
                    CameraCharacteristics.LENS_FACING_BACK
            } ?: withFlash.firstOrNull()
        }.getOrNull()

        /** Whether this phone has a flash unit. No flash, no flash switch. */
        fun hasTorch(context: Context): Boolean = torchCameraId(context) != null
    }
}

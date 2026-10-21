package app.critalarm.alarm

import android.app.Activity
import android.util.Log
import android.view.KeyEvent
import android.view.WindowManager

/**
 * What the alarm screen does to its own window while it rings. With "Bright
 * screen when it rings" on, the window goes to full brightness and keeps the
 * screen on. Either way a volume-down press does nothing while the alarm
 * plays. Only this window changes: the phone's brightness setting is never
 * written, and the window lets go when the screen stops ringing.
 */
class RingWindow(private val activity: Activity) {
    private var ringingFor: String? = null

    /** The alarm screen for [incidentId] rings, or is in front again. */
    fun ringing(incidentId: String) {
        ringingFor = incidentId
        apply(RingWindowRule.brightness(RingSwitches.brightScreen(activity)))
    }

    /** The alarm screen stopped ringing, or was covered or closed. */
    fun ended(incidentId: String?) {
        if (!RingWindowRule.ends(ringingFor, incidentId)) return
        ringingFor = null
        apply(null)
    }

    /** True for a key press the alarm screen swallows. */
    fun swallows(event: KeyEvent): Boolean = RingWindowRule.swallowsKey(
        isVolumeDown = event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN,
        screenRings = ringingFor != null,
        alarmRings = AlarmForegroundService.isRinging,
    )

    private fun apply(brightness: Float?) {
        val window = activity.window ?: return
        runCatching {
            window.attributes = window.attributes.also {
                it.screenBrightness = brightness ?: WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
            }
            if (brightness != null) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }.onFailure { Log.w(TAG, "ring_window_failed error=$it") }
    }

    private companion object {
        const val TAG = "CritAlarmAlarm"
    }
}

/** The rules [RingWindow] follows, apart from Android so they are tested on the JVM. */
object RingWindowRule {
    /** A window's own brightness at full. */
    const val FULL = 1f

    /** The window brightness while ringing, or null to leave the phone's own. */
    fun brightness(switchOn: Boolean): Float? = if (switchOn) FULL else null

    /**
     * Whether letting go of [released] ends the ring on this window. Null
     * means whatever it shows. A release for another incident changes
     * nothing.
     */
    fun ends(ringingFor: String?, released: String?): Boolean =
        ringingFor != null && (released == null || released == ringingFor)

    /** Volume down is swallowed only while the alarm screen rings and the sound plays. */
    fun swallowsKey(isVolumeDown: Boolean, screenRings: Boolean, alarmRings: Boolean): Boolean =
        isVolumeDown && screenRings && alarmRings
}

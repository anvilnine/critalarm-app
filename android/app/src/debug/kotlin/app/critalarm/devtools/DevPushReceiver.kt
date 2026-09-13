package app.critalarm.devtools

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import app.critalarm.push.PushRouter

/**
 * Feeds a made-up FCM data message into the real routing code, so the four
 * channels can be checked on a device without a live relay.
 *
 * Debug builds only: this file lives in `src/debug` and is not compiled into a
 * release APK. Send one with:
 *
 * ```
 * adb shell am broadcast -a app.critalarm.debug.PUSH \
 *   -n app.critalarm/app.critalarm.devtools.DevPushReceiver \
 *   --es incident_id inc_1 --es server https://alerts.example.com \
 *   --es kind open --es priority 5
 * ```
 */
class DevPushReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION) return
        val extras = intent.extras ?: return
        val data = buildMap {
            for (key in extras.keySet()) {
                val value = extras.getString(key) ?: continue
                put(key, value)
            }
        }
        Log.i(TAG, "dev_push_injected data=$data")
        PushRouter(context.applicationContext).route(data)
    }

    companion object {
        const val ACTION = "app.critalarm.debug.PUSH"
        private const val TAG = "CritAlarmDev"
    }
}

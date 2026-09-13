package app.critalarm.devtools

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Writes the server session the app would have saved after onboarding, so a
 * device can be pointed at a throwaway server without tapping through the
 * connect screen.
 *
 * Debug builds only. The value is the same `base|relay|mode|credential` string
 * `SharedPrefsApiSessionStore` writes.
 *
 * ```
 * adb shell am broadcast -a app.critalarm.debug.SESSION \
 *   -n app.critalarm/app.critalarm.devtools.DevSessionReceiver \
 *   --es session "http://10.0.0.5:8787|http://10.0.0.5:8787|selfhosted|ad_devtoken"
 * ```
 */
class DevSessionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION) return
        val session = intent.getStringExtra("session") ?: return
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putString("flutter.api_session", session)
            .apply()
        Log.i(TAG, "dev_session_written session=$session")
    }

    companion object {
        const val ACTION = "app.critalarm.debug.SESSION"
        private const val TAG = "CritAlarmDev"
    }
}

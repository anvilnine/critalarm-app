package app.critalarm.devtools

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import app.critalarm.actions.IncidentActionReceiver

/**
 * Presses the Stop or Acknowledge button for you.
 *
 * `IncidentActionReceiver` is not exported, so `adb shell am broadcast` cannot
 * reach it. This receiver can: it runs inside the app, so the broadcast it
 * sends is a local one.
 *
 * Debug builds only.
 *
 * ```
 * adb shell am broadcast -a app.critalarm.debug.ACTION \
 *   -n app.critalarm/app.critalarm.devtools.DevActionReceiver \
 *   --es trigger stop --es incident_id inc_1 --es server http://192.168.8.244:8787
 * ```
 */
class DevActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION) return
        val incidentId = intent.getStringExtra("incident_id") ?: return
        val server = intent.getStringExtra("server") ?: return
        val forwarded = when (intent.getStringExtra("trigger")) {
            "stop" -> IncidentActionReceiver.ACTION_STOP
            "acknowledge" -> IncidentActionReceiver.ACTION_ACKNOWLEDGE
            else -> return
        }
        Log.i(TAG, "dev_action_forwarded trigger=$forwarded incident_id=$incidentId")
        context.sendBroadcast(
            Intent(context, IncidentActionReceiver::class.java).apply {
                action = forwarded
                putExtra(IncidentActionReceiver.EXTRA_INCIDENT_ID, incidentId)
                putExtra(IncidentActionReceiver.EXTRA_SERVER, server)
            },
        )
    }

    companion object {
        const val ACTION = "app.critalarm.debug.ACTION"
        private const val TAG = "CritAlarmDev"
    }
}

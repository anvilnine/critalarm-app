package app.critalarm.alarm

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.util.Log
import app.critalarm.notifications.AlarmNotificationFactory
import app.critalarm.storage.IncidentDeliveryStore
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The Android half of Dart's AlarmHost.
 *
 * Android has no AlarmKit. A critical page rings from [AlarmForegroundService],
 * started by the push router, and until this class existed nothing in Dart could
 * reach it. Acknowledging wrote "acked" to the server and left the phone
 * ringing, because the channel was never registered here and Dart quietly turned
 * the MissingPluginException into a false.
 *
 * Only the calls Android can honour are answered. The rest fall through to
 * notImplemented, which Dart already reads as "this platform does not do that".
 */
class AlarmChannel(private val context: Context) {

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // There is no permission to ask for. Saying "unsupported" rather
            // than "denied" is what lets the critical toggle stay editable.
            "authorizationStatus", "requestAuthorization" -> result.success(UNSUPPORTED)

            // Stop the sound, whichever incident it belongs to. Android runs
            // one alarm service, so stopping it is the whole job.
            "stopRinging" -> {
                result.success(stopService("dart_stop_ringing"))
            }

            "cancelAlarm" -> {
                val incidentId = call.argument<String>("incident_id")
                if (incidentId.isNullOrEmpty()) {
                    result.success(false)
                    return
                }
                result.success(stop(incidentId))
            }

            // Android puts up a plain notification, not a Live Activity, so
            // there is never a card of ours on screen to report or end.
            "showingIncidentIds" -> result.success(emptyList<String>())
            "endActivity" -> {
                val incidentId = call.argument<String>("incident_id")
                if (!incidentId.isNullOrEmpty()) stop(incidentId)
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    /** Stops the ring and clears the notification that came with it. */
    private fun stop(incidentId: String): Boolean = try {
        IncidentDeliveryStore(context).markAcknowledged(incidentId)
        context.getSystemService(NotificationManager::class.java)
            ?.cancel(AlarmNotificationFactory.notificationId(incidentId))
        stopService("incident_id=$incidentId")
    } catch (e: Exception) {
        Log.w(TAG, "alarm_stop_failed incident_id=$incidentId error=${e.message}")
        false
    }

    private fun stopService(reason: String): Boolean = try {
        context.stopService(Intent(context, AlarmForegroundService::class.java))
        Log.i(TAG, "alarm_service_stopped source=dart $reason")
        true
    } catch (e: Exception) {
        Log.w(TAG, "alarm_stop_failed reason=$reason error=${e.message}")
        false
    }

    companion object {
        const val NAME = "app.critalarm/alarm"
        private const val UNSUPPORTED = "unsupported"
        private const val TAG = "CritAlarmAlarm"
    }
}

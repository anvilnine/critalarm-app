package app.critalarm.actions

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import app.critalarm.alarm.AlarmForegroundService
import app.critalarm.storage.AckQueueStore
import app.critalarm.storage.IncidentDeliveryStore
import app.critalarm.storage.NativeConnectionStore
import app.critalarm.notifications.StatusNotificationFactory
import android.app.NotificationManager
import java.net.HttpURLConnection
import java.net.URI
import java.net.URL

class IncidentActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val incidentId = intent.getStringExtra(EXTRA_INCIDENT_ID)?.takeIf(String::isNotEmpty) ?: return
        val trigger = when (intent.action) {
            ACTION_STOP -> "stop"
            ACTION_ACKNOWLEDGE -> "acknowledge"
            else -> return
        }
        val route = IncidentActionRouter.fromTrigger(trigger, incidentId) ?: return
        if (route.action == IncidentAction.ACK) {
            IncidentDeliveryStore(context).markAcknowledged(incidentId)
            context.stopService(Intent(context, AlarmForegroundService::class.java))
            Log.i(TAG, "alarm_service_stopped incident_id=$incidentId")
        }
        val queue = AckQueueStore(context)
        val pending = goAsync()
        Thread {
            try {
                val server = intent.getStringExtra(EXTRA_SERVER)?.let(::URI)
                val credentials = server?.let { NativeConnectionStore(context).credentialsFor(it) }
                if (credentials == null) {
                    Log.w(TAG, "${route.action.wireValue}_request_missing_session incident_id=$incidentId")
                    queue.enqueue(route.action.wireValue, incidentId)
                    Log.i(TAG, "ack_queued action=${route.action.wireValue} incident_id=$incidentId pending=${queue.pendingCount()}")
                    return@Thread
                }
                Log.i(TAG, "${route.action.wireValue}_request incident_id=$incidentId")
                val connection = URL(credentials.first.toString().trimEnd('/') + route.path).openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Authorization", "Bearer ${credentials.second}")
                connection.connectTimeout = 5_000
                connection.readTimeout = 5_000
                val status = connection.responseCode
                Log.i(TAG, "${route.action.wireValue}_response_$status incident_id=$incidentId")
                // 409 means the incident already moved on, so there is nothing
                // left to send. Anything else outside 2xx is worth a retry.
                if (status !in 200..299 && status != 409) {
                    queue.enqueue(route.action.wireValue, incidentId)
                    Log.i(TAG, "ack_queued action=${route.action.wireValue} incident_id=$incidentId pending=${queue.pendingCount()}")
                }
                if (route.action == IncidentAction.CLOSE && status in 200..299) {
                    context.getSystemService(NotificationManager::class.java)
                        .cancel(StatusNotificationFactory.notificationId(incidentId))
                    Log.i(TAG, "status_notification_cancelled incident_id=$incidentId")
                }
                connection.disconnect()
            } catch (_: Exception) {
                // Offline. The alarm is already stopped; the send waits for the
                // network and goes out from the Dart queue on the next launch.
                Log.w(TAG, "${route.action.wireValue}_request_failed incident_id=$incidentId")
                queue.enqueue(route.action.wireValue, incidentId)
                Log.i(TAG, "ack_queued action=${route.action.wireValue} incident_id=$incidentId pending=${queue.pendingCount()}")
            } finally {
                pending.finish()
            }
        }.start()
    }

    companion object {
        const val ACTION_STOP = "app.critalarm.action.STOP"
        const val ACTION_ACKNOWLEDGE = "app.critalarm.action.ACKNOWLEDGE"
        const val EXTRA_INCIDENT_ID = "incident_id"
        const val EXTRA_SERVER = "server"
        private const val TAG = "CritAlarmAction"
    }
}

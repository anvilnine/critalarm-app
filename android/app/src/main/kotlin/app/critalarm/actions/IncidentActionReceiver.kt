package app.critalarm.actions

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import app.critalarm.alarm.AlarmForegroundService
import app.critalarm.storage.AckQueueStore
import app.critalarm.storage.IncidentDeliveryStore
import app.critalarm.storage.NativeConnectionStore
import app.critalarm.notifications.AlarmNotificationFactory
import app.critalarm.notifications.IncidentCardState
import app.critalarm.notifications.StatusNotificationFactory
import app.critalarm.push.FcmIncidentPayload
import app.critalarm.push.IncidentContent
import app.critalarm.push.IncidentContentFetcher
import app.critalarm.push.IncidentPushKind
import app.critalarm.push.SingleCardRule
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
        val server = intent.getStringExtra(EXTRA_SERVER)
            ?.let { runCatching { URI(it) }.getOrNull() }
        // The desk timer starts when the user stops the alarm, so the refresh
        // that follows the fetch counts from here too and not from whenever
        // the network answered.
        val ackedAtMillis = System.currentTimeMillis()
        if (route.action == IncidentAction.ACK) {
            val deliveries = IncidentDeliveryStore(context)
            deliveries.markAcknowledged(incidentId)
            context.stopService(Intent(context, AlarmForegroundService::class.java))
            Log.i(TAG, "alarm_service_stopped incident_id=$incidentId")
            // The alarm has stopped, so the card changes hands. SingleCardRule
            // gives one incident one card, and a promoted alarm card left
            // beside a promoted status card puts two chips in the status bar.
            val ringing = !deliveries.isAcknowledged(incidentId)
            if (server != null && SingleCardRule.showsStatusCard(ringing)) {
                context.getSystemService(NotificationManager::class.java)
                    .cancel(incidentId, AlarmNotificationFactory.notificationId(incidentId))
                postStatusCard(context, incidentId, server, null, ackedAtMillis)
                Log.i(TAG, "status_notification_posted incident_id=$incidentId")
            }
        }
        val queue = AckQueueStore(context)
        val pending = goAsync()
        Thread {
            try {
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
                    // The same tag the card was posted under. A cancel without
                    // it leaves the card on screen.
                    context.getSystemService(NotificationManager::class.java)
                        .cancel(incidentId, StatusNotificationFactory.notificationId(incidentId))
                    Log.i(TAG, "status_notification_cancelled incident_id=$incidentId")
                }
                connection.disconnect()
                if (route.action == IncidentAction.ACK && server != null) {
                    // The card went up with the fallback text because a push
                    // carries no topic and the alarm could not wait for a
                    // fetch. This is the same enrichment PushRouter does for
                    // the alarm card, and the topic it brings back is what
                    // gives the desk timer its countdown.
                    IncidentContentFetcher.fetch(context, server, incidentId)?.let {
                        postStatusCard(context, incidentId, server, it, ackedAtMillis)
                        Log.i(TAG, "status_content_resolved incident_id=$incidentId")
                    }
                }
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

    /**
     * The acked card for one incident, posted under the same tag the push path
     * uses so a later post replaces it instead of stacking a second one.
     *
     * [content] is null for the first post, right after the alarm stops, and
     * the resolved content once the fetch answers.
     */
    private fun postStatusCard(
        context: Context,
        incidentId: String,
        server: URI,
        content: IncidentContent?,
        ackedAtMillis: Long,
    ) {
        // Only the incident id and the server are read off this. A stopped
        // alarm was a priority 5 incident push, which is what the two values
        // below say.
        val payload = FcmIncidentPayload(
            incidentId = incidentId,
            server = server,
            kind = IncidentPushKind.OPEN,
            priority = 5,
            title = null,
            body = null,
        )
        context.getSystemService(NotificationManager::class.java).notify(
            incidentId,
            StatusNotificationFactory.notificationId(incidentId),
            StatusNotificationFactory.create(
                context = context,
                payload = payload,
                content = content ?: IncidentContentFetcher.fallback(payload),
                state = IncidentCardState.ACKED,
                openedAtMillis = ackedAtMillis,
            ),
        )
    }

    companion object {
        const val ACTION_STOP = "app.critalarm.action.STOP"
        const val ACTION_ACKNOWLEDGE = "app.critalarm.action.ACKNOWLEDGE"
        const val EXTRA_INCIDENT_ID = "incident_id"
        const val EXTRA_SERVER = "server"
        private const val TAG = "CritAlarmAction"
    }
}

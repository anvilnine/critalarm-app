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
import app.critalarm.push.LateContentRule
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
        // The text the card being replaced was already showing. Without it the
        // status card falls back to "Critical incident" and stays there for as
        // long as the enrichment fails.
        val title = intent.getStringExtra(EXTRA_TITLE)?.takeIf(String::isNotEmpty)
        val body = intent.getStringExtra(EXTRA_BODY)?.takeIf(String::isNotEmpty)
        // False on the onboarding demo alarm, which is scheduled locally and
        // has no incident behind it. It comes from the alarm that posted this
        // button, so nothing here has to recognise an id.
        val handOver = intent.getBooleanExtra(EXTRA_HAND_OVER, true)
        // The desk timer starts when the user stops the alarm, so the refresh
        // that follows the fetch counts from here too and not from whenever
        // the network answered.
        val ackedAtMillis = System.currentTimeMillis()
        val deliveries = IncidentDeliveryStore(context)
        val manager = context.getSystemService(NotificationManager::class.java)
        if (route.action == IncidentAction.ACK) {
            // A demo alarm is over the moment it is stopped. Marking it closed
            // rather than acknowledged is what keeps it out of the list launch
            // reconcile walks.
            if (handOver) {
                deliveries.markAcknowledged(incidentId, ackedAtMillis)
            } else {
                deliveries.markClosed(incidentId, ackedAtMillis)
            }
            context.stopService(Intent(context, AlarmForegroundService::class.java))
            Log.i(TAG, "alarm_service_stopped incident_id=$incidentId")
            // The alarm card goes whether or not a status card can take its
            // place. A promoted RINGING card left on a stopped alarm is worse
            // than a gap.
            manager.cancel(AlarmNotificationFactory.notificationId(incidentId))
            // The alarm has stopped, so the card changes hands. SingleCardRule
            // gives one incident one card, and a promoted alarm card left
            // beside a promoted status card puts two chips in the status bar.
            val ringing = !deliveries.isAcknowledged(incidentId)
            val handsOverToStatusCard =
                SingleCardRule.showsStatusCard(ringing, handsOver = handOver)
            if (!handsOverToStatusCard) {
                // Nothing takes the alarm card's place, so any status card
                // from an earlier round goes too.
                manager.cancel(StatusNotificationFactory.notificationId(incidentId))
            }
            if (server != null && handsOverToStatusCard) {
                postStatusCard(
                    context = context,
                    incidentId = incidentId,
                    server = server,
                    title = title,
                    body = body,
                    content = null,
                    ackedAtMillis = ackedAtMillis,
                    deskTimerEndMillis = deliveries.deskTimerFiresAtMillis(incidentId),
                )
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
                // 409 means the incident already moved on and 404 or 410 that
                // it is not there at all, so neither has anything left to
                // send. Anything else outside 2xx is worth a retry.
                if (!ActionResponseRule.isSettled(status)) {
                    queue.enqueue(route.action.wireValue, incidentId)
                    Log.i(TAG, "ack_queued action=${route.action.wireValue} incident_id=$incidentId pending=${queue.pendingCount()}")
                }
                if (route.action == IncidentAction.ACK && status in 200..299) {
                    rememberDeskTimer(connection, deliveries, incidentId)
                }
                if (route.action == IncidentAction.CLOSE && ActionResponseRule.endsTheIncident(status)) {
                    // Written before the cancel, because a fetch started by the
                    // Stop that came before this is still out and will try to
                    // put the card back when it lands.
                    deliveries.markClosed(incidentId)
                    manager.cancel(StatusNotificationFactory.notificationId(incidentId))
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
                // The broadcast window closes here, before the enrichment runs.
                // A manifest receiver fired from a notification action has
                // roughly ten seconds, and the POST above can spend ten of them
                // on its own, so holding the broadcast open for a second
                // network call risks a timeout or an ANR.
                pending.finish()
            }
            // Outside the try, so a failed ack still refreshes the text. The
            // ack is what the server needs; the card is what the user reads.
            if (route.action == IncidentAction.ACK && server != null && handOver) {
                enrichStatusCard(context, deliveries, incidentId, server, title, body, ackedAtMillis)
            }
        }.start()
    }

    /**
     * Reads `desk_timer_fires_at` off the ack response (api.md §3.2) so the bar
     * counts to the instant the server picked, not to a fresh full timer the
     * device guessed. A 409 carries no such field and leaves the cached value
     * in place.
     */
    private fun rememberDeskTimer(
        connection: HttpURLConnection,
        deliveries: IncidentDeliveryStore,
        incidentId: String,
    ) {
        val text = runCatching {
            connection.inputStream.bufferedReader().use { it.readText() }
        }.getOrNull() ?: return
        val firesAt = IncidentContentFetcher.parseDeskTimerFiresAt(text) ?: return
        deliveries.rememberDeskTimerFiresAt(incidentId, firesAt)
        Log.i(TAG, "desk_timer_resolved incident_id=$incidentId fires_at=$firesAt")
    }

    /**
     * Replaces the seeded text on the status card once
     * `GET /v1/incidents/{id}` answers, and brings back the topic, which is
     * what gives the bar its length.
     *
     * The two guards are the point of the re-read. The fetch can be out for
     * seconds, and in that time the user can press Done, or a reopen can put
     * the alarm back up. Posting the acked card either way leaves a card on an
     * incident that no longer has one.
     */
    private fun enrichStatusCard(
        context: Context,
        deliveries: IncidentDeliveryStore,
        incidentId: String,
        server: URI,
        title: String?,
        body: String?,
        ackedAtMillis: Long,
    ) {
        val content = IncidentContentFetcher.fetch(
            context = context,
            server = server,
            incidentId = incidentId,
            connectTimeoutMs = IncidentContentFetcher.ACTION_CONNECT_TIMEOUT_MS,
            readTimeoutMs = IncidentContentFetcher.ACTION_READ_TIMEOUT_MS,
        ) ?: return
        val destination = LateContentRule.destinationFor(
            acknowledged = deliveries.isAcknowledged(incidentId),
            closed = deliveries.isClosed(incidentId),
        )
        if (destination != LateContentRule.Destination.STATUS_CARD) {
            Log.i(TAG, "status_content_dropped incident_id=$incidentId destination=$destination")
            return
        }
        postStatusCard(
            context = context,
            incidentId = incidentId,
            server = server,
            title = title,
            body = body,
            content = content,
            ackedAtMillis = ackedAtMillis,
            deskTimerEndMillis = deliveries.deskTimerFiresAtMillis(incidentId),
        )
        Log.i(TAG, "status_content_resolved incident_id=$incidentId")
    }

    companion object {
        const val ACTION_STOP = "app.critalarm.action.STOP"
        const val ACTION_ACKNOWLEDGE = "app.critalarm.action.ACKNOWLEDGE"
        const val EXTRA_INCIDENT_ID = "incident_id"
        const val EXTRA_SERVER = "server"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"

        /**
         * False when the alarm that posted this button leaves no card behind.
         * Set by [AlarmNotificationFactory] from the flag the alarm was
         * scheduled with, so the receiver never has to recognise an id.
         */
        const val EXTRA_HAND_OVER = "hand_over_to_status_card"
        private const val TAG = "CritAlarmAction"

        /**
         * The acked card for one incident.
         *
         * Posted untagged, under the id alone, because
         * [AlarmForegroundService] posts the alarm card with startForeground,
         * which takes no tag. Android keys a notification by tag and id
         * together, so one tagged post and one untagged post of the same id
         * are two cards and two status bar chips.
         *
         * [content] is null for the first post, right after the alarm stops,
         * and the resolved content once the fetch answers. [title] and [body]
         * are what the card being replaced was showing.
         *
         * Shared with AlarmChannel so in-app Stop hands the card over the same
         * way the notification's Stop button does.
         */
        fun postStatusCard(
            context: Context,
            incidentId: String,
            server: URI,
            title: String?,
            body: String?,
            content: IncidentContent?,
            ackedAtMillis: Long,
            deskTimerEndMillis: Long?,
        ) {
            // Only the incident id, the server and the text are read off this.
            // A stopped alarm was a priority 5 incident push, which is what the
            // two values below say.
            val payload = FcmIncidentPayload(
                incidentId = incidentId,
                server = server,
                kind = IncidentPushKind.OPEN,
                priority = 5,
                title = title,
                body = body,
            )
            context.getSystemService(NotificationManager::class.java).notify(
                StatusNotificationFactory.notificationId(incidentId),
                StatusNotificationFactory.create(
                    context = context,
                    payload = payload,
                    content = content ?: IncidentContentFetcher.fallback(payload),
                    state = IncidentCardState.ACKED,
                    ackedAtMillis = ackedAtMillis,
                    deskTimerEndMillis = deskTimerEndMillis,
                ),
            )
        }
    }
}

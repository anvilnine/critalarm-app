package app.critalarm.push

import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import app.critalarm.actions.IncidentActionReceiver
import app.critalarm.alarm.AlarmForegroundService
import app.critalarm.alarm.IncidentRearm
import app.critalarm.notifications.AlarmNotificationFactory
import app.critalarm.notifications.MessageNotificationFactory
import app.critalarm.notifications.NotificationChannels
import app.critalarm.notifications.StatusNotificationFactory
import app.critalarm.storage.IncidentDeliveryStore
import app.critalarm.storage.NativeConnectionStore
import app.critalarm.storage.PushEventLog

/**
 * One card per incident, never two.
 *
 * While the alarm rings it owns the card, and the status card starts once the
 * alarm is gone. iOS has the same rule in
 * ios/Shared/Alarm/IncidentActivityCoordinator.swift, and without it a
 * promoted incident puts two chips in the status bar.
 */
object SingleCardRule {
    fun showsAlarmCard(ringing: Boolean) = ringing

    /**
     * [handsOver] false is an alarm with no incident behind it, which is the
     * onboarding demo. Stopping it leaves no card: an acked card is ongoing,
     * so it cannot be swiped away, and its Done button would close an incident
     * that does not exist.
     */
    fun showsStatusCard(ringing: Boolean, handsOver: Boolean = true) = !ringing && handsOver
}

/**
 * Where a fetch that started seconds ago puts its answer.
 *
 * Both content fetches run up to twenty seconds, and the incident does not hold
 * still for them. Stop lands at 2s and the alarm card is gone; Done lands at 4s
 * and the status card is gone too. Whoever started the fetch has to re-read the
 * state, not trust the one it captured, or a finished incident gets a card back.
 */
object LateContentRule {
    enum class Destination { ALARM_CARD, STATUS_CARD, NOWHERE }

    fun destinationFor(acknowledged: Boolean, closed: Boolean): Destination = when {
        closed -> Destination.NOWHERE
        acknowledged -> Destination.STATUS_CARD
        else -> Destination.ALARM_CARD
    }
}

/**
 * Decides what one push turns into. api.md §5.2 messages are data-only, so the
 * app builds the notification itself and picks the channel from the priority:
 *
 * - priority 5 that opened an incident: the alarm path (foreground service,
 *   full-screen intent, alarm channel).
 * - priority 5 on a topic that is not critical, and priority 4: the high
 *   channel, as a heads-up, with an ACK button when there is an incident.
 * - priority 1-3: the standard channel. api.md §1.7 does not forward these, so
 *   one arriving means the server is ahead of this app; showing it quietly
 *   beats dropping it.
 */
class PushRouter(private val context: Context) {
    private val events = PushEventLog(context)

    fun route(data: Map<String, String>) {
        val payload = FcmIncidentPayload.fromData(data) ?: run {
            Log.w(TAG, "push_dropped reason=unparseable")
            events.record("push_dropped", mapOf("reason" to "unparseable"))
            return
        }
        if (!NativeConnectionStore(context).matchesCanonicalServer(payload.server)) {
            // One server connection per app in v1.
            Log.w(TAG, "push_dropped reason=other_server server=${payload.server}")
            events.record("push_dropped", mapOf("reason" to "other_server"))
            return
        }
        events.record(
            "push_received",
            mapOf("kind" to payload.kind.wireValue, "priority" to payload.priority.toString()),
        )
        Log.i(
            TAG,
            "push_received incident_id=${payload.incidentId} kind=${payload.kind.wireValue} priority=${payload.priority}",
        )

        NotificationChannels.ensureCreated(context)
        // The incident was handled on another device. Never a ring, never a
        // new notification: stop what is going off here and fix the card.
        if (payload.kind.isStateChange) {
            handleStateChange(payload)
            return
        }
        when {
            payload.priority == 5 && payload.isIncident -> handleAlarm(payload)
            payload.priority >= 4 -> handleMessage(payload, NotificationChannels.highChannelId())
            else -> handleMessage(payload, NotificationChannels.standardChannelId())
        }
    }

    /** Which channel a payload belongs on. Kept public for the unit tests. */
    fun channelFor(payload: FcmIncidentPayload): String = when {
        payload.priority == 5 && payload.isIncident -> NotificationChannels.alarmChannelId()
        payload.priority >= 4 -> NotificationChannels.highChannelId()
        else -> NotificationChannels.standardChannelId()
    }

    private fun handleAlarm(payload: FcmIncidentPayload) {
        val incidentId = payload.incidentId ?: return
        val store = IncidentDeliveryStore(context)
        if (payload.kind == IncidentPushKind.REPEAT && store.isAcknowledged(incidentId)) {
            Log.i(TAG, "push_dropped reason=already_acked incident_id=$incidentId")
            events.record("push_dropped", mapOf("reason" to "already_acked"))
            return
        }
        val alreadyActive = store.isActive(incidentId)
        val reopen = payload.kind == IncidentPushKind.REOPEN
        store.activate(incidentId, reopen = reopen)
        // Written before anything is posted, because a Stop can land seconds
        // later and the re-arm reads this with no network call. A reopen moves
        // opened_at, so the server sends a new value and it lands here too.
        payload.ringUntilMillis?.let { store.rememberRingUntil(incidentId, it) }

        val manager = context.getSystemService(NotificationManager::class.java)
        if (!alreadyActive || reopen) {
            // The alarm is ringing, so SingleCardRule gives it the card on its
            // own. A reopen arrives on an incident the user already acked, and
            // that ack left a status card up, so the handover runs in this
            // direction too. The status card starts again when the user stops
            // the alarm, in IncidentActionReceiver.
            if (!SingleCardRule.showsStatusCard(ringing = true)) {
                manager.cancel(StatusNotificationFactory.notificationId(incidentId))
            }
            // Post first, resolve the text after. FCM cuts an app's
            // high-priority quota when a high-priority message does not show a
            // notification quickly, and an alarm that waits ten seconds for a
            // fetch is an alarm that arrives late.
            val fallback = IncidentContentFetcher.fallback(payload)
            // Untagged, under the id alone. AlarmForegroundService posts this
            // same id with startForeground, which takes no tag, and Android
            // keys a notification by tag and id together. A tag here would
            // make the two posts two cards and two status bar chips.
            manager.notify(
                AlarmNotificationFactory.notificationId(incidentId),
                AlarmNotificationFactory.create(context, payload, fallback),
            )
            events.record("alarm_fired", mapOf("incident_id" to incidentId))
            Log.i(TAG, "alarm_notification_posted channel=${NotificationChannels.alarmChannelId()} incident_id=$incidentId kind=${payload.kind.wireValue}")
            if (payload.needsContentFetch) enrichLater(payload)
        }
        try {
            ContextCompat.startForegroundService(context, AlarmForegroundService.startIntent(context, payload))
            Log.i(TAG, "alarm_service_start_requested incident_id=$incidentId kind=${payload.kind.wireValue}")
        } catch (error: RuntimeException) {
            if (Build.VERSION.SDK_INT < 31 || error.javaClass.simpleName != "ForegroundServiceStartNotAllowedException") throw error
            Log.w(TAG, "alarm_service_start_rejected incident_id=$incidentId")
        }
    }

    /**
     * `ack`, `close` or `expire` (api.md §5.2). The incident was answered
     * somewhere else, so this device stops ringing for it, drops the ring it
     * had set for itself, and either hands the card to the acked state or
     * takes it down.
     */
    private fun handleStateChange(payload: FcmIncidentPayload) {
        val incidentId = payload.incidentId ?: return
        val store = IncidentDeliveryStore(context)
        val manager = context.getSystemService(NotificationManager::class.java)

        AlarmForegroundService.stopIncident(context, incidentId)
        IncidentRearm.cancel(context, incidentId)
        manager.cancel(AlarmNotificationFactory.notificationId(incidentId))
        manager.cancel(MessageNotificationFactory.notificationId(incidentId))

        when (StateKindRule.cardFor(payload.kind)) {
            StateKindRule.Card.ACKED -> {
                val ackedAt = store.acknowledgedAtMillis(incidentId) ?: System.currentTimeMillis()
                store.markAcknowledged(incidentId, ackedAt)
                IncidentActionReceiver.postStatusCard(
                    context = context,
                    incidentId = incidentId,
                    server = payload.server,
                    title = null,
                    body = null,
                    content = null,
                    ackedAtMillis = ackedAt,
                    deskTimerEndMillis = store.deskTimerFiresAtMillis(incidentId),
                )
            }
            else -> {
                store.markClosed(incidentId)
                manager.cancel(StatusNotificationFactory.notificationId(incidentId))
            }
        }
        events.record("push_state_change", mapOf("kind" to payload.kind.wireValue))
        Log.i(TAG, "incident_state_applied kind=${payload.kind.wireValue} incident_id=$incidentId")
    }

    private fun handleMessage(payload: FcmIncidentPayload, channelId: String) {
        val withAck = channelId == NotificationChannels.highChannelId() && payload.incidentId != null
        // Post the fallback now and fill in the real text when the fetch
        // answers. The fetch cannot run here: this is the main thread when the
        // push arrives while the app is in front, and a network call on it
        // throws NetworkOnMainThreadException. Even off the main thread,
        // holding a heads-up for up to ten seconds is worse than showing it
        // twice.
        postMessage(payload, IncidentContentFetcher.fallback(payload), channelId, withAck)
        if (payload.needsContentFetch) enrichMessageLater(payload, channelId, withAck)
    }

    private fun postMessage(
        payload: FcmIncidentPayload,
        content: IncidentContent,
        channelId: String,
        withAck: Boolean,
    ) {
        val notification = MessageNotificationFactory.create(
            context = context,
            payload = payload,
            content = content,
            channelId = channelId,
            withAck = withAck,
        )
        context.getSystemService(NotificationManager::class.java)
            .notify(MessageNotificationFactory.notificationId(payload), notification)
        Log.i(
            TAG,
            "message_notification_posted channel=$channelId priority=${payload.priority} " +
                "incident_id=${payload.incidentId} ack=$withAck",
        )
    }

    private fun enrichMessageLater(payload: FcmIncidentPayload, channelId: String, withAck: Boolean) {
        val incidentId = payload.incidentId ?: return
        Thread {
            val content = IncidentContentFetcher.fetch(context, payload.server, incidentId) ?: run {
                Log.i(TAG, "message_content_fallback incident_id=$incidentId")
                return@Thread
            }
            postMessage(payload, content, channelId, withAck)
            Log.i(TAG, "message_content_resolved incident_id=$incidentId")
        }.start()
    }

    /** Replaces the fallback text once `GET /v1/incidents/{id}` answers. */
    private fun enrichLater(payload: FcmIncidentPayload) {
        val incidentId = payload.incidentId ?: return
        Thread {
            val content = IncidentContentFetcher.fetch(context, payload.server, incidentId) ?: run {
                Log.i(TAG, "alarm_content_fallback incident_id=$incidentId")
                return@Thread
            }
            // The push carries no topic (api.md §5.2), and the re-arm needs one
            // to read the repeat interval and the critical switch.
            content.topic?.let { IncidentDeliveryStore(context).rememberTopic(incidentId, it) }
            // Re-read rather than trust the state from before the network call.
            // The fetch waits up to ten seconds for connect and ten for read,
            // and the user can press Stop inside the first one. Re-posting the
            // alarm card then would put a RINGING card back on an incident
            // they already stopped.
            val store = IncidentDeliveryStore(context)
            val manager = context.getSystemService(NotificationManager::class.java)
            when (
                LateContentRule.destinationFor(
                    acknowledged = store.isAcknowledged(incidentId),
                    closed = store.isClosed(incidentId),
                )
            ) {
                LateContentRule.Destination.NOWHERE ->
                    Log.i(TAG, "alarm_content_dropped incident_id=$incidentId")

                // The alarm is gone, so the resolved text belongs to the card
                // that took its place.
                LateContentRule.Destination.STATUS_CARD -> {
                    IncidentActionReceiver.postStatusCard(
                        context = context,
                        incidentId = incidentId,
                        server = payload.server,
                        title = payload.title,
                        body = payload.body,
                        content = content,
                        ackedAtMillis = store.acknowledgedAtMillis(incidentId)
                            ?: System.currentTimeMillis(),
                        deskTimerEndMillis = store.deskTimerFiresAtMillis(incidentId),
                    )
                    Log.i(TAG, "status_content_resolved incident_id=$incidentId")
                }

                // Untagged, for the same reason the first post is.
                LateContentRule.Destination.ALARM_CARD -> {
                    manager.notify(
                        AlarmNotificationFactory.notificationId(incidentId),
                        AlarmNotificationFactory.create(context, payload, content),
                    )
                    Log.i(TAG, "alarm_content_resolved incident_id=$incidentId")
                }
            }
        }.start()
    }

    companion object {
        private const val TAG = "CritAlarmFcm"
    }
}

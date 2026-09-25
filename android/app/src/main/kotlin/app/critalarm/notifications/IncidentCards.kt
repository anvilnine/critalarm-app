package app.critalarm.notifications

import android.app.NotificationManager
import android.content.Context
import android.util.Log
import app.critalarm.push.FcmIncidentPayload
import app.critalarm.push.IncidentContent
import app.critalarm.push.IncidentContentFetcher
import app.critalarm.push.IncidentPushKind
import app.critalarm.storage.IncidentDeliveryStore
import app.critalarm.storage.NativeConnectionStore
import app.critalarm.storage.TopicTimerStore
import java.net.URI

/**
 * The one place a card for an incident is shown or taken down.
 *
 * Every path that changes an incident's phone state calls [show] with that
 * state, and [IncidentCardRule] decides what the card becomes. The status card
 * is keyed on the incident id alone, so one state replaces another in place
 * with no flash. The ringing card keeps its own id because the foreground
 * service owns it.
 */
object IncidentCards {
    private const val TAG = "CritAlarmCard"

    fun show(
        context: Context,
        incidentId: String,
        state: IncidentPhoneState,
        server: URI? = null,
        title: String? = null,
        body: String? = null,
        content: IncidentContent? = null,
        postRinging: () -> Unit = {},
    ) {
        val deliveries = IncidentDeliveryStore(context)
        val now = System.currentTimeMillis()
        val resolved = when (state) {
            is IncidentPhoneState.Acked -> IncidentPhoneState.Acked(
                ackedAtMillis = state.ackedAtMillis,
                deskTimerEndMillis = state.deskTimerEndMillis
                    ?: deliveries.deskTimerFiresAtMillis(incidentId),
                deskTimerSeconds = state.deskTimerSeconds
                    ?: deliveries.topicOf(incidentId)
                        ?.let { TopicTimerStore(context).timersFor(it)?.deskTimerS },
            )
            else -> state
        }
        val decision = IncidentCardRule.decide(resolved, now)
        val manager = context.getSystemService(NotificationManager::class.java)
        val resolvedServer = server ?: NativeConnectionStore(context).canonicalServer()

        when (decision.card) {
            IncidentCardRule.Card.RINGING -> {
                // Post the ringing card first, then clear the status card, so a
                // reopen or repeat that lands on an acked or silenced card never
                // shows a gap. The lambda posts the alarm notification, which
                // lives outside this object because the foreground service owns
                // that id.
                postRinging()
                manager.cancel(StatusNotificationFactory.notificationId(incidentId))
                Log.i(TAG, "card_shown incident_id=$incidentId state=ringing until=none")
            }
            IncidentCardRule.Card.SILENCED -> {
                val nextRingAt = decision.countdownEndMillis
                if (resolvedServer == null || nextRingAt == null) {
                    manager.cancel(StatusNotificationFactory.notificationId(incidentId))
                    Log.i(TAG, "card_cleared incident_id=$incidentId reason=${if (resolvedServer == null) "no_server" else "rearm_refused"}")
                    return
                }
                val seconds = ((nextRingAt - now) / 1000L).toInt().coerceAtLeast(1)
                postStatus(
                    context, incidentId, resolvedServer, title, body, content,
                    IncidentCardState.OPEN, now, nextRingAt, seconds,
                )
                Log.i(TAG, "card_shown incident_id=$incidentId state=silenced until=$nextRingAt")
            }
            IncidentCardRule.Card.ACKED -> {
                if (resolvedServer == null) {
                    manager.cancel(StatusNotificationFactory.notificationId(incidentId))
                    Log.i(TAG, "card_cleared incident_id=$incidentId reason=no_server")
                    return
                }
                val acked = resolved as IncidentPhoneState.Acked
                // Only an ack made on this phone has a time worth printing. A
                // remote ack stores when its push arrived, which is not when
                // anyone pressed anything.
                val ackTimeKnown = deliveries.locallyAcknowledgedAtMillis(incidentId) != null
                postStatus(
                    context, incidentId, resolvedServer, title, body, content,
                    IncidentCardState.ACKED, acked.ackedAtMillis, decision.countdownEndMillis, null,
                    ackTimeKnown,
                )
                Log.i(TAG, "card_shown incident_id=$incidentId state=acked until=${decision.countdownEndMillis ?: "none"}")
            }
            IncidentCardRule.Card.NONE -> {
                manager.cancel(StatusNotificationFactory.notificationId(incidentId))
                Log.i(TAG, "card_cleared incident_id=$incidentId reason=${clearReasonFor(resolved)}")
            }
        }
    }

    /** Takes the status card down. Safe to call when there is none. */
    fun clear(context: Context, incidentId: String, reason: String) {
        context.getSystemService(NotificationManager::class.java)
            .cancel(StatusNotificationFactory.notificationId(incidentId))
        Log.i(TAG, "card_cleared incident_id=$incidentId reason=$reason")
    }

    private fun postStatus(
        context: Context,
        incidentId: String,
        server: URI,
        title: String?,
        body: String?,
        content: IncidentContent?,
        state: IncidentCardState,
        ackedAtMillis: Long,
        countdownEndMillis: Long?,
        silencedInSeconds: Int?,
        ackTimeKnown: Boolean = true,
    ) {
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
                state = state,
                ackedAtMillis = ackedAtMillis,
                silencedInSeconds = silencedInSeconds,
                countdownEndMillis = countdownEndMillis,
                ackTimeKnown = ackTimeKnown,
            ),
        )
    }

    private fun clearReasonFor(state: IncidentPhoneState): String = when (state) {
        is IncidentPhoneState.Silenced -> "rearm_refused"
        IncidentPhoneState.Closed -> "closed"
        IncidentPhoneState.Expired -> "expired"
        else -> "none"
    }
}

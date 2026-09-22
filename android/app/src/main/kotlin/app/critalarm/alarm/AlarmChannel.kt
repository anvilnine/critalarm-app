package app.critalarm.alarm

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.util.Log
import app.critalarm.actions.IncidentActionReceiver
import app.critalarm.notifications.AlarmNotificationFactory
import app.critalarm.notifications.MessageNotificationFactory
import app.critalarm.notifications.StatusNotificationFactory
import app.critalarm.storage.IncidentDeliveryStore
import app.critalarm.storage.NativeConnectionStore
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

            // Onboarding's local test alarm. No push is coming, so the
            // system AlarmManager holds it and starts the service on time,
            // even if the app is backgrounded or killed by then.
            "scheduleAlarm" -> {
                val incidentId = call.argument<String>("incident_id")
                if (incidentId.isNullOrEmpty()) {
                    result.success(false)
                    return
                }
                result.success(
                    ScheduledAlarmReceiver.schedule(
                        context = context,
                        incidentId = incidentId,
                        server = call.argument<String>("server").orEmpty(),
                        title = call.argument<String>("title").orEmpty(),
                        body = call.argument<String>("body"),
                        delaySeconds = call.argument<Int>("delay_seconds") ?: 30,
                        // The onboarding demo says false: inc_demo is not on
                        // the server, so its Stop button must not leave a card
                        // whose Done button has nothing to close. The flag
                        // rides the alarm all the way to that button rather
                        // than being guessed from the id in the receiver.
                        handOverToStatusCard =
                            call.argument<Boolean>("hand_over_to_status_card") ?: true,
                    ),
                )
            }

            // Stop the sound, whichever incident it belongs to. Android runs
            // one alarm service, so stopping it is the whole job.
            "stopRinging" -> {
                result.success(stopService("dart_stop_ringing"))
            }

            "isRinging" -> result.success(AlarmForegroundService.isRinging)

            "debugSnapshot" -> result.success(AlarmDebug.snapshot(context))

            "cancelAllRearms" -> {
                AlarmDebug.cancelAllRearms(context)
                result.success(null)
            }

            "clearContentCache" -> {
                AlarmDebug.clearContentCache(context)
                result.success(null)
            }

            "clearAckedSet" -> {
                AlarmDebug.clearAckedSet(context)
                result.success(null)
            }

            "cancelAlarm" -> {
                val incidentId = call.argument<String>("incident_id")
                if (incidentId.isNullOrEmpty()) {
                    result.success(false)
                    return
                }
                // Dart says which it is. An acknowledge leaves the incident
                // open and hands the card over; a close, or the onboarding
                // demo, ends it and takes both cards down. A missing argument
                // reads as the second, because that is the one that never
                // leaves an ongoing card behind.
                val handOver = call.argument<Boolean>("hand_over_to_status_card") ?: false
                result.success(
                    stop(
                        incidentId = incidentId,
                        handOverToStatusCard = handOver,
                        // What the screen was showing. The card that takes
                        // over is built here, with no network, so without
                        // these it reads "Critical incident" for good.
                        title = call.argument<String>("title"),
                        body = call.argument<String>("body"),
                    ),
                )
            }

            // Silence, from the in-app ringing screen. The incident stays
            // open and the phone sets its own next ring for it; only "I'm up"
            // ends the loop. Answers the seconds until that ring, or null when
            // nothing was set.
            "rearmAlarm" -> {
                val incidentId = call.argument<String>("incident_id")
                if (incidentId.isNullOrEmpty()) {
                    result.success(null)
                    return
                }
                stopService("dart_silence")
                result.success(
                    IncidentRearm.rearm(
                        context = context,
                        incidentId = incidentId,
                        title = call.argument<String>("title"),
                        body = call.argument<String>("body"),
                    ),
                )
            }

            "cancelRearm" -> {
                val incidentId = call.argument<String>("incident_id")
                if (!incidentId.isNullOrEmpty()) IncidentRearm.cancel(context, incidentId)
                result.success(null)
            }

            // The acked cards this device still has up. They are plain
            // notifications rather than Live Activities, so the store is the
            // only record of them, and launch-time reconcile needs the list to
            // take down the ones the server has finished with.
            "showingIncidentIds" -> {
                val deliveries = IncidentDeliveryStore(context)
                // Launch is the one moment a session drops what is past the
                // retention window, and this list is the thing that grows:
                // Dart walks it one server call at a time.
                deliveries.prune()
                result.success(deliveries.acknowledgedIncidentIds())
            }
            "endActivity" -> {
                val incidentId = call.argument<String>("incident_id")
                if (!incidentId.isNullOrEmpty()) stop(incidentId, handOverToStatusCard = false)
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Stops the ring and clears the notification that came with it.
     *
     * Both cancels drop the tag, because [AlarmForegroundService] posts the
     * alarm card with startForeground, which takes no tag, and Android keys a
     * notification by tag and id together.
     *
     * [handOverToStatusCard] comes from Dart, because only the caller knows
     * what it just did. An acknowledge leaves the incident open, so the acked
     * card takes over the way it does when the user presses Stop on the
     * notification. A close, or the onboarding demo alarm, ends it: both cards
     * come down and nothing replaces them.
     *
     * The ring only stops when nothing un-acked is left. See [AlarmStopRule]:
     * there is one service for the whole app, and cancelling an old incident
     * used to silence a live alarm.
     */
    private fun stop(
        incidentId: String,
        handOverToStatusCard: Boolean,
        title: String? = null,
        body: String? = null,
    ): Boolean = try {
        ScheduledAlarmReceiver.cancel(context, incidentId)
        val ackedAtMillis = System.currentTimeMillis()
        val deliveries = IncidentDeliveryStore(context)
        val manager = context.getSystemService(NotificationManager::class.java)
        // This names the incident, and it runs before the cancels. The service
        // holds every un-acked incident and hands over to the next rather than
        // going quiet, so it never silences an alarm the caller did not ask
        // about. It has to go first because Android refuses to cancel the
        // notification that is holding a service in the foreground: the alarm
        // card stops being that notification only once the service has stopped
        // or moved its foreground card to the next incident. See AlarmStopRule.
        val stopped = AlarmForegroundService.stopIncident(context, incidentId)
        manager?.cancel(AlarmNotificationFactory.notificationId(incidentId))
        // Same reason as the notification's Stop button: the heads-up that
        // carried the ACK action is its own id and nothing else takes it down.
        manager?.cancel(MessageNotificationFactory.notificationId(incidentId))
        if (handOverToStatusCard) {
            deliveries.markAcknowledged(incidentId, ackedAtMillis)
            // Without this the user keeps a promoted RINGING card on an
            // incident the app has already acked, and never sees an AWAKE one.
            NativeConnectionStore(context).canonicalServer()?.let { server ->
                IncidentActionReceiver.postStatusCard(
                    context = context,
                    incidentId = incidentId,
                    server = server,
                    title = title,
                    body = body,
                    content = null,
                    ackedAtMillis = ackedAtMillis,
                    deskTimerEndMillis = deliveries.deskTimerFiresAtMillis(incidentId),
                )
            }
        } else {
            deliveries.markClosed(incidentId)
            manager?.cancel(StatusNotificationFactory.notificationId(incidentId))
        }
        stopped
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

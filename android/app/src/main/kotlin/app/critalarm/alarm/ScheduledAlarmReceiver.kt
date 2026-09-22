package app.critalarm.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Rings a local alarm after a delay, with no push involved.
 *
 * Onboarding's "ring my phone in 30 seconds" test needs this: there is no
 * server message coming, so [AlarmForegroundService] has nothing to start it.
 * The alarm is held by the system AlarmManager rather than by a timer in the
 * app, so it still fires if the user backgrounds or kills the app, which is
 * the whole point of the test.
 */
class ScheduledAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val incidentId = intent.getStringExtra(EXTRA_INCIDENT_ID)
        if (incidentId.isNullOrEmpty()) return
        Log.i(TAG, "scheduled_alarm_fired incident_id=$incidentId")

        val service = Intent(context, AlarmForegroundService::class.java).apply {
            putExtra("incident_id", incidentId)
            putExtra("server", intent.getStringExtra(EXTRA_SERVER).orEmpty())
            putExtra("kind", "open")
            putExtra("priority", "5")
            intent.getStringExtra(EXTRA_TITLE)?.let { putExtra("title", it) }
            intent.getStringExtra(EXTRA_BODY)?.let { putExtra("body", it) }
            // Passed on so the Stop button this alarm posts knows whether a
            // card may take the alarm card's place.
            putExtra(
                AlarmForegroundService.EXTRA_HAND_OVER,
                intent.getStringExtra(AlarmForegroundService.EXTRA_HAND_OVER) ?: "true",
            )
        }
        context.startForegroundService(service)
    }

    companion object {
        private const val TAG = "CritAlarmAlarm"
        private const val EXTRA_INCIDENT_ID = "incident_id"
        private const val EXTRA_SERVER = "server"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_BODY = "body"

        /**
         * Puts an alarm [delaySeconds] out for [incidentId], replacing any
         * alarm already set for it. False when the system refuses, which on
         * Android 12 and up means the user has not allowed exact alarms.
         */
        fun schedule(
            context: Context,
            incidentId: String,
            server: String,
            title: String,
            body: String?,
            delaySeconds: Int,
            handOverToStatusCard: Boolean = true,
        ): Boolean {
            return scheduleAt(
                context = context,
                incidentId = incidentId,
                server = server,
                title = title,
                body = body,
                atMillis = System.currentTimeMillis() + delaySeconds * 1000L,
                handOverToStatusCard = handOverToStatusCard,
            )
        }

        /**
         * The same alarm, at an instant rather than a delay. This is what a
         * re-arm uses.
         *
         * `setAlarmClock`, not `setExactAndAllowWhileIdle`. In Doze the latter
         * fires at most about once every nine minutes per app, which is no use
         * for a thirty-second repeat. `setAlarmClock` is exempt from Doze and
         * also lets the receiver start a foreground service from the
         * background, which is how the ring comes back with the app closed.
         * The cost is the alarm icon in the status bar, which for an alarm app
         * is honest.
         */
        fun scheduleAt(
            context: Context,
            incidentId: String,
            server: String,
            title: String,
            body: String?,
            atMillis: Long,
            handOverToStatusCard: Boolean = true,
        ): Boolean {
            val manager = context.getSystemService(AlarmManager::class.java) ?: return false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !manager.canScheduleExactAlarms()) {
                Log.w(TAG, "scheduled_alarm_refused reason=no_exact_alarm_permission")
                return false
            }
            val fire = pendingIntent(context, incidentId, server, title, body, handOverToStatusCard) ?: return false
            return try {
                manager.setAlarmClock(AlarmManager.AlarmClockInfo(atMillis, fire), fire)
                Log.i(TAG, "scheduled_alarm_set incident_id=$incidentId at=$atMillis")
                true
            } catch (e: Exception) {
                Log.w(TAG, "scheduled_alarm_failed incident_id=$incidentId error=${e.message}")
                false
            }
        }

        /** Drops a pending alarm. Safe to call when there is none. */
        fun cancel(context: Context, incidentId: String) {
            val manager = context.getSystemService(AlarmManager::class.java) ?: return
            pendingIntent(context, incidentId, "", "", null)?.let(manager::cancel)
        }

        internal fun isScheduled(context: Context, incidentId: String): Boolean =
            pendingIntent(
                context, incidentId, "", "", null,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            ) != null

        private fun pendingIntent(
            context: Context,
            incidentId: String,
            server: String,
            title: String,
            body: String?,
            handOverToStatusCard: Boolean = true,
            flags: Int = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        ): PendingIntent? {
            val intent = Intent(context, ScheduledAlarmReceiver::class.java).apply {
                putExtra(EXTRA_INCIDENT_ID, incidentId)
                putExtra(EXTRA_SERVER, server)
                putExtra(EXTRA_TITLE, title)
                body?.let { putExtra(EXTRA_BODY, it) }
                putExtra(
                    AlarmForegroundService.EXTRA_HAND_OVER,
                    handOverToStatusCard.toString(),
                )
            }
            return PendingIntent.getBroadcast(
                context,
                incidentId.hashCode(),
                intent,
                flags,
            )
        }
    }
}

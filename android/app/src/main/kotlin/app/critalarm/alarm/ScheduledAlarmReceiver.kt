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
        ): Boolean {
            val manager = context.getSystemService(AlarmManager::class.java) ?: return false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !manager.canScheduleExactAlarms()) {
                Log.w(TAG, "scheduled_alarm_refused reason=no_exact_alarm_permission")
                return false
            }
            val at = System.currentTimeMillis() + delaySeconds * 1000L
            return try {
                manager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    at,
                    pendingIntent(context, incidentId, server, title, body),
                )
                Log.i(
                    TAG,
                    "scheduled_alarm_set incident_id=$incidentId delay_s=$delaySeconds",
                )
                true
            } catch (e: Exception) {
                Log.w(TAG, "scheduled_alarm_failed incident_id=$incidentId error=${e.message}")
                false
            }
        }

        /** Drops a pending alarm. Safe to call when there is none. */
        fun cancel(context: Context, incidentId: String) {
            val manager = context.getSystemService(AlarmManager::class.java) ?: return
            manager.cancel(pendingIntent(context, incidentId, "", "", null))
        }

        private fun pendingIntent(
            context: Context,
            incidentId: String,
            server: String,
            title: String,
            body: String?,
        ): PendingIntent {
            val intent = Intent(context, ScheduledAlarmReceiver::class.java).apply {
                putExtra(EXTRA_INCIDENT_ID, incidentId)
                putExtra(EXTRA_SERVER, server)
                putExtra(EXTRA_TITLE, title)
                body?.let { putExtra(EXTRA_BODY, it) }
            }
            return PendingIntent.getBroadcast(
                context,
                incidentId.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
    }
}

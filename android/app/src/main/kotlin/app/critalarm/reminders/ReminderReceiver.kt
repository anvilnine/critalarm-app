package app.critalarm.reminders

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import app.critalarm.alarm.AlarmForegroundService
import app.critalarm.storage.IncidentDeliveryStore

/** Posts a reminder when its alarm goes off, unless an alarm is under way. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(ReminderAlarms.EXTRA_ID, -1)
        if (ReminderSpecStore.get(context, id) == null) return
        if (holds(context)) {
            // The spec stays on disk, so [releaseHeld] can post it once the
            // last incident is acknowledged.
            ReminderSpecStore.hold(context, id)
            Log.i(TAG, "reminder_held_alarm_focus id=$id")
            return
        }
        post(context, id)
    }

    companion object {
        private const val TAG = "CritAlarmReminders"

        /** Posts every reminder that waited. Called from each ack path. */
        fun releaseHeld(context: Context) {
            val ids = ReminderHoldRule.released(
                heldIds = ReminderSpecStore.heldIds(context),
                alarmRinging = AlarmForegroundService.isRinging,
                activeIncidentIds = IncidentDeliveryStore(context).activeIncidentIds(),
            )
            for (id in ids) {
                ReminderSpecStore.releaseHold(context, id)
                Log.i(TAG, "reminder_released_alarm_focus id=$id")
                post(context, id)
            }
        }

        private fun holds(context: Context) = ReminderHoldRule.holdsReminder(
            alarmRinging = AlarmForegroundService.isRinging,
            activeIncidentIds = IncidentDeliveryStore(context).activeIncidentIds(),
        )

        private fun post(context: Context, id: Int) {
            val spec = ReminderSpecStore.get(context, id) ?: return
            ReminderSpecStore.remove(context, id)
            val manager = context.getSystemService(NotificationManager::class.java) ?: return
            if (!manager.areNotificationsEnabled()) return
            try {
                manager.notify(id, ReminderNotificationFactory.build(context, spec))
            } catch (e: SecurityException) {
                Log.w(TAG, "reminder_post_refused id=$id")
            }
        }
    }
}

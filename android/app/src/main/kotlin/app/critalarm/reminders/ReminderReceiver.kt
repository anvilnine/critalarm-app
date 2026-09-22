package app.critalarm.reminders

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Posts a reminder when its alarm goes off. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(ReminderAlarms.EXTRA_ID, -1)
        val spec = ReminderSpecStore.get(context, id) ?: return
        ReminderSpecStore.remove(context, id)
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (!manager.areNotificationsEnabled()) return
        try {
            manager.notify(id, ReminderNotificationFactory.build(context, spec))
        } catch (e: SecurityException) {
            Log.w("CritAlarmReminders", "reminder_post_refused id=$id")
        }
    }
}

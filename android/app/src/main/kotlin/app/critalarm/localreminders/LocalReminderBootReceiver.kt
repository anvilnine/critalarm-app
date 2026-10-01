package app.critalarm.localreminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * AlarmManager forgets every alarm on a reboot, and a clock or zone change
 * moves what a wall-clock time means. Re-arms whatever is still pending.
 */
class LocalReminderBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            -> LocalReminderAlarms.rearmAll(context)
        }
    }
}

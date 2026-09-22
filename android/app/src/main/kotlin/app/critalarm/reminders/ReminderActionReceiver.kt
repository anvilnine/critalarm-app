package app.critalarm.reminders

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * A reminder button that must not open the app. Today that is only "Not
 * now" on the morning after: it leaves a flag in the preferences file the
 * Flutter side reads, and the next plan pass turns it into a dismissal.
 */
class ReminderActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(ReminderAlarms.EXTRA_ID, -1)
        if (intent.getStringExtra(EXTRA_ACTION) == NOT_NOW) {
            context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(PENDING_PRO_DISMISS_KEY, true)
                .apply()
        }
        if (id >= 0) context.getSystemService(NotificationManager::class.java)?.cancel(id)
    }

    companion object {
        const val EXTRA_ACTION = "reminder_action"
        const val NOT_NOW = "not_now"

        /** shared_preferences' own file and key prefix on Android. */
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val PENDING_PRO_DISMISS_KEY = "flutter.reminder_pending_pro_dismiss"
    }
}

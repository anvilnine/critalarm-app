package app.critalarm.reminders

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Sets and cancels reminder alarms. Inexact on purpose
 * (`setAndAllowWhileIdle`): a reminder landing a few minutes late is fine,
 * and it needs no exact-alarm permission.
 */
object ReminderAlarms {
    private const val TAG = "CritAlarmReminders"
    const val EXTRA_ID = "reminder_id"

    /** A reminder more than this far past due is dropped, not fired late. */
    private const val GRACE_MS = 60_000L

    fun schedule(context: Context, spec: ReminderSpec): Boolean {
        ReminderSpecStore.put(context, spec)
        return arm(context, spec)
    }

    fun cancelPending(context: Context, ids: List<Int>) {
        val manager = context.getSystemService(AlarmManager::class.java) ?: return
        ids.forEach {
            manager.cancel(pendingIntent(context, it))
            ReminderSpecStore.remove(context, it)
        }
    }

    /** After a reboot, an app update or a clock or zone change. */
    fun rearmAll(context: Context) {
        ReminderSpecStore.all(context).forEach { arm(context, it) }
    }

    private fun arm(context: Context, spec: ReminderSpec): Boolean {
        val manager = context.getSystemService(AlarmManager::class.java) ?: return false
        val at = spec.triggerAtMillis()
        if (at < System.currentTimeMillis() - GRACE_MS) {
            // Missed while the phone was off. The next plan pass decides
            // again rather than firing it at a time the rules never allowed.
            ReminderSpecStore.remove(context, spec.id)
            return false
        }
        return try {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pendingIntent(context, spec.id))
            Log.i(TAG, "reminder_set id=${spec.id} kind=${spec.kind}")
            true
        } catch (e: Exception) {
            Log.w(TAG, "reminder_set_failed id=${spec.id} error=${e.message}")
            false
        }
    }

    private fun pendingIntent(context: Context, id: Int): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            id,
            Intent(context, ReminderReceiver::class.java).putExtra(EXTRA_ID, id),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
}

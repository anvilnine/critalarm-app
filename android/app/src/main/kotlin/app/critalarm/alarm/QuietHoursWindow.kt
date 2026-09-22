package app.critalarm.alarm

import android.content.Context
import java.util.Calendar

/**
 * The quiet hours window, read where the alarm code runs with no Flutter
 * engine.
 *
 * Dart owns the values and writes them through shared_preferences, which on
 * Android is the `FlutterSharedPreferences` file with a `flutter.` prefix, the
 * same place [app.critalarm.storage.TopicTimerStore] reads its timers from.
 * `lib/core/alarm/quiet_hours.dart` and `ios/Shared/Alarm/QuietHours.swift`
 * are the other two copies of this rule. Change the three together.
 */
data class QuietHoursWindow(
    val isEnabled: Boolean,
    val startMinutes: Int,
    val endMinutes: Int,
    val criticalRingsThrough: Boolean,
) {
    /**
     * True when [minuteOfDay] falls inside the window.
     *
     * A window that wraps past midnight is the normal case: 22:00 to 07:00 is
     * start 1320 and end 420, and both 23:30 and 02:00 are inside it. Start is
     * inside, end is outside. Start equal to end is an empty window, not a
     * whole day.
     */
    fun contains(minuteOfDay: Int): Boolean {
        if (startMinutes == endMinutes) return false
        return if (startMinutes < endMinutes) {
            minuteOfDay >= startMinutes && minuteOfDay < endMinutes
        } else {
            minuteOfDay >= startMinutes || minuteOfDay < endMinutes
        }
    }

    /** True when the ring for a page of [priority] is held at [minuteOfDay]. */
    fun holdsRing(minuteOfDay: Int, priority: Int): Boolean {
        if (!isEnabled) return false
        if (priority >= CRITICAL_PRIORITY && criticalRingsThrough) return false
        return contains(minuteOfDay)
    }

    companion object {
        /** api.md §1.7: priority 5 on a critical topic is the pager case. */
        const val CRITICAL_PRIORITY = 5

        /**
         * What a device with nothing saved yet runs. The same four values are
         * the fallback in Dart and in Swift.
         */
        val DEFAULTS = QuietHoursWindow(
            isEnabled = false,
            startMinutes = 22 * 60,
            endMinutes = 7 * 60,
            criticalRingsThrough = true,
        )

        fun read(context: Context): QuietHoursWindow {
            val preferences =
                context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            if (!preferences.contains("flutter.quiet_hours_enabled")) return DEFAULTS
            return QuietHoursWindow(
                isEnabled = preferences.getBoolean("flutter.quiet_hours_enabled", false),
                startMinutes = preferences.getLong("flutter.quiet_hours_start_minutes", 0L).toInt(),
                endMinutes = preferences.getLong("flutter.quiet_hours_end_minutes", 0L).toInt(),
                criticalRingsThrough =
                    preferences.getBoolean("flutter.quiet_hours_critical_rings", true),
            )
        }

        /** Minutes from local midnight, right now. */
        fun minuteOfDay(millis: Long): Int {
            val calendar = Calendar.getInstance().apply { timeInMillis = millis }
            return calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
        }
    }
}

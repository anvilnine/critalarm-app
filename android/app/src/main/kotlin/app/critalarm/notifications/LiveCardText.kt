package app.critalarm.notifications

import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Words on the status card. Pure, so a test can pin the zone and the clock.
 *
 * Same words as the acknowledged line on the iOS Live Activity, so both
 * platforms say the same thing about the same ack.
 */
object LiveCardText {
    const val PATTERN_24H = "HH:mm"
    const val PATTERN_12H = "h:mm a"

    /**
     * "Acknowledged at 03:12", in [zone] and [pattern]. A null [ackedAtMillis]
     * means this phone does not know when the ack happened (another device
     * acked it), so the line is "Acknowledged" with no time.
     */
    fun ackedLine(
        ackedAtMillis: Long?,
        zone: ZoneId = ZoneId.systemDefault(),
        pattern: String = PATTERN_24H,
        locale: Locale = Locale.getDefault(),
    ): String {
        if (ackedAtMillis == null) return "Acknowledged"
        val clock = DateTimeFormatter.ofPattern(pattern, locale)
        return "Acknowledged at " + clock.format(Instant.ofEpochMilli(ackedAtMillis).atZone(zone))
    }

    /** The clock pattern for the phone's 12 or 24 hour setting. */
    fun patternFor(is24Hour: Boolean) = if (is24Hour) PATTERN_24H else PATTERN_12H
}

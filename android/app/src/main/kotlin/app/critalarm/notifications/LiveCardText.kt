package app.critalarm.notifications

import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Words on the status card. Pure, so a test can pin the zone.
 *
 * Same words as `LiveCardText.ackedLine` in ios/Shared/Alarm/LiveCardText.swift
 * so both platforms say the same thing about the same ack.
 */
object LiveCardText {
    private val clock = DateTimeFormatter.ofPattern("HH:mm")

    /** "Acknowledged at 03:12", in [zone]. */
    fun ackedLine(ackedAtMillis: Long, zone: ZoneId = ZoneId.systemDefault()): String =
        "Acknowledged at " + clock.format(Instant.ofEpochMilli(ackedAtMillis).atZone(zone))
}

package app.critalarm.widgets

import app.critalarm.notifications.CritAlarmFace
import app.critalarm.notifications.IncidentCardState

/**
 * What the widgets say and how many rows they show. Pure, so the JVM tests
 * can hold it to the same words as `WidgetDisplay` in
 * ios/Shared/Widgets/WidgetSnapshot.swift.
 */
object WidgetRows {
    const val HEADER_DP = 40
    const val ROW_DP = 44
    const val MAX_ROWS = 8

    const val NOT_CONNECTED = "Open Crit Alarm to connect"
    const val NO_TOPICS = "No topics yet"
    const val TOPIC_NOT_FOUND = "Topic not found"
    const val ALL_QUIET = "All quiet"
    const val LOCKED = "Widgets are part of Pro. Tap to see plans."
    const val LOCKED_SHORT = "Pro"

    data class Rows(val rows: List<WidgetTopic>, val more: Int)

    /** How many topic rows a list widget [heightDp] tall has room for. */
    fun rowsThatFit(heightDp: Int): Int = ((heightDp - HEADER_DP) / ROW_DP).coerceIn(1, MAX_ROWS)

    /** The first [limit] topics in display order, and how many are left over. */
    fun rows(snapshot: WidgetSnapshot, limit: Int): Rows {
        val shown = snapshot.topics.take(maxOf(0, limit))
        return Rows(shown, snapshot.topics.size - shown.size)
    }

    /**
     * The rows for a list widget [heightDp] tall. When some topics do not fit,
     * the last slot holds the "+N more" line instead of a row.
     */
    fun listRows(snapshot: WidgetSnapshot, heightDp: Int): Rows {
        val fit = rowsThatFit(heightDp)
        if (snapshot.topics.size <= fit) return rows(snapshot, fit)
        return rows(snapshot, maxOf(1, fit - 1))
    }

    /** The word beside a topic: the same words the live card uses. */
    fun stateWord(incident: WidgetIncident?): String = when (incident?.state) {
        WidgetSnapshot.OPEN -> "Ringing"
        WidgetSnapshot.ACKED -> "Awake"
        else -> "Quiet"
    }

    /** "I'm up" acknowledges a ringing incident, "Done" closes an acked one. */
    fun buttonTitle(incident: WidgetIncident?): String? = when (incident?.state) {
        WidgetSnapshot.OPEN -> "I'm up"
        WidgetSnapshot.ACKED -> "Done"
        else -> null
    }

    fun moreText(more: Int): String = "+$more more"

    /** The list widget's header and the count widget's label. */
    fun countText(openCount: Int): String = if (openCount > 0) "$openCount open" else ALL_QUIET

    fun face(incident: WidgetIncident?): CritAlarmFace = when (incident?.state) {
        WidgetSnapshot.OPEN -> IncidentCardState.OPEN.face
        WidgetSnapshot.ACKED -> IncidentCardState.ACKED.face
        else -> CritAlarmFace.CALM
    }

    /** The count widget's face: the worst state of any topic. */
    fun worstFace(snapshot: WidgetSnapshot): CritAlarmFace = face(
        snapshot.topics.firstOrNull { it.incident?.state == WidgetSnapshot.OPEN }?.incident
            ?: snapshot.topics.firstOrNull { it.incident?.state == WidgetSnapshot.ACKED }?.incident,
    )

    /** When the timer counts from: the open, the same as iOS. Null when unknown. */
    fun openedSeconds(incident: WidgetIncident?): Long? = incident?.openedAt?.takeIf { it > 0L }

    /**
     * The base a RemoteViews Chronometer needs to show the time since
     * [openedAtSeconds]. A chronometer counts up from a base on the
     * elapsedRealtime clock, so the wall clock age is moved onto that clock.
     */
    fun chronometerBase(openedAtSeconds: Long, nowMillis: Long, elapsedRealtimeMillis: Long): Long =
        elapsedRealtimeMillis - (nowMillis - openedAtSeconds * 1000L)
}

package app.critalarm.widgets

import app.critalarm.l10n.NativeText
import app.critalarm.l10n.NativeWords
import app.critalarm.notifications.CritAlarmFace
import app.critalarm.notifications.IncidentCardState

/**
 * What the widgets say and how many rows they show. Pure, so the JVM tests
 * can hold it to the same words as `WidgetDisplay` in
 * ios/Shared/Widgets/WidgetSnapshot.swift.
 *
 * The words come from a [NativeWords]: [NativeWords.English] by default, the
 * language picked in the app when the widget views pass theirs.
 */
object WidgetRows {
    const val HEADER_DP = 40
    const val ROW_DP = 44
    const val MAX_ROWS = 8

    val NOT_CONNECTED: String get() = NativeText.WIDGET_CONNECT.english
    val NO_TOPICS: String get() = NativeText.WIDGET_NO_TOPICS.english
    val TOPIC_NOT_FOUND: String get() = NativeText.WIDGET_TOPIC_NOT_FOUND.english
    val ALL_QUIET: String get() = NativeText.WIDGET_ALL_QUIET.english
    val LOCKED: String get() = NativeText.WIDGET_LOCKED.english
    val LOCKED_SHORT: String get() = NativeText.WIDGET_LOCKED_SHORT.english

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
    fun stateWord(incident: WidgetIncident?, words: NativeWords = NativeWords.English): String =
        words.text(
            when (incident?.state) {
                WidgetSnapshot.OPEN -> NativeText.STATE_RINGING
                WidgetSnapshot.ACKED -> NativeText.STATE_AWAKE
                else -> NativeText.STATE_QUIET
            },
        )

    /** "I'm up" acknowledges a ringing incident, "Done" closes an acked one. */
    fun buttonTitle(incident: WidgetIncident?, words: NativeWords = NativeWords.English): String? =
        when (incident?.state) {
            WidgetSnapshot.OPEN -> words.text(NativeText.ACTION_IM_UP)
            WidgetSnapshot.ACKED -> words.text(NativeText.ACTION_DONE)
            else -> null
        }

    fun moreText(more: Int, words: NativeWords = NativeWords.English): String =
        words.text(NativeText.WIDGET_MORE, "count" to more)

    /** The list widget's header and the count widget's label. */
    fun countText(openCount: Int, words: NativeWords = NativeWords.English): String =
        if (openCount > 0) {
            words.text(NativeText.WIDGET_OPEN_COUNT, "count" to openCount)
        } else {
            words.text(NativeText.WIDGET_ALL_QUIET)
        }

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

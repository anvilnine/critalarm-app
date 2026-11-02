package app.critalarm.notifications

import app.critalarm.l10n.NativeText
import app.critalarm.l10n.NativeWords
import java.util.Locale

/**
 * The palette, copied from lib/design/tokens/colors.dart by way of
 * ios/CritAlarmActivity/FaceView.swift. Keep the three in step.
 */
object CritAlarmPalette {
    const val INK = 0xFF1A140F.toInt()
    const val YELLOW = 0xFFFFC93C.toInt()
    const val HIGH = 0xFFFF8A1F.toInt()
    const val CRIT = 0xFFF5473A.toInt()
    const val COBALT = 0xFF2A3BD8.toInt()
    const val ON_HIGHLIGHT = 0xFFFFFFFF.toInt()
    const val CREAM = 0xFFF7F2E9.toInt()
}

/** The five faces from lib/design/faces/face_state.dart. */
enum class CritAlarmFace(val canvasColor: Int) {
    CALM(CritAlarmPalette.YELLOW),
    WATCHING(CritAlarmPalette.YELLOW),
    WORRIED(CritAlarmPalette.HIGH),
    ALARMED(CritAlarmPalette.CRIT),
    ACKED(CritAlarmPalette.COBALT);

    /**
     * The head is brand yellow in every state. [canvasColor] is for the
     * surface around the face (the notification accent), never the face.
     */
    val headColor: Int
        get() = CritAlarmPalette.YELLOW

    /** The eyes, brows and mouth are ink on every state. */
    val strokeColor: Int
        get() = CritAlarmPalette.INK
}

/**
 * What the card shows for one incident state.
 *
 * The four words match the StatusPill in
 * ios/CritAlarmActivity/IncidentActivityWidget.swift so the two platforms say
 * the same thing about the same incident.
 */
enum class IncidentCardState(
    val face: CritAlarmFace,
    private val word: NativeText,
) {
    OPEN(CritAlarmFace.ALARMED, NativeText.STATE_RINGING),
    ACKED(CritAlarmFace.ACKED, NativeText.STATE_AWAKE),
    CLOSED(CritAlarmFace.CALM, NativeText.STATE_CLOSED),
    EXPIRED(CritAlarmFace.WORRIED, NativeText.STATE_MISSED);

    /** The chip's word in English, upper case. */
    val chipText: String get() = chipText(NativeWords.English)

    /** The chip's word from [words], upper case in the locale it is written in. */
    fun chipText(words: NativeWords, locale: Locale = Locale.ROOT): String =
        words.text(word).uppercase(locale)

    val accentColor: Int get() = face.canvasColor
}

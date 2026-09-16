package app.critalarm.notifications

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

    val strokeColor: Int
        get() = if (this == ACKED) CritAlarmPalette.ON_HIGHLIGHT else CritAlarmPalette.INK
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
    val chipText: String,
) {
    OPEN(CritAlarmFace.ALARMED, "RINGING"),
    ACKED(CritAlarmFace.ACKED, "AWAKE"),
    CLOSED(CritAlarmFace.CALM, "CLOSED"),
    EXPIRED(CritAlarmFace.WORRIED, "MISSED");

    val accentColor: Int get() = face.canvasColor
}

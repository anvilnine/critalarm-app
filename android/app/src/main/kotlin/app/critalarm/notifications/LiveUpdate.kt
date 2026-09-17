package app.critalarm.notifications

import android.content.Context
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Promoted ongoing notifications, which Android 16 calls Live Updates.
 *
 * This is the closest Android gets to the iOS Live Activity: an ongoing
 * notification lifted onto the lock screen and into the status bar chip. It is
 * a template, not a canvas, so everything here fills a named slot. A custom
 * content view or a colorized notification is refused promotion outright, so
 * neither is used anywhere in this package.
 *
 * Every call below is safe on every version. androidx.core 1.17.0 carries the
 * API 36 checks inside NotificationManagerCompat and NotificationCompatBuilder,
 * so on Android 15 and below the card posts as an ordinary ongoing
 * notification and nothing here needs a version guard of its own.
 */
object LiveUpdate {
    /**
     * True when the OS is new enough and the user has left promoted
     * notifications on for this app. False on anything below API 36.
     */
    fun canPromote(context: Context): Boolean =
        NotificationManagerCompat.from(context).canPostPromotedNotifications()

    /** Asks for the lock screen and status bar treatment. */
    fun NotificationCompat.Builder.requestPromotion(): NotificationCompat.Builder =
        setRequestPromotedOngoing(true)

    /** The word in the status bar chip. Keep it to a few characters. */
    fun NotificationCompat.Builder.shortCriticalText(text: String): NotificationCompat.Builder =
        setShortCriticalText(text)

    /**
     * The countdown bar, the second half of a Live Update.
     *
     * One segment covers the whole wait, the progress says how much of it has
     * gone, and the point sits on the instant the incident rings again. The bar
     * is a style, so it replaces BigTextStyle on the cards that get one, and it
     * leaves the chronometer slot alone: the elapsed timer counts up from
     * setWhen while this counts the wait down.
     *
     * androidx.core 1.17.0 carries NotificationCompat.ProgressStyle and its
     * Api36Impl, so this posts a bar on Android 16 and degrades to a plain
     * progress row below it, with no version check here.
     *
     * Returns null when there is nothing to count, so the caller can leave the
     * style alone rather than draw a bar of length zero.
     */
    fun countdownBar(
        elapsedSeconds: Long,
        totalSeconds: Long,
        color: Int,
    ): NotificationCompat.ProgressStyle? {
        if (totalSeconds <= 0L) return null
        val length = totalSeconds.coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
        val progress = elapsedSeconds.coerceIn(0L, length.toLong()).toInt()
        return NotificationCompat.ProgressStyle()
            .addProgressSegment(NotificationCompat.ProgressStyle.Segment(length).setColor(color))
            .addProgressPoint(NotificationCompat.ProgressStyle.Point(length).setColor(color))
            .setProgress(progress)
            .setStyledByProgress(true)
    }
}

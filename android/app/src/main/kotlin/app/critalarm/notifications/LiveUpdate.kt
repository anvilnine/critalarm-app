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
}

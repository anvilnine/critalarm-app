package app.critalarm.links

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import app.critalarm.MainActivity

/**
 * Opens an `https://critalarm.app` link in the app.
 *
 * Holds the VIEW filter so MainActivity and the launcher aliases do not:
 *
 * - A link that landed on MainActivity from an app that did not ask for a new
 *   task would start a second Flutter engine inside that app's task and take
 *   the push channel away from the real one. The audio share has its own
 *   activity for the same reason.
 * - MainActivity never sees a data URI this way. The link travels as an
 *   extra, which is read once and removed, so nothing can hand it to
 *   go_router as a location and a replay from recents carries no link.
 * - Only one launcher alias is enabled at a time. A filter on an alias would
 *   stop working when the user picks another icon.
 *
 * It has no screen. It never reads the link beyond checking its shape, and
 * never logs it: a connect link carries a token.
 */
class AppLinkActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Recreated, say on rotation: the first instance already handed off.
        if (savedInstanceState == null) {
            val data = intent?.data
            val link = if (intent?.action == Intent.ACTION_VIEW && data != null) {
                AppLinkRule.linkToForward(data.scheme, data.host, data.port, data.path, data.toString())
            } else {
                null
            }
            // A link that is not the app's still opens the app, on Home.
            startActivity(
                Intent(this, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    if (link != null) putExtra(MainActivity.EXTRA_LINK, link)
                },
            )
        }
        finish()
    }
}

/**
 * Which links go to Dart. Pure, so a JVM test can reach it.
 *
 * It matches the manifest filter and nothing more. What a link opens is
 * decided in Dart, by the one parser.
 */
object AppLinkRule {
    const val SCHEME = "https"
    const val HOST = "critalarm.app"
    const val CONNECT_PATH = "/connect"
    const val OPEN_PREFIX = "/open/"

    /** [whole] when the link is one the app claims, or null. */
    fun linkToForward(scheme: String?, host: String?, port: Int, path: String?, whole: String): String? {
        if (!scheme.equals(SCHEME, ignoreCase = true)) return null
        if (!host.equals(HOST, ignoreCase = true)) return null
        if (port != -1 && port != 443) return null
        if (path == null) return null
        return if (path == CONNECT_PATH || path.startsWith(OPEN_PREFIX)) whole else null
    }
}

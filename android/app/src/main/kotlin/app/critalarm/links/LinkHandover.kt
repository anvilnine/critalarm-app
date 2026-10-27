package app.critalarm.links

import java.util.UUID

/**
 * How a link gets from AppLinkActivity to MainActivity.
 *
 * The link stays here, in memory. The intent carries a pass made for that
 * one hand-over and nothing of the link. MainActivity is exported, so an
 * extra on its intent does not say who put it there: only the pass in hand
 * gives a link, and it gives it once.
 *
 * One link is held at a time, and a newer one replaces a link nobody
 * collected. Both activities run in the app's one process. If that process
 * dies in between, the link is gone and the app opens on Home.
 *
 * Nothing is logged: a connect link carries a token.
 *
 * Pure, so a JVM test can reach it.
 */
object LinkHandover {
    private var heldPass: String? = null
    private var heldLink: String? = null

    /** Holds [link] and returns the pass AppLinkActivity puts on the intent. */
    @Synchronized
    fun hold(link: String): String {
        val pass = UUID.randomUUID().toString()
        heldPass = pass
        heldLink = link
        return pass
    }

    /**
     * The link held under [pass], or null when [pass] is not the one in
     * hand. A wrong pass leaves a held link where it is.
     */
    @Synchronized
    fun take(pass: String?): String? {
        if (pass == null || pass != heldPass) return null
        val link = heldLink
        heldPass = null
        heldLink = null
        return link
    }
}

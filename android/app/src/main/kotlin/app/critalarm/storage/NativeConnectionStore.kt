package app.critalarm.storage

import android.content.Context
import java.net.URI

/**
 * The session Dart saved: `server|...|token`.
 *
 * It lives in Dart's own preferences, which cannot be read before the first
 * unlock after a reboot. Then only the server address is known, from the
 * copy in device-protected storage ([BootMirror]), and there are no
 * credentials: nothing that needs the token runs before the unlock.
 */
class NativeConnectionStore(context: Context) {
    private val app = context.applicationContext ?: context
    private val unlocked = BootStorage.isUnlocked(app)
    private val preferences by lazy {
        app.getSharedPreferences(BootStorage.FLUTTER, Context.MODE_PRIVATE)
    }

    /** The one server this app is connected to, or null when it is not. */
    fun canonicalServer(): URI? {
        val raw = if (unlocked) {
            preferences.getString(BootMirror.SESSION_KEY, null)?.substringBefore('|')
        } else {
            BootStorage.flutterPrefs(app).getString(BootMirror.SERVER_KEY, null)
        } ?: return null
        return runCatching { URI(raw) }.getOrNull()
    }

    fun matchesCanonicalServer(server: URI): Boolean {
        val canonical = canonicalServer() ?: return false
        return canonical.normalize() == server.normalize()
    }

    /** The server and its token, or null. Always null before the first unlock. */
    fun credentialsFor(server: URI): Pair<URI, String>? {
        if (!unlocked) return null
        val raw = preferences.getString(BootMirror.SESSION_KEY, null) ?: return null
        val parts = raw.split('|')
        if (parts.size != 4) return null
        val canonical = runCatching { URI(parts[0]) }.getOrNull() ?: return null
        if (canonical.normalize() != server.normalize()) return null
        return canonical to parts[3]
    }
}

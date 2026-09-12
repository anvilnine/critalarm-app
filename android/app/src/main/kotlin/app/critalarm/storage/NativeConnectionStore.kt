package app.critalarm.storage

import android.content.Context
import java.net.URI

class NativeConnectionStore(context: Context) {
    private val preferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    fun matchesCanonicalServer(server: URI): Boolean {
        val raw = preferences.getString("flutter.api_session", null)
            ?: preferences.getString("flutter.api_session", null)
            ?: return false
        val canonical = runCatching { URI(raw.substringBefore('|')) }.getOrNull() ?: return false
        return canonical.normalize() == server.normalize()
    }

    fun credentialsFor(server: URI): Pair<URI, String>? {
        val raw = preferences.getString("flutter.api_session", null) ?: return null
        val parts = raw.split('|')
        if (parts.size != 4) return null
        val canonical = runCatching { URI(parts[0]) }.getOrNull() ?: return null
        if (canonical.normalize() != server.normalize()) return null
        return canonical to parts[3]
    }
}

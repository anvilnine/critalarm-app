package app.critalarm.taps

import io.flutter.embedding.engine.FlutterShellArgs
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Every start option the pinned Flutter embedding reads off an intent is on
 * the list the gate strips. A Flutter upgrade that adds one fails here.
 */
class FlutterShellExtrasTest {
    @Test
    fun `every FlutterShellArgs extra name is listed`() {
        val keys = FlutterShellArgs::class.java.declaredFields
            .filter { it.name.startsWith("ARG_KEY_") }
            .map { it.get(null) as String }
        assertTrue("no ARG_KEY_ constants found", keys.size > 10)
        for (key in keys) {
            assertTrue("$key reaches the engine from any app", key in FlutterShellExtras.NAMES)
        }
    }

    @Test
    fun `a routing extra is never on the list`() {
        for (name in TapSignature.FIELDS) {
            assertTrue(name, name !in FlutterShellExtras.NAMES)
        }
    }
}

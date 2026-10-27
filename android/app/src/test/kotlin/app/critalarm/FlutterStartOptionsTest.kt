package app.critalarm

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Flutter's own start options on MainActivity answer fixed values and never
 * read the intent. Any app can put the extras the defaults read, and a bad
 * value threw inside onCreate.
 *
 * MainActivity cannot be made in a JVM test (Flutter's activity calls into
 * Android as its class loads), so this checks two things without loading it:
 * MainActivity declares each getter itself, and each one is the fixed answer.
 */
class FlutterStartOptionsTest {
    private val fixed = mapOf(
        "getCachedEngineId" to "override fun getCachedEngineId(): String? = null",
        "getCachedEngineGroupId" to "override fun getCachedEngineGroupId(): String? = null",
        "getBackgroundMode" to "override fun getBackgroundMode(): BackgroundMode = BackgroundMode.opaque",
        "getDartEntrypointArgs" to "override fun getDartEntrypointArgs(): List<String>? = null",
        "getInitialRoute" to "override fun getInitialRoute(): String = TapRoute.initialRoute(launchRoute)",
    )

    @Test
    fun `MainActivity declares each start option itself`() {
        // Not initialised: only the declarations are read.
        val type = Class.forName("app.critalarm.MainActivity", false, javaClass.classLoader)
        val declared = type.declaredMethods.map { it.name }.toSet()
        for (name in fixed.keys) {
            assertTrue("$name falls back to Flutter's default, which reads the intent", name in declared)
        }
    }

    @Test
    fun `each start option is the fixed answer and reads no intent`() {
        val source = File("src/main/kotlin/app/critalarm/MainActivity.kt").readLines().map { it.trim() }
        for ((name, line) in fixed) {
            val found = source.filter { it.startsWith("override fun $name(") }
            assertEquals(name, listOf(line), found)
            assertTrue(name, !line.contains("intent", ignoreCase = true))
        }
    }
}

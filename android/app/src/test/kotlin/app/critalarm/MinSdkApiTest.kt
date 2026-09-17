package app.critalarm

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Methods that compile against compileSdk 36 but are not there on minSdk 28.
 *
 * `URLEncoder.encode(String, Charset)` is API 33 and core library desugaring
 * does not backport it, so on Android 9 to 12L the call throws
 * NoSuchMethodError. It sits on the Stop path, which means the alarm keeps
 * ringing behind a button that does nothing. Only the API 1 overload,
 * `encode(String, String)`, is allowed.
 */
class MinSdkApiTest {
    private val sources = File("src/main/kotlin/app/critalarm")

    @Test
    fun `URLEncoder is called with the API 1 overload`() {
        val offenders = kotlinFiles()
            .filter { file ->
                file.readLines().any { line ->
                    line.contains("URLEncoder.encode(") && line.contains("Charset")
                }
            }
            .map { it.name }
            .toList()
        assertTrue(
            "URLEncoder.encode(String, Charset) is API 33 and minSdk is 28: $offenders",
            offenders.isEmpty(),
        )
    }

    @Test
    fun `no file imports StandardCharsets for URLEncoder`() {
        val offenders = kotlinFiles()
            .filter { file ->
                val text = file.readText()
                text.contains("URLEncoder.encode(") && text.contains("StandardCharsets")
            }
            .map { it.name }
            .toList()
        assertTrue("StandardCharsets beside URLEncoder.encode: $offenders", offenders.isEmpty())
    }

    private fun kotlinFiles() = sources.walkTopDown().filter { it.extension == "kt" }
}

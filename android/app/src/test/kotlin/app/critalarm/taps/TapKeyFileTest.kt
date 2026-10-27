package app.critalarm.taps

import app.critalarm.MainActivity
import java.io.File
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class TapKeyFileTest {
    @get:Rule
    val folder = TemporaryFolder()

    private val alarm = mapOf(
        MainActivity.EXTRA_ALARM_INCIDENT_ID to "inc_a",
        MainActivity.EXTRA_INCIDENT_ID to "inc_a",
    )

    @Test
    fun `a mark made before a process restart still matches after it`() {
        val file = File(folder.root, TapKeyFile.NAME)
        // The process that posted the notification.
        val before = TapKeyFile(file).load()
        val mark = TapSignature.sign(before, alarm)
        // A new process reads the same file from scratch.
        val after = TapKeyFile(file).load()
        assertArrayEquals(before, after)
        assertEquals(TapVerdict.SIGNED, TapSignature.verdict(alarm, mark) { after })
    }

    @Test
    fun `the first read makes a key of the full size and writes it`() {
        val file = File(folder.root, "nested/" + TapKeyFile.NAME)
        val key = TapKeyFile(file).load()
        assertEquals(TapKeyFile.SIZE, key.size)
        assertTrue(file.isFile)
        assertArrayEquals(key, file.readBytes())
        assertFalse(File(file.parentFile, file.name + ".new").exists())
    }

    @Test
    fun `two installs get different keys`() {
        val one = TapKeyFile(File(folder.root, "one")).load()
        val two = TapKeyFile(File(folder.root, "two")).load()
        assertFalse(one.contentEquals(two))
    }

    @Test
    fun `a file of the wrong size is replaced`() {
        val file = File(folder.root, TapKeyFile.NAME)
        file.writeBytes(ByteArray(5))
        val key = TapKeyFile(file).load()
        assertEquals(TapKeyFile.SIZE, key.size)
        assertArrayEquals(key, file.readBytes())
    }

    @Test
    fun `a key that cannot be written is still returned`() {
        // A plain file where the folder should be: nothing can be written.
        val blocker = folder.newFile("blocker")
        val key = TapKeyFile(File(blocker, TapKeyFile.NAME)).load()
        assertEquals(TapKeyFile.SIZE, key.size)
    }
}

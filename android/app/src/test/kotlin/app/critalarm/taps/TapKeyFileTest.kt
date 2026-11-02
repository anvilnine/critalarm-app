package app.critalarm.taps

import app.critalarm.MainActivity
import java.io.File
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeFalse
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
    fun `a key file that cannot be read is kept for the next process`() {
        val file = File(folder.root, TapKeyFile.NAME)
        val saved = TapKeyFile(file).load()
        val mark = TapSignature.sign(saved, alarm)
        assertTrue(file.setReadable(false))
        // Running as a user that reads anything, the failure cannot be made.
        assumeFalse(file.canRead())
        try {
            val stopgap = TapKeyFile(file).load()
            assertEquals(TapKeyFile.SIZE, stopgap.size)
            assertFalse(stopgap.contentEquals(saved))
        } finally {
            file.setReadable(true)
        }
        // Not overwritten: the next process reads the same key and the mark
        // made before the failed read still matches.
        assertArrayEquals(saved, file.readBytes())
        val next = TapKeyFile(file).load()
        assertEquals(TapVerdict.SIGNED, TapSignature.verdict(alarm, mark) { next })
        assertFalse(File(file.parentFile, file.name + ".new").exists())
    }

    @Test
    fun `an existing key is never replaced`() {
        val file = File(folder.root, TapKeyFile.NAME)
        val first = TapKeyFile(file).load()
        repeat(3) { assertArrayEquals(first, TapKeyFile(file).load()) }
        assertArrayEquals(first, file.readBytes())
    }

    @Test
    fun `a key that cannot be written is still returned`() {
        // A plain file where the folder should be: nothing can be written.
        val blocker = folder.newFile("blocker")
        val key = TapKeyFile(File(blocker, TapKeyFile.NAME)).load()
        assertEquals(TapKeyFile.SIZE, key.size)
    }
}

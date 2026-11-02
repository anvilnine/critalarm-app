package app.critalarm.alarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RingVolumeTest {
    /** A fake AudioManager alarm stream. [log] records every change in order. */
    private class FakeStream(var level: Int, override val max: Int = 7, val log: MutableList<String> = mutableListOf()) :
        AlarmStream {
        var fails = false
        override val volume: Int get() = level
        override fun set(volume: Int) {
            if (fails) throw SecurityException("refused")
            log.add("set $volume")
            level = volume
        }
    }

    /** A fake file on disk: it outlives the [RingVolume] and the stream that used it. */
    private class FakeDisk(val log: MutableList<String> = mutableListOf()) : SavedVolume {
        var value: Int? = null
        override fun read(): Int? = value
        override fun write(volume: Int) {
            log.add("save $volume")
            value = volume
        }
        override fun clear() {
            log.add("clear")
            value = null
        }
    }

    @Test
    fun everyStartRaisesTheVolumeEvenWhileTheSoundPlays() {
        val stream = FakeStream(level = 3)
        val volume = RingVolume(stream, FakeDisk())

        // The first ring: nothing plays yet, so it rings anew.
        assertTrue(AlarmPlayerRules.onStart(quiet = false, loopAlive = false, mediaPlaying = false, volume = volume))
        assertEquals(7, stream.level)

        // The person presses volume down while it rings.
        stream.level = 1

        // A repeat push or the next slot of the chain arrives while the loop
        // still plays. The sound is not restarted, and the volume goes back up.
        assertFalse(AlarmPlayerRules.onStart(quiet = false, loopAlive = true, mediaPlaying = false, volume = volume))
        assertEquals(7, stream.level)

        stream.level = 0
        assertFalse(AlarmPlayerRules.onStart(quiet = false, loopAlive = false, mediaPlaying = true, volume = volume))
        assertEquals(7, stream.level)
    }

    @Test
    fun theVolumeFromBeforeTheFirstRingIsTheOneKept() {
        val stream = FakeStream(level = 3)
        val disk = FakeDisk()
        val volume = RingVolume(stream, disk)
        volume.raise()
        stream.level = 2
        volume.raise()
        assertEquals(3, disk.value)
        volume.restore()
        assertEquals(3, stream.level)
        assertNull(disk.value)
    }

    @Test
    fun theVolumeIsOnDiskBeforeItIsRaised() {
        val log = mutableListOf<String>()
        val volume = RingVolume(FakeStream(level = 4, log = log), FakeDisk(log))
        volume.raise()
        assertEquals(listOf("save 4", "set 7"), log)
    }

    @Test
    fun aQuietBuildLeavesTheVolumeAlone() {
        val stream = FakeStream(level = 2)
        val disk = FakeDisk()
        assertTrue(AlarmPlayerRules.onStart(quiet = true, loopAlive = false, mediaPlaying = false, volume = RingVolume(stream, disk)))
        assertEquals(2, stream.level)
        assertNull(disk.value)
    }

    @Test
    fun aRaiseThatFailsStillRings() {
        val stream = FakeStream(level = 2).apply { fails = true }
        val errors = mutableListOf<Exception>()
        val rings = AlarmPlayerRules.onStart(
            quiet = false,
            loopAlive = false,
            mediaPlaying = false,
            volume = RingVolume(stream, FakeDisk()),
            onError = { errors.add(it) },
        )
        assertTrue(rings)
        assertEquals(1, errors.size)
    }

    @Test
    fun aLoweredStreamIsPutBackWhileRinging() {
        val stream = FakeStream(level = 7)
        val volume = RingVolume(stream, FakeDisk())
        assertFalse(volume.holdAtMax())
        stream.level = 5
        assertTrue(volume.holdAtMax())
        assertEquals(7, stream.level)
    }

    @Test
    fun theSavedVolumeComesBackAfterACrashMidRing() {
        val disk = FakeDisk()
        RingVolume(FakeStream(level = 3), disk).raise()
        // The process dies here. Nothing called restore, the phone stays at
        // full and the disk still holds 3.
        val afterCrash = FakeStream(level = 7)
        val launched = RingVolume(afterCrash, disk)

        // Next start, with an alarm ringing again, leaves it for that ring's stop.
        assertFalse(launched.recover(ringing = true))
        assertEquals(7, afterCrash.level)

        // Next start with nothing ringing puts it back.
        assertTrue(launched.recover(ringing = false))
        assertEquals(3, afterCrash.level)
        assertNull(disk.value)

        // Nothing saved, nothing to do.
        assertFalse(launched.recover(ringing = false))
    }

    @Test
    fun aRingAfterACrashKeepsTheVolumeFromBeforeTheCrash() {
        val disk = FakeDisk()
        RingVolume(FakeStream(level = 2), disk).raise()
        // The process died at full volume. A new alarm rings in the new process.
        val stream = FakeStream(level = 7)
        val volume = RingVolume(stream, disk)
        volume.raise()
        assertEquals(2, disk.value)
        volume.restore()
        assertEquals(2, stream.level)
    }

    @Test
    fun aRestoreThatFailsStillDropsTheSavedValue() {
        val disk = FakeDisk()
        val stream = FakeStream(level = 3)
        val volume = RingVolume(stream, disk)
        volume.raise()
        stream.fails = true
        runCatching { volume.restore() }
        assertNull(disk.value)
    }

    // W10: under total-silence Do Not Disturb the phone ignores the put-back,
    // and the watch logged it every second.
    @Test
    fun aPutBackThePhoneIgnoresIsToldApartFromOneThatWorked() {
        val stream = FakeStream(level = 7)
        val volume = RingVolume(stream, FakeDisk())
        assertEquals(RingVolume.Hold.AT_MAX, volume.hold())

        stream.level = 2
        assertEquals(RingVolume.Hold.PUT_BACK, volume.hold())
        assertEquals(7, stream.level)

        val ignoring = object : AlarmStream {
            override val volume = 0
            override val max = 7
            override fun set(volume: Int) = Unit
        }
        assertEquals(RingVolume.Hold.REFUSED, RingVolume(ignoring, FakeDisk()).hold())

        stream.level = 1
        stream.fails = true
        assertEquals(RingVolume.Hold.REFUSED, volume.hold())
        assertTrue(volume.holdAtMax())
    }
}

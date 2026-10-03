package app.critalarm.alarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PcmWriterTest {
    private val pcm = ShortArray(10_000) { (it % 64).toShort() }

    /** Records what was written, and answers with [answer] from the given call on. */
    private class FakeTrack(
        private val failOnCall: Int = Int.MAX_VALUE,
        private val answer: () -> Int = { 0 },
    ) : PcmSink {
        var calls = 0
        var written = 0
        override fun write(samples: ShortArray, offset: Int, size: Int): Int {
            calls += 1
            if (calls >= failOnCall) return answer()
            written += size
            return size
        }
    }

    private fun feed(track: PcmSink, loop: Boolean, running: () -> Boolean = { true }, errors: MutableList<String>? = null) =
        PcmWriter.feed(pcm, pcm.size, 1, loop, track, running, chunkFrames = 4096, onError = { errors?.add(it) })

    @Test
    fun aDeadTrackFailsSoTheOwnerFallsBack() {
        // ERROR_DEAD_OBJECT after an audio server restart.
        val errors = mutableListOf<String>()
        val track = FakeTrack(failOnCall = 7) { -6 }
        assertEquals(LoopEnd.FAILED, feed(track, loop = true, errors = errors))
        assertEquals(listOf("code=-6"), errors)
    }

    @Test
    fun anInvalidOperationFails() {
        assertEquals(LoopEnd.FAILED, feed(FakeTrack(failOnCall = 1) { -3 }, loop = true))
    }

    @Test
    fun aZeroFromATrackNobodyPausedFails() {
        assertEquals(LoopEnd.FAILED, feed(FakeTrack(failOnCall = 3) { 0 }, loop = true))
    }

    @Test
    fun aThrowingTrackFails() {
        val errors = mutableListOf<String>()
        val track = FakeTrack(failOnCall = 2) { throw IllegalStateException("released") }
        assertEquals(LoopEnd.FAILED, feed(track, loop = true, errors = errors))
        assertEquals(1, errors.size)
    }

    @Test
    fun aZeroAfterStopIsAStopNotAFailure() {
        var running = true
        val track = FakeTrack(failOnCall = 3) {
            running = false
            0
        }
        assertEquals(LoopEnd.STOPPED, feed(track, loop = true, running = { running }))
    }

    @Test
    fun aThrowAfterStopIsAStopNotAFailure() {
        var running = true
        val track = FakeTrack(failOnCall = 2) {
            running = false
            throw IllegalStateException("released")
        }
        assertEquals(LoopEnd.STOPPED, feed(track, loop = true, running = { running }))
    }

    @Test
    fun aSinglePassWritesEverythingOnceAndSaysSo() {
        val track = FakeTrack()
        assertEquals(LoopEnd.PASS_DONE, feed(track, loop = false))
        assertEquals(pcm.size, track.written)
    }

    @Test
    fun aLoopKeepsGoingUntilStopped() {
        var running = true
        val track = object : PcmSink {
            var written = 0
            override fun write(samples: ShortArray, offset: Int, size: Int): Int {
                written += size
                if (written >= pcm.size * 12) running = false
                return size
            }
        }
        assertEquals(LoopEnd.STOPPED, feed(track, loop = true, running = { running }))
        assertEquals(true, track.written >= pcm.size * 12)
    }

    @Test
    fun aShortWriteIsFinishedBeforeTheNextChunk() {
        val offsets = mutableListOf<Int>()
        var running = true
        val track = PcmSink { _, offset, size ->
            offsets.add(offset)
            if (offsets.size >= 6) running = false
            minOf(size, 1000)
        }
        feed(track, loop = true, running = { running })
        assertEquals(listOf(0, 1000, 2000, 3000, 4000, 4096), offsets)
    }

    @Test
    fun writeResults() {
        assertNull(PcmWriter.afterWrite(512, running = true))
        assertEquals(LoopEnd.FAILED, PcmWriter.afterWrite(0, running = true))
        assertEquals(LoopEnd.FAILED, PcmWriter.afterWrite(-32, running = true))
        assertEquals(LoopEnd.STOPPED, PcmWriter.afterWrite(0, running = false))
        assertEquals(LoopEnd.STOPPED, PcmWriter.afterWrite(-6, running = false))
    }
}

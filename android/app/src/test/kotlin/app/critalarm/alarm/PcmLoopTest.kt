package app.critalarm.alarm

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlin.math.sin
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PcmLoopTest {
    /** The test loop from the device check: 750 Hz at 48 kHz, 64 samples a period. */
    private fun sineLoop(frames: Int): ShortArray =
        ShortArray(frames) { (sin(2 * PI * it / 64) * 16_000).roundToInt().toShort() }

    /** Everything a writer hands the track, chunk by chunk, until [wraps] wraps. */
    private fun play(pcm: ShortArray, chunkFrames: Int, wraps: Int): ShortArray {
        val loop = PcmLoop(pcm.size, loop = true)
        val out = ArrayList<Short>()
        while (loop.wraps < wraps) {
            val chunk = loop.next(chunkFrames)!!
            for (i in chunk.start until chunk.start + chunk.count) out.add(pcm[i])
        }
        return out.toShortArray()
    }

    @Test
    fun tenWrapsAreTheBufferTenTimesWithNothingBetween() {
        val pcm = sineLoop(96_000)
        // 4096 does not divide 96000, so chunks end short at every wrap.
        val written = play(pcm, chunkFrames = 4096, wraps = 10)
        assertEquals(96_000 * 10, written.size)
        for (pass in 0 until 10) {
            assertArrayEquals(pcm, written.copyOfRange(pass * 96_000, (pass + 1) * 96_000))
        }
    }

    @Test
    fun theSeamIsNoBiggerAStepThanAnyOtherSample() {
        val pcm = sineLoop(96_000)
        val written = play(pcm, chunkFrames = 4096, wraps = 12)
        var largestInside = 0
        for (i in 1 until pcm.size) largestInside = maxOf(largestInside, abs(pcm[i] - pcm[i - 1]))
        for (wrap in 1 until 12) {
            val seam = wrap * pcm.size
            val step = abs(written[seam] - written[seam - 1])
            assertTrue("step $step at wrap $wrap", step <= largestInside)
        }
    }

    @Test
    fun aChunkNeverCrossesTheEnd() {
        val loop = PcmLoop(10, loop = true)
        assertEquals(PcmLoop.Chunk(0, 4), loop.next(4))
        assertEquals(PcmLoop.Chunk(4, 4), loop.next(4))
        assertEquals(PcmLoop.Chunk(8, 2), loop.next(4))
        assertEquals(1, loop.wraps)
        assertEquals(PcmLoop.Chunk(0, 4), loop.next(4))
    }

    @Test
    fun withoutLoopingItPlaysOnceAndStops() {
        val loop = PcmLoop(10, loop = false)
        assertEquals(PcmLoop.Chunk(0, 6), loop.next(6))
        assertEquals(PcmLoop.Chunk(6, 4), loop.next(6))
        assertNull(loop.next(6))
        assertEquals(0, loop.wraps)
    }

    @Test
    fun anEmptyBufferHandsOutNothing() {
        assertNull(PcmLoop(0, loop = true).next(4096))
        assertNull(PcmLoop(10, loop = true).next(0))
    }
}

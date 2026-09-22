package app.critalarm.sound

import java.nio.ByteBuffer
import java.nio.ByteOrder
import org.junit.Assert.assertEquals
import org.junit.Test

class ClipMathTest {
    @Test
    fun halvingTheRateHalvesTheSampleCount() {
        val input = FloatArray(44_100) { 0.5f }
        val out = ClipMath.resample(input, input.size, 44_100, 22_050)
        assertEquals(22_050, out.size)
        assertEquals(0.5f, out[100], 1e-6f)
    }

    @Test
    fun onlyTheCountedSamplesAreUsed() {
        val input = FloatArray(10) { it.toFloat() }
        val out = ClipMath.resample(input, 4, 22_050, 22_050)
        assertEquals(4, out.size)
    }

    @Test
    fun resamplingDrawsStraightLinesBetweenSamples() {
        val out = ClipMath.resample(floatArrayOf(0f, 1f), 2, 1, 2)
        assertEquals(4, out.size)
        assertEquals(0.5f, out[1], 1e-6f)
    }

    @Test
    fun fadeStartsAndEndsInSilenceAndLeavesTheMiddle() {
        val samples = FloatArray(22_050) { 1f }
        ClipMath.fade(samples, 22_050, 50)
        assertEquals(0f, samples[0], 1e-6f)
        assertEquals(0f, samples.last(), 1e-6f)
        assertEquals(1f, samples[11_000], 1e-6f)
        // 50 ms at 22.05 kHz is 1102 samples.
        assertEquals(0.5f, samples[551], 0.01f)
    }

    @Test
    fun wavHeaderDescribesMono16BitAtTheRate() {
        val bytes = ClipMath.wavBytes(FloatArray(100), 22_050)
        assertEquals(244, bytes.size)
        val header = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        assertEquals("RIFF", String(bytes, 0, 4, Charsets.US_ASCII))
        assertEquals("WAVE", String(bytes, 8, 4, Charsets.US_ASCII))
        assertEquals(1, header.getShort(22).toInt())
        assertEquals(22_050, header.getInt(24))
        assertEquals(16, header.getShort(34).toInt())
        assertEquals(200, header.getInt(40))
    }
}

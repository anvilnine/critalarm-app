package app.critalarm.sound

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test

class PcmMathTest {
    @Test
    fun opusDurationGivesBackTheExactFrameCount() {
        // classic_siren.ogg: 768000 valid frames at 48 kHz.
        assertEquals(768_000, PcmMath.framesForDurationUs(16_000_000L, 48_000))
        // 96648 frames is 2013500 µs exactly; 96647 frames is 2013479.1 µs, cut to 2013479.
        assertEquals(96_648, PcmMath.framesForDurationUs(2_013_500L, 48_000))
        assertEquals(96_647, PcmMath.framesForDurationUs(2_013_479L, 48_000))
        assertEquals(0, PcmMath.framesForDurationUs(0L, 48_000))
    }

    @Test
    fun theOpusTailPaddingIsCut() {
        // 768000 valid + 648 remainder, the shipped files' worst case.
        assertEquals(768_000, PcmMath.trimmedFrames(768_648, 768_000, PcmMath.maxTrimFrames(48_000)))
    }

    @Test
    fun aDurationFarShorterThanTheDecodeIsIgnored() {
        assertEquals(768_648, PcmMath.trimmedFrames(768_648, 700_000, PcmMath.maxTrimFrames(48_000)))
    }

    @Test
    fun aShortDecodeIsNeverPadded() {
        assertEquals(767_000, PcmMath.trimmedFrames(767_000, 768_000, 1920))
        assertEquals(767_000, PcmMath.trimmedFrames(767_000, 0, 1920))
    }

    @Test
    fun maxTrimIsFortyMilliseconds() {
        assertEquals(1920, PcmMath.maxTrimFrames(48_000))
    }

    @Test
    fun floatSamplesAreScaledAndClipped() {
        assertEquals(Short.MAX_VALUE, PcmMath.floatToPcm16(1f))
        assertEquals(Short.MAX_VALUE, PcmMath.floatToPcm16(2f))
        assertEquals((-Short.MAX_VALUE).toShort(), PcmMath.floatToPcm16(-1.5f))
        assertEquals(0.toShort(), PcmMath.floatToPcm16(0f))
    }

    @Test
    fun monoAndStereoPassThrough() {
        val stereo = shortArrayOf(1, 2, 3, 4)
        val out = ShortArray(4)
        assertEquals(4, PcmMath.mixInto(stereo, 2, 2, out, 0))
        assertArrayEquals(stereo, out)
        val mono = ShortArray(3)
        assertEquals(2, PcmMath.mixInto(shortArrayOf(7, 8), 2, 1, mono, 1))
        assertArrayEquals(shortArrayOf(0, 7, 8), mono)
    }

    @Test
    fun widerThanStereoIsFoldedToMono() {
        val sixChannels = shortArrayOf(6, 6, 6, 0, 0, 0, 12, 12, 12, 12, 12, 12)
        val out = ShortArray(2)
        assertEquals(2, PcmMath.mixInto(sixChannels, 2, 6, out, 0))
        assertArrayEquals(shortArrayOf(3, 12), out)
    }
}

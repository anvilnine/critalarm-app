package app.critalarm.alarm

import java.io.File
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HapticPatternTest {
    private val sounds = File("../../assets/sounds")
    private val loudnessDir = File("src/test/resources/alarm_loudness")

    /** The Android sounds: every bundled sound's .ogg, see AlarmSoundStore.assetPathFor. */
    private fun bundledIds(): List<String> =
        sounds.listFiles { file -> file.extension == "ogg" }!!.map { it.nameWithoutExtension }.sorted()

    private fun loudnessOf(id: String): DoubleArray =
        File(loudnessDir, "$id.txt").readLines().filter { it.isNotBlank() }.map { it.toDouble() }.toDoubleArray()

    private val window = HapticPattern.WINDOW_MS.toLong()

    /** The middle of window [i], in ms from the start of the sound. */
    private fun middle(i: Int) = i * window + window / 2

    @Test
    fun everyBundledSoundHasItsLoudness() {
        val ids = bundledIds()
        assertTrue("no bundled sounds found at ${sounds.absolutePath}", ids.size >= 20)
        val missing = ids.filter { !File(loudnessDir, "$it.txt").exists() }
        assertTrue("run tool/alarm_loudness_fixtures.sh, missing: $missing", missing.isEmpty())
    }

    @Test
    fun thePatternPutsItsPeaksOnTheSoundsPeaksForEveryBundledSound() {
        for (id in bundledIds()) {
            val loudness = loudnessOf(id)
            val durationMs = loudness.size * window
            val pattern = HapticPattern.fromLoudness(loudness, durationMs)

            // One pass is as long as the sound, so both loop in step.
            assertEquals("$id length", durationMs, pattern.durationMs)
            assertTrue("$id never vibrates", !pattern.isStill)

            // The loudest moment of the sound is the strongest vibration.
            val loudest = loudness.indices.maxBy { loudness[it] }
            assertEquals("$id loudest", 255, pattern.amplitudeAt(middle(loudest)))

            var beat = 0
            while (beat < loudness.size) {
                if (loudness[beat] < HapticPattern.GATE) {
                    // A quiet stretch of the sound is a still motor.
                    assertEquals("$id quiet at ${middle(beat)} ms", 0, pattern.amplitudeAt(middle(beat)))
                    beat += 1
                    continue
                }
                // One beat: a run of loud windows. Its peak is where the
                // vibration is strongest, and every loud window vibrates.
                var end = beat
                while (end < loudness.size && loudness[end] >= HapticPattern.GATE) end += 1
                val peak = (beat until end).maxBy { loudness[it] }
                val strongest = (beat until end).maxOf { pattern.amplitudeAt(middle(it)) }
                assertEquals("$id beat at ${beat * window} ms", strongest, pattern.amplitudeAt(middle(peak)))
                for (i in beat until end) {
                    assertTrue("$id loud at ${middle(i)} ms", pattern.amplitudeAt(middle(i)) > 0)
                    // Louder never vibrates weaker.
                    if (i > beat && loudness[i] > loudness[i - 1]) {
                        assertTrue(pattern.amplitudeAt(middle(i)) >= pattern.amplitudeAt(middle(i - 1)))
                    }
                }
                beat = end
            }
        }
    }

    @Test
    fun theAppsOwnLoudnessFindsTheBeepsInPcm() {
        // 48 kHz mono: 100 ms beep, 100 ms silence, five times, then a soft beep.
        val rate = 48_000
        val frames = rate * 12 / 10
        val samples = ShortArray(frames)
        for (frame in 0 until frames) {
            val ms = frame * 1000 / rate
            val on = ms < 1000 && (ms / 100) % 2 == 0
            val soft = ms in 1000 until 1100
            val level = if (on) 20_000 else if (soft) 2_000 else 0
            samples[frame] = (if (frame % 2 == 0) level else -level).toShort()
        }
        val pattern = HapticPattern.forPcm(samples, frames, channels = 1, sampleRate = rate)
        assertEquals(1200L, pattern.durationMs)
        for (beep in 0 until 5) {
            assertEquals("beep $beep", 255, pattern.amplitudeAt(beep * 200L + 50))
            assertEquals("gap $beep", 0, pattern.amplitudeAt(beep * 200L + 150))
        }
        // A beep a tenth as loud as the rest is under the gate.
        assertEquals(0, pattern.amplitudeAt(1050))
    }

    @Test
    fun stereoIsMixedBeforeItIsMeasured() {
        val frames = 960 * 2
        val samples = ShortArray(frames * 2)
        // First window loud on the left only, second loud on both.
        for (frame in 0 until frames) {
            samples[frame * 2] = 10_000
            samples[frame * 2 + 1] = if (frame < 960) 0 else 10_000
        }
        val loudness = HapticPattern.loudness(samples, frames, channels = 2, sampleRate = 48_000)
        assertEquals(2, loudness.size)
        assertEquals(0.5, loudness[0], 1e-6)
        assertEquals(1.0, loudness[1], 1e-6)
    }

    @Test
    fun aSilentSoundGivesAStillPattern() {
        val loudness = HapticPattern.loudness(ShortArray(4800), 4800, channels = 1, sampleRate = 48_000)
        assertTrue(loudness.all { it == 0.0 })
        assertTrue(HapticPattern.fromLoudness(loudness, 100).isStill)
    }

    @Test
    fun neighbouringStepsOfTheSameStrengthAreJoined() {
        val pattern = HapticPattern.fromLoudness(doubleArrayOf(1.0, 1.0, 1.0, 0.0, 0.0, 1.0), durationMs = 115)
        assertArrayEquals(longArrayOf(60, 40, 15), pattern.timings)
        assertArrayEquals(intArrayOf(255, 0, 255), pattern.amplitudes)
    }

    @Test
    fun strengthRisesWithLoudnessAndStopsUnderTheGate() {
        assertEquals(0, HapticPattern.amplitude(0.0))
        assertEquals(0, HapticPattern.amplitude(HapticPattern.GATE - 0.01))
        assertTrue(HapticPattern.amplitude(HapticPattern.GATE) >= HapticPattern.MIN_AMPLITUDE)
        assertEquals(255, HapticPattern.amplitude(1.0))
        var last = 0
        for (step in 0..100) {
            val amp = HapticPattern.amplitude(step / 100.0)
            assertTrue(amp >= last)
            assertTrue(amp in 0..255)
            last = amp
        }
    }

    @Test
    fun theModeFollowsTheSwitchAndThePhone() {
        assertEquals(HapticMode.OFF, HapticPattern.mode(switchOn = false, sdk = 35) { true })
        assertEquals(HapticMode.GENERATOR, HapticPattern.mode(switchOn = true, sdk = 31) { true })
        assertEquals(HapticMode.PATTERN, HapticPattern.mode(switchOn = true, sdk = 35) { false })
        // Android 11 has no generator, and is never asked.
        assertEquals(HapticMode.PATTERN, HapticPattern.mode(switchOn = true, sdk = 30) { error("not asked") })
    }
}

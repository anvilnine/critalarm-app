package app.critalarm.alarm

/**
 * Walks a PCM buffer of [frames] frames in chunks, and wraps from the last
 * frame straight back to frame 0 when [loop] is on.
 *
 * The alarm's writer thread hands each chunk to a streaming AudioTrack. Every
 * frame is written once per pass and nothing is written between passes, so
 * the audio server sees one unbroken stream and the wrap has no gap. That is
 * the whole difference from `MediaPlayer.setLooping`, which waits for the end,
 * seeks to 0 and refills its decoder.
 *
 * Pure, so the seam can be tested on the JVM.
 */
class PcmLoop(private val frames: Int, private val loop: Boolean) {
    /** One run of frames to write: [start] is a frame index, [count] frames long. */
    data class Chunk(val start: Int, val count: Int)

    private var position = 0
    private var finished = frames <= 0

    /** How many times playback has gone from the last frame back to frame 0. */
    var wraps = 0
        private set

    /**
     * The next run of at most [maxFrames] frames, or null once a single pass
     * has been handed out with [loop] off. A chunk never crosses the end of
     * the buffer: the frame after the last one is frame 0 of the next chunk.
     */
    fun next(maxFrames: Int): Chunk? {
        if (finished || maxFrames <= 0) return null
        val count = minOf(maxFrames, frames - position)
        val chunk = Chunk(position, count)
        position += count
        if (position == frames) {
            if (loop) {
                position = 0
                wraps += 1
            } else {
                finished = true
            }
        }
        return chunk
    }
}

/** How a writer stopped feeding the track. */
enum class LoopEnd {
    /** [PcmLoopPlayer.stop] was called. Nothing more to do. */
    STOPPED,

    /** The one pass of a non-looping ring is written in full. */
    PASS_DONE,

    /** The track refused a write or threw while still wanted. The owner must fall back. */
    FAILED,
}

/** Where a writer puts PCM: an AudioTrack on a phone, a fake in tests. */
fun interface PcmSink {
    /** Shorts accepted, 0 when the track is paused or stopped, negative on an error. */
    fun write(samples: ShortArray, offset: Int, size: Int): Int
}

/**
 * Feeds [samples] ([frames] frames of [channels] channels) to [sink], wrapping
 * with [PcmLoop], until [running] turns false, the single pass ends, or the
 * sink fails.
 *
 * Every way out while [running] is still true, other than a finished single
 * pass, is [LoopEnd.FAILED]: a negative code such as `ERROR_DEAD_OBJECT` after
 * an audio server restart, a 0 from a track nobody paused, or a throw. The
 * caller turns that into the MediaPlayer fallback, so the alarm never goes
 * quiet on its own. Pure, so every exit is tested on the JVM.
 */
object PcmWriter {
    const val CHUNK_FRAMES = 4096

    fun feed(
        samples: ShortArray,
        frames: Int,
        channels: Int,
        loop: Boolean,
        sink: PcmSink,
        running: () -> Boolean,
        chunkFrames: Int = CHUNK_FRAMES,
        onError: (String) -> Unit = {},
    ): LoopEnd {
        val cursor = PcmLoop(frames, loop)
        while (running()) {
            val chunk = cursor.next(chunkFrames) ?: return LoopEnd.PASS_DONE
            val end = (chunk.start + chunk.count) * channels
            var at = chunk.start * channels
            while (at < end) {
                val written = try {
                    sink.write(samples, at, end - at)
                } catch (error: Exception) {
                    if (!running()) return LoopEnd.STOPPED
                    onError("threw $error")
                    return LoopEnd.FAILED
                }
                afterWrite(written, running())?.let { outcome ->
                    if (outcome == LoopEnd.FAILED) onError("code=$written")
                    return outcome
                }
                at += written
            }
        }
        return LoopEnd.STOPPED
    }

    /** What one write result means. Null: keep writing. */
    fun afterWrite(written: Int, running: Boolean): LoopEnd? = when {
        !running -> LoopEnd.STOPPED
        written <= 0 -> LoopEnd.FAILED
        else -> null
    }
}

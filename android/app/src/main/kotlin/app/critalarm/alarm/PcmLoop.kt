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

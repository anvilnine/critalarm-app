package app.critalarm.alarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LoopRunTest {
    private class Owner {
        val heard = mutableListOf<String>()
        var released = 0
    }

    private fun finish(owner: Owner, running: () -> Boolean = { true }, body: () -> LoopEnd) =
        LoopRun.finish(
            body = body,
            release = { owner.released += 1 },
            running = running,
            onFailed = { owner.heard.add("failed") },
            onPassDone = { owner.heard.add("pass_done") },
        )

    @Test
    fun aThrowInPlayReleasesAndFallsBack() {
        val owner = Owner()
        val end = finish(owner) { throw IllegalStateException("play() on a dead track") }
        assertEquals(LoopEnd.FAILED, end)
        assertEquals(1, owner.released)
        assertEquals(listOf("failed"), owner.heard)
    }

    @Test
    fun anOutOfMemoryErrorIsAFailureToo() {
        val owner = Owner()
        assertEquals(LoopEnd.FAILED, finish(owner) { throw OutOfMemoryError() })
        assertEquals(listOf("failed"), owner.heard)
    }

    @Test
    fun stopDuringDecodeGivesNoCallback() {
        val owner = Owner()
        var running = true
        // The decode fails, but stop came while it ran: no one is listening.
        val end = finish(owner, running = { running }) {
            running = false
            LoopEnd.FAILED
        }
        assertEquals(LoopEnd.STOPPED, end)
        assertEquals(1, owner.released)
        assertTrue(owner.heard.isEmpty())
    }

    @Test
    fun aFinishedSinglePassIsReported() {
        val owner = Owner()
        finish(owner) { LoopEnd.PASS_DONE }
        assertEquals(listOf("pass_done"), owner.heard)
    }

    @Test
    fun aStoppedRunSaysNothing() {
        val owner = Owner()
        finish(owner, running = { false }) { LoopEnd.STOPPED }
        assertTrue(owner.heard.isEmpty())
        assertEquals(1, owner.released)
    }

    @Test
    fun aFailedTrackIsRebuiltOnceFromTheSamePcm() {
        val attempts = mutableListOf<Int>()
        val retries = mutableListOf<Int>()
        val end = LoopRun.withRetries(
            retries = 1,
            running = { true },
            attempt = { attempts.add(it); LoopEnd.FAILED },
            onRetry = { retries.add(it) },
        )
        assertEquals(LoopEnd.FAILED, end)
        assertEquals(listOf(0, 1), attempts)
        assertEquals(listOf(1), retries)
    }

    @Test
    fun aRebuiltTrackThatPlaysEndsTheRetries() {
        var calls = 0
        var running = true
        val end = LoopRun.withRetries(retries = 1, running = { running }, attempt = {
            calls += 1
            if (it == 0) LoopEnd.FAILED else {
                running = false
                LoopEnd.STOPPED
            }
        })
        assertEquals(LoopEnd.STOPPED, end)
        assertEquals(2, calls)
    }

    @Test
    fun aThrowingAttemptIsRetried() {
        val errors = mutableListOf<Throwable>()
        var calls = 0
        val end = LoopRun.withRetries(retries = 1, running = { true }, attempt = {
            calls += 1
            if (it == 0) throw IllegalStateException("track not initialized") else LoopEnd.PASS_DONE
        }, onError = { errors.add(it) })
        assertEquals(LoopEnd.PASS_DONE, end)
        assertEquals(2, calls)
        assertEquals(1, errors.size)
    }

    @Test
    fun noRetryAfterStop() {
        var running = true
        var calls = 0
        val end = LoopRun.withRetries(retries = 1, running = { running }, attempt = {
            calls += 1
            running = false
            LoopEnd.FAILED
        })
        assertEquals(LoopEnd.STOPPED, end)
        assertEquals(1, calls)
    }

    @Test
    fun theWholeRunFallsBackOnlyAfterBothTracksFail() {
        val owner = Owner()
        finish(owner) {
            LoopRun.withRetries(retries = 1, running = { true }, attempt = { LoopEnd.FAILED })
        }
        assertEquals(listOf("failed"), owner.heard)
        assertFalse(owner.heard.contains("pass_done"))
    }
}

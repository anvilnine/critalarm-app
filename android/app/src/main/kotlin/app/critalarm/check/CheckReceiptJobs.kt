package app.critalarm.check

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Which receipt jobs the system has taken back.
 *
 * One service object runs many jobs over its life, so "stopped" belongs to
 * one run of one job and never to the service. Each started job gets its own
 * [Run], and stopping a job stops that run and no other.
 */
class CheckReceiptJobs {
    /** One run of one job. */
    class Run internal constructor() {
        private val stopped = AtomicBoolean(false)
        val isStopped: Boolean get() = stopped.get()
        internal fun stop() = stopped.set(true)
    }

    private val runs = ConcurrentHashMap<Int, Run>()

    /** A job started. A run of the same id that is still going is left to end by itself. */
    fun started(jobId: Int): Run = Run().also { runs[jobId] = it }

    /** The system took the job back. */
    fun stop(jobId: Int) {
        runs[jobId]?.stop()
    }

    /** The run's own work ended. A later run under the same id is not touched. */
    fun finished(jobId: Int, run: Run) {
        runs.remove(jobId, run)
    }
}

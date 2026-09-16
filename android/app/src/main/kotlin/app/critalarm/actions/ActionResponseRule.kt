package app.critalarm.actions

/**
 * What the server's answer to an ack or a close means here.
 *
 * 404 and 410 say there is no such incident. A close that gets one has already
 * achieved what the user wanted, so the card comes down and nothing is queued:
 * a retry of that POST can never succeed. The onboarding demo is where this
 * shows up. inc_demo never existed on the server, so its Done button 404s
 * every time, and because the card only came down on a 2xx it stayed up, set
 * ongoing, which means it cannot be swiped away either.
 *
 * 409 is different. It means the incident moved on somewhere else, so there is
 * nothing left to send, but this device was not told what state it landed in.
 */
object ActionResponseRule {
    private val GONE = setOf(404, 410)

    /** True when nothing more needs sending, so the queue can let it go. */
    fun isSettled(status: Int): Boolean =
        status in 200..299 || status == 409 || status in GONE

    /** True when the incident is over, so its card goes and it is marked closed. */
    fun endsTheIncident(status: Int): Boolean = status in 200..299 || status in GONE
}

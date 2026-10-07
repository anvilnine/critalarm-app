package app.critalarm.check

/**
 * Hosts a weekly check receipt may reach over plain http.
 *
 * Debug builds only: this file lives in `src/debug` and is not compiled into
 * a release APK, whose own copy is empty. It names this machine and the
 * emulator's name for the computer it runs on, so a relay run on localhost
 * can be answered. Everything else is https or nothing.
 */
object PlainHttpRelays {
    val hosts: Set<String> = setOf("127.0.0.1", "localhost", "10.0.2.2")
}

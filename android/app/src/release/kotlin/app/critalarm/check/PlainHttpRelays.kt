package app.critalarm.check

/**
 * Hosts a weekly check receipt may reach over plain http.
 *
 * None. This build only ever sends the device token over https. The debug
 * build has its own copy of this file, which is not compiled in here.
 */
object PlainHttpRelays {
    val hosts: Set<String> = emptySet()
}

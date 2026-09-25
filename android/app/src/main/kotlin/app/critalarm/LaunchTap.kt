package app.critalarm

/**
 * The tap a cold start carries, read from the intent once.
 *
 * Reading a tap strips its extras, and FlutterFragmentActivity asks for the
 * initial route twice (once for a log line, once for real), so a route read
 * on demand came back null the second time and the app opened on Home. The
 * route is worked out here, once, and every later ask gets the same answer.
 */
class LaunchTap(read: () -> Map<String, String>?) {
    val tap: Map<String, String>? = read()
    val route: String? = TapRoute.routeFor(tap)
}

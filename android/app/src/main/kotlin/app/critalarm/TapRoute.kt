package app.critalarm

import java.net.URLEncoder

/**
 * The go_router path for a tap, the same mapping Dart's PushDeepLink makes:
 * incident first, then topic, then `open=home` from the open count widget.
 *
 * Pure, so a JVM test can reach it. The escaping matches Dart's
 * `Uri.encodeComponent` and Android's `Uri.encode`.
 */
object TapRoute {
    fun routeFor(tap: Map<String, String>?): String? {
        if (tap == null) return null
        tap[MainActivity.EXTRA_INCIDENT_ID]?.let { return "/incidents/${encode(it)}" }
        tap[MainActivity.EXTRA_TOPIC]?.let { return "/topics/${encode(it)}" }
        if (tap[MainActivity.EXTRA_OPEN] == MainActivity.OPEN_HOME) return "/"
        if (tap[MainActivity.EXTRA_OPEN] == MainActivity.OPEN_PAYWALL) return "/paywall"
        return null
    }

    // API 1 overload. See MinSdkApiTest: the Charset one is API 33.
    private fun encode(value: String): String = URLEncoder.encode(value, "UTF-8")
        .replace("+", "%20")
        .replace("%21", "!")
        .replace("%27", "'")
        .replace("%28", "(")
        .replace("%29", ")")
        .replace("%7E", "~")
}

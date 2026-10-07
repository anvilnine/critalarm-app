package app.critalarm.makersettings

/**
 * One settings page to try, as Dart sends it.
 *
 * [kind] is `component` (another app's activity, by [pkg] and [component]),
 * `action` (a system action) or `appDetails` (this app's own page).
 */
data class MakerSettingsCandidate(
    val kind: String,
    val pkg: String? = null,
    val component: String? = null,
    val action: String? = null,
) {
    companion object {
        /**
         * Reads the list Dart sent. An entry that is not a map, or has no
         * usable fields for its kind, is dropped, so a malformed call can
         * only open less, never crash.
         */
        fun parseAll(raw: Any?): List<MakerSettingsCandidate> {
            val list = raw as? List<*> ?: return emptyList()
            return list.mapNotNull { parse(it) }
        }

        private fun parse(raw: Any?): MakerSettingsCandidate? {
            val map = raw as? Map<*, *> ?: return null
            val kind = map["kind"] as? String ?: return null
            val pkg = map["package"] as? String
            val component = map["component"] as? String
            val action = map["action"] as? String
            return when (kind) {
                "component" ->
                    if (pkg.isNullOrBlank() || component.isNullOrBlank()) null
                    else MakerSettingsCandidate(kind, pkg = pkg, component = component)
                "action" ->
                    if (action.isNullOrBlank()) null
                    else MakerSettingsCandidate(kind, action = action)
                "appDetails" -> MakerSettingsCandidate(kind)
                else -> null
            }
        }
    }
}

/** What the launcher needs from the phone. A fake stands in for it in tests. */
interface MakerSettingsGateway {
    /** True when the system can find an activity for [candidate] right now. */
    fun resolves(candidate: MakerSettingsCandidate): Boolean

    /** Starts [candidate]. May throw; the launcher catches everything. */
    fun start(candidate: MakerSettingsCandidate)
}

/**
 * Opens the first settings page in a list that the phone has.
 *
 * Another maker's settings screen is not ours to count on: the component can
 * be missing on this phone or this version, can refuse to be started from
 * outside, or can throw while it starts. Each candidate is resolved first and
 * then started inside a catch, and a failure moves on to the next one. The
 * app's own page is last in the list Dart sends, and every phone has it.
 */
class MakerSettingsLauncher(private val gateway: MakerSettingsGateway) {

    /**
     * The index of the candidate that opened, or -1 when none did. Never
     * throws.
     */
    fun open(candidates: List<MakerSettingsCandidate>): Int {
        for ((index, candidate) in candidates.withIndex()) {
            try {
                if (!gateway.resolves(candidate)) continue
                gateway.start(candidate)
                return index
            } catch (e: Exception) {
                // Missing, refused or crashed while starting. Try the next.
            }
        }
        return -1
    }
}

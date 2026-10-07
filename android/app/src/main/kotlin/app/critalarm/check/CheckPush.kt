package app.critalarm.check

/**
 * One weekly check push, api.md §5.4.
 *
 * Data only: `kind` is `check`, with the `check_id` the receipt names and the
 * `attempt` of the round, 1 to 3. It carries no server, no incident, no title
 * and no body, and it shows nothing.
 *
 * `check_id` is in the push and nowhere else, so it never goes in a log line.
 * [toString] leaves it out for that reason.
 */
class CheckPush(val checkId: String, val attempt: Int?) {
    override fun toString() = "CheckPush(attempt=$attempt)"

    companion object {
        const val KIND = "check"

        /**
         * Null for every push that is not a weekly check, which is every
         * incident push. A check with no `check_id` cannot be answered, so it
         * is null too and falls through to where an unknown push is dropped.
         */
        fun fromData(data: Map<String, String>): CheckPush? {
            if (data["kind"] != KIND) return null
            val checkId = data["check_id"]?.takeIf(String::isNotEmpty) ?: return null
            return CheckPush(checkId = checkId, attempt = data["attempt"]?.toIntOrNull())
        }
    }
}

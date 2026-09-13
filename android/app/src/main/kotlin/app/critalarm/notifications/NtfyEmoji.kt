package app.critalarm.notifications

/**
 * ntfy's emoji shortcodes, the subset Crit Alarm renders.
 *
 * api.md §1.3: `X-Tags` values that match an emoji shortcode are rendered the
 * way ntfy does it, which is to turn the tag into the emoji and put it in front
 * of the title. Tags that match nothing stay as plain text.
 *
 * Keep this in step with `lib/core/push/ntfy_emoji.dart`.
 */
object NtfyEmoji {
    val shortcodes: Map<String, String> = mapOf(
        "+1" to "👍",
        "-1" to "👎",
        "alarm_clock" to "⏰",
        "ambulance" to "🚑",
        "bangbang" to "‼️",
        "bell" to "🔔",
        "boom" to "💥",
        "bug" to "🐛",
        "building_construction" to "🏗️",
        "chart_with_downwards_trend" to "📉",
        "chart_with_upwards_trend" to "📈",
        "check" to "✔️",
        "computer" to "💻",
        "construction" to "🚧",
        "cd" to "💿",
        "exclamation" to "❗",
        "facepalm" to "🤦",
        "fire" to "🔥",
        "floppy_disk" to "💾",
        "gear" to "⚙️",
        "globe_with_meridians" to "🌐",
        "green_circle" to "🟢",
        "hammer" to "🔨",
        "heavy_check_mark" to "✔️",
        "heavy_exclamation_mark" to "❗",
        "hourglass" to "⌛",
        "information_source" to "ℹ️",
        "key" to "🔑",
        "loudspeaker" to "📢",
        "lock" to "🔒",
        "mag" to "🔍",
        "money_with_wings" to "💸",
        "no_entry" to "⛔",
        "no_entry_sign" to "🚫",
        "orange_circle" to "🟠",
        "package" to "📦",
        "partying_face" to "🥳",
        "phone" to "☎️",
        "question" to "❓",
        "red_circle" to "🔴",
        "robot" to "🤖",
        "rocket" to "🚀",
        "rotating_light" to "🚨",
        "satellite" to "🛰️",
        "skull" to "💀",
        "sos" to "🆘",
        "stopwatch" to "⏱️",
        "tada" to "🎉",
        "triangular_flag_on_post" to "🚩",
        "unlock" to "🔓",
        "warning" to "⚠️",
        "wastebasket" to "🗑️",
        "white_check_mark" to "✅",
        "x" to "❌",
        "yellow_circle" to "🟡",
        "zap" to "⚡",
    )

    fun emojiFor(tag: String): String? = shortcodes[tag.trim().lowercase()]

    /** The emoji tags, then the plain-text ones, in the order they were sent. */
    fun split(tags: List<String>): Pair<List<String>, List<String>> {
        val emoji = mutableListOf<String>()
        val plain = mutableListOf<String>()
        for (tag in tags) {
            val trimmed = tag.trim()
            if (trimmed.isEmpty()) continue
            val match = emojiFor(trimmed)
            if (match == null) plain.add(trimmed) else emoji.add(match)
        }
        return emoji to plain
    }

    /** Title with the emoji tags in front, the way ntfy shows it. */
    fun prefixTitle(title: String, tags: List<String>): String {
        val (emoji, _) = split(tags)
        return if (emoji.isEmpty()) title else emoji.joinToString("") + " " + title
    }
}

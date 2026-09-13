import Foundation

/// ntfy's emoji shortcodes, the subset Crit Alarm renders.
///
/// api.md §1.3 says `X-Tags` values that match an emoji shortcode are
/// "rendered like ntfy": each match turns into the emoji and goes in front of
/// the title, and anything that matches nothing stays plain text. Keep this in
/// step with `lib/core/push/ntfy_emoji.dart` and `NtfyEmoji.kt`.
enum NtfyEmoji {
    static let shortcodes: [String: String] = [
        "+1": "👍",
        "-1": "👎",
        "alarm_clock": "⏰",
        "ambulance": "🚑",
        "bangbang": "‼️",
        "bell": "🔔",
        "boom": "💥",
        "bug": "🐛",
        "building_construction": "🏗️",
        "chart_with_downwards_trend": "📉",
        "chart_with_upwards_trend": "📈",
        "check": "✔️",
        "computer": "💻",
        "construction": "🚧",
        "cd": "💿",
        "exclamation": "❗",
        "facepalm": "🤦",
        "fire": "🔥",
        "floppy_disk": "💾",
        "gear": "⚙️",
        "globe_with_meridians": "🌐",
        "green_circle": "🟢",
        "hammer": "🔨",
        "heavy_check_mark": "✔️",
        "heavy_exclamation_mark": "❗",
        "hourglass": "⌛",
        "information_source": "ℹ️",
        "key": "🔑",
        "loudspeaker": "📢",
        "lock": "🔒",
        "mag": "🔍",
        "money_with_wings": "💸",
        "no_entry": "⛔",
        "no_entry_sign": "🚫",
        "orange_circle": "🟠",
        "package": "📦",
        "partying_face": "🥳",
        "phone": "☎️",
        "question": "❓",
        "red_circle": "🔴",
        "robot": "🤖",
        "rocket": "🚀",
        "rotating_light": "🚨",
        "satellite": "🛰️",
        "skull": "💀",
        "sos": "🆘",
        "stopwatch": "⏱️",
        "tada": "🎉",
        "triangular_flag_on_post": "🚩",
        "unlock": "🔓",
        "warning": "⚠️",
        "wastebasket": "🗑️",
        "white_check_mark": "✅",
        "x": "❌",
        "yellow_circle": "🟡",
        "zap": "⚡",
    ]

    static func emoji(for tag: String) -> String? {
        shortcodes[tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
    }

    /// Title with the emoji tags in front, the way ntfy shows it.
    static func prefixTitle(_ title: String, tags: [String]) -> String {
        let matched = tags.compactMap { NtfyEmoji.emoji(for: $0) }
        return matched.isEmpty ? title : matched.joined() + " " + title
    }
}

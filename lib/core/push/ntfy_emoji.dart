/// ntfy's emoji shortcodes, the subset Crit Alarm renders.
///
/// api.md §1.3 says `X-Tags` values that match an emoji shortcode are "rendered
/// like ntfy". ntfy takes each tag that matches a shortcode, turns it into the
/// emoji and puts it in front of the title; tags that match nothing stay as
/// plain text. This is the lookup table for the first half of that.
abstract final class NtfyEmoji {
  static const Map<String, String> shortcodes = {
    '+1': '👍',
    '-1': '👎',
    'alarm_clock': '⏰',
    'ambulance': '🚑',
    'bangbang': '‼️',
    'bell': '🔔',
    'boom': '💥',
    'bug': '🐛',
    'building_construction': '🏗️',
    'chart_with_downwards_trend': '📉',
    'chart_with_upwards_trend': '📈',
    'check': '✔️',
    'computer': '💻',
    'construction': '🚧',
    'cd': '💿',
    'exclamation': '❗',
    'facepalm': '🤦',
    'fire': '🔥',
    'floppy_disk': '💾',
    'gear': '⚙️',
    'globe_with_meridians': '🌐',
    'green_circle': '🟢',
    'hammer': '🔨',
    'heavy_check_mark': '✔️',
    'heavy_exclamation_mark': '❗',
    'hourglass': '⌛',
    'information_source': 'ℹ️',
    'key': '🔑',
    'loudspeaker': '📢',
    'lock': '🔒',
    'mag': '🔍',
    'money_with_wings': '💸',
    'no_entry': '⛔',
    'no_entry_sign': '🚫',
    'orange_circle': '🟠',
    'package': '📦',
    'partying_face': '🥳',
    'phone': '☎️',
    'question': '❓',
    'red_circle': '🔴',
    'robot': '🤖',
    'rocket': '🚀',
    'rotating_light': '🚨',
    'satellite': '🛰️',
    'skull': '💀',
    'sos': '🆘',
    'stopwatch': '⏱️',
    'tada': '🎉',
    'triangular_flag_on_post': '🚩',
    'unlock': '🔓',
    'warning': '⚠️',
    'wastebasket': '🗑️',
    'white_check_mark': '✅',
    'x': '❌',
    'yellow_circle': '🟡',
    'zap': '⚡',
  };

  /// The emoji for one tag, or null when the tag is plain text.
  static String? emojiFor(String tag) => shortcodes[tag.trim().toLowerCase()];

  /// Splits tags into the emoji ones and the plain-text ones, keeping the
  /// order the publisher sent.
  static NtfyTagRender render(Iterable<String> tags) {
    final emoji = <String>[];
    final rest = <String>[];
    for (final tag in tags) {
      final trimmed = tag.trim();
      if (trimmed.isEmpty) continue;
      final match = emojiFor(trimmed);
      if (match == null) {
        rest.add(trimmed);
      } else {
        emoji.add(match);
      }
    }
    return NtfyTagRender(emoji: emoji, plain: rest);
  }

  /// Title with the emoji tags in front, the way ntfy shows it.
  static String prefixTitle(String title, Iterable<String> tags) {
    final rendered = render(tags);
    if (rendered.emoji.isEmpty) return title;
    return '${rendered.emoji.join()} $title';
  }
}

/// Tags after the split: emoji on one side, plain words on the other.
final class NtfyTagRender {
  const NtfyTagRender({required this.emoji, required this.plain});

  final List<String> emoji;
  final List<String> plain;
}

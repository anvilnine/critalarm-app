import 'package:critalarm/core/push/ntfy_emoji.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('known shortcodes map to emoji', () {
    expect(NtfyEmoji.emojiFor('warning'), '⚠️');
    expect(NtfyEmoji.emojiFor('skull'), '💀');
    expect(NtfyEmoji.emojiFor('rotating_light'), '🚨');
    expect(NtfyEmoji.emojiFor('+1'), '👍');
  });

  test('lookup ignores case and surrounding spaces', () {
    expect(NtfyEmoji.emojiFor('  FiRe  '), '🔥');
  });

  test('a tag that is not a shortcode stays plain', () {
    expect(NtfyEmoji.emojiFor('db01'), isNull);
    expect(NtfyEmoji.emojiFor(''), isNull);
  });

  test('tags split into emoji and plain, keeping their order', () {
    final rendered = NtfyEmoji.render(['warning', 'db01', 'fire', 'prod']);
    expect(rendered.emoji, ['⚠️', '🔥']);
    expect(rendered.plain, ['db01', 'prod']);
  });

  test('empty tags are skipped', () {
    final rendered = NtfyEmoji.render(['', '  ', 'zap']);
    expect(rendered.emoji, ['⚡']);
    expect(rendered.plain, isEmpty);
  });

  test('emoji tags go in front of the title', () {
    expect(
      NtfyEmoji.prefixTitle('Database down', ['warning', 'fire']),
      '⚠️🔥 Database down',
    );
  });

  test('a title with no emoji tags is left alone', () {
    expect(NtfyEmoji.prefixTitle('Database down', ['db01']), 'Database down');
    expect(NtfyEmoji.prefixTitle('Database down', []), 'Database down');
  });

  test('every shortcode maps to a non-empty emoji', () {
    for (final entry in NtfyEmoji.shortcodes.entries) {
      expect(entry.value, isNotEmpty, reason: entry.key);
      expect(entry.key, entry.key.toLowerCase(), reason: entry.key);
    }
  });
}

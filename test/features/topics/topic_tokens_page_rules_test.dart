import 'package:critalarm/core/models/topic_token.dart';
import 'package:critalarm/features/topics/domain/topic_tokens_page_rules.dart';
import 'package:critalarm/features/topics/presentation/cubits/topic_tokens_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tokenMadeLine', () {
    // Local times, so the answer does not depend on the machine's zone.
    final now = DateTime(2026, 10, 9, 14, 30);

    String line(DateTime? at) => tokenMadeLine(
      createdAt: at,
      now: now,
      madeJustNow: 'Made just now',
      madeOn: (when) => 'Made $when',
      yesterday: 'yesterday',
    );

    test('a token with no date from the server was just made', () {
      expect(line(null), 'Made just now');
    });

    test('earlier today is the time', () {
      expect(line(DateTime(2026, 10, 9, 11, 17)), 'Made 11:17');
      expect(line(DateTime(2026, 10, 9, 0, 5)), 'Made 00:05');
    });

    test('a moment ahead of the clock still counts as today', () {
      expect(line(DateTime(2026, 10, 9, 14, 31)), 'Made 14:31');
    });

    test('the day before is the word yesterday', () {
      expect(line(DateTime(2026, 10, 8, 23, 59)), 'Made yesterday');
      expect(line(DateTime(2026, 10, 8, 0, 1)), 'Made yesterday');
    });

    test('an older day is the day and month', () {
      expect(line(DateTime(2026, 10, 7, 9)), 'Made 7 Oct');
      expect(line(DateTime(2026, 1, 2, 9)), 'Made 2 Jan');
    });

    test('a day in another year adds the year', () {
      expect(line(DateTime(2025, 12, 31, 9)), 'Made 31 Dec 2025');
    });
  });

  group('topicTokensPath', () {
    test('the Home branch', () {
      expect(topicTokensPath('/', 'uptime-kuma'), '/topics/uptime-kuma/tokens');
    });

    test('the History branch', () {
      expect(
        topicTokensPath('/history', 'uptime-kuma'),
        '/history/topics/uptime-kuma/tokens',
      );
    });

    test('a base with a trailing slash gives one slash', () {
      expect(
        topicTokensPath('/history/', 'nas'),
        '/history/topics/nas/tokens',
      );
    });

    test('a name that needs encoding stays one segment', () {
      expect(
        topicTokensPath('/', 'my topic/a?b'),
        '/topics/my%20topic%2Fa%3Fb/tokens',
      );
    });

    test('the curl flow adds the query', () {
      expect(
        topicTokensPath('/', 'nas', startCurlFlow: true),
        '/topics/nas/tokens?curl=1',
      );
    });
  });

  group('canRevoke', () {
    TopicTokensState withTokens(int count) => TopicTokensState(
      tokens: [
        for (var i = 0; i < count; i++)
          TopicTokenInfo(tokenId: 'tid_$i', name: 'Token $i'),
      ],
    );

    test('the last token cannot be revoked', () {
      expect(withTokens(1).canRevoke, isFalse);
      expect(withTokens(0).canRevoke, isFalse);
    });

    test('two tokens can', () {
      expect(withTokens(2).canRevoke, isTrue);
    });
  });
}

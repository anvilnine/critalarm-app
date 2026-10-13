import 'package:critalarm/features/paywall/presentation/layouts/previews/topics_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('topicsTagIsLifted', () {
    test('the count shows until the switch goes on, then No limit', () {
      // Seconds in the 12 second loop. See TopicsPreviewTimes.
      final lifted = <double, bool>{
        0.2: true, // resting, switched on
        1.0: false, // off, waiting for the tap
        1.5: false, // refusing
        2.0: false, // refused
        2.6: true, // turning on
        3.5: true, // on
      };
      for (final MapEntry(key: t, value: expected) in lifted.entries) {
        expect(
          topicsTagIsLifted(topicsPreviewFrameAt(t)),
          expected,
          reason: 'at $t s',
        );
      }
    });
  });

  group('topicsPreviewNames with namesTappedRow', () {
    test('the topic they were making is the row that switches on', () {
      expect(
        topicsPreviewNames(3, topicName: 'billing-api', namesTappedRow: true),
        ['prod-db', 'uptime-kuma', 'billing-api'],
      );
      expect(
        topicsPreviewNames(4, topicName: 'billing-api', namesTappedRow: true),
        ['prod-db', 'uptime-kuma', 'billing-api', 'home-ha'],
      );
      expect(
        topicsPreviewNames(2, topicName: 'billing-api', namesTappedRow: true),
        ['uptime-kuma', 'billing-api'],
      );
      expect(
        topicsPreviewNames(1, topicName: 'billing-api', namesTappedRow: true),
        ['billing-api'],
      );
    });

    test('a name the same as a made-up one is not listed twice', () {
      expect(
        topicsPreviewNames(3, topicName: 'prod-db', namesTappedRow: true),
        ['nas-backup', 'uptime-kuma', 'prod-db'],
      );
    });

    test(
      'without the flag the first row takes the name, as the reel needs',
      () {
        expect(
          topicsPreviewNames(3, topicName: 'billing-api'),
          ['billing-api', 'uptime-kuma', 'nas-backup'],
        );
      },
    );

    test('no name leaves the made-up names', () {
      expect(
        topicsPreviewNames(3, namesTappedRow: true),
        ['prod-db', 'uptime-kuma', 'nas-backup'],
      );
    });

    test('the other rows are always the made-up names', () {
      for (final rows in [1, 2, 3, 4]) {
        final names = topicsPreviewNames(
          rows,
          topicName: 'billing-api',
          namesTappedRow: true,
        );
        expect(names, hasLength(rows));
        expect(
          names.where((n) => n != 'billing-api').toSet().difference({
            'prod-db',
            'uptime-kuma',
            'nas-backup',
            'home-ha',
          }),
          isEmpty,
        );
      }
    });
  });

  test('the tag needs both numbers', () {
    expect(const TopicsPreviewOwn(used: 2, limit: 2).hasTag, isTrue);
    expect(const TopicsPreviewOwn(used: 2).hasTag, isFalse);
    expect(const TopicsPreviewOwn(limit: 2).hasTag, isFalse);
    expect(const TopicsPreviewOwn(topicName: 'a').hasTag, isFalse);
  });
}

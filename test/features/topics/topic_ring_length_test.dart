import 'package:critalarm/features/topics/presentation/formatters/topic_ring_length.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('topicRingLengthLine', () {
    test('the defaults: 30 min every 30 s', () {
      expect(
        topicRingLengthLine(maxRingS: 1800, repeatIntervalS: 30),
        "Rings for 30 min, every 30 s, until you're up.",
      );
    });

    test('a 60 s ring is one minute', () {
      expect(
        topicRingLengthLine(maxRingS: 60, repeatIntervalS: 30),
        "Rings for 1 min, every 30 s, until you're up.",
      );
    });

    test('a ring under a minute stays in seconds', () {
      expect(
        topicRingLengthLine(maxRingS: 45, repeatIntervalS: 15),
        "Rings for 45 s, every 15 s, until you're up.",
      );
    });

    test('a 2 h ring is two hours', () {
      expect(
        topicRingLengthLine(maxRingS: 7200, repeatIntervalS: 30),
        "Rings for 2 h, every 30 s, until you're up.",
      );
    });

    test('an hour and a half', () {
      expect(
        topicRingLengthLine(maxRingS: 5400, repeatIntervalS: 60),
        "Rings for 1 h 30 min, every 1 min, until you're up.",
      );
    });

    test('a 90 s interval keeps its seconds', () {
      expect(
        topicRingLengthLine(maxRingS: 1800, repeatIntervalS: 90),
        "Rings for 30 min, every 1 min 30 s, until you're up.",
      );
    });

    test('says nothing for a timer that is unknown or not above zero', () {
      expect(topicRingLengthLine(maxRingS: null, repeatIntervalS: 30), isNull);
      expect(
        topicRingLengthLine(maxRingS: 1800, repeatIntervalS: null),
        isNull,
      );
      expect(topicRingLengthLine(maxRingS: 0, repeatIntervalS: 30), isNull);
      expect(topicRingLengthLine(maxRingS: 1800, repeatIntervalS: 0), isNull);
    });
  });
}

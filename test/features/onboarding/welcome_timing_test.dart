import 'package:critalarm/features/onboarding/domain/welcome_timing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the ring story', () {
    test('the alert has landed within 1 s of launch', () {
      expect(ringStoryAlertLandsAt, closeTo(0.6, 1e-9));
      expect(ringStoryAlertLandsAt, lessThan(1));
    });

    test('the phone rings only after the alert has landed', () {
      expect(ringStoryRingStartsAt, greaterThan(ringStoryAlertLandsAt));
    });

    test('with no tap the first full ring is on screen by 2.5 s', () {
      expect(welcomeFirstRingAt, closeTo(1.4, 1e-9));
      expect(welcomeFirstRingAt, lessThanOrEqualTo(2.5));
    });

    test('with no tap it stops by itself', () {
      expect(ringStoryStopsAt(), ringStoryAutoStopAt);
      expect(ringStoryIsRinging(ringStoryAutoStopAt - 0.01), isTrue);
      expect(ringStoryIsRinging(ringStoryAutoStopAt), isFalse);
    });

    test('a tap stops it at the tap', () {
      expect(ringStoryStopsAt(tappedAt: 2.2), 2.2);
      expect(ringStoryIsRinging(2.19, tappedAt: 2.2), isTrue);
      expect(ringStoryIsRinging(2.2, tappedAt: 2.2), isFalse);
      expect(ringStoryIsRinging(3, tappedAt: 2.2), isFalse);
    });

    test('a tap before it rings, or after it stopped, changes nothing', () {
      expect(ringStoryStopsAt(tappedAt: 0.4), ringStoryAutoStopAt);
      expect(
        ringStoryStopsAt(tappedAt: ringStoryAutoStopAt + 1),
        ringStoryAutoStopAt,
      );
    });

    test('it does not ring before the alarm starts', () {
      expect(ringStoryIsRinging(ringStoryRingStartsAt - 0.01), isFalse);
      expect(ringStoryIsRinging(ringStoryRingStartsAt), isTrue);
    });

    test('the acknowledged screen holds, then the next story starts', () {
      expect(ringStoryEndsAt(), closeTo(6.8, 1e-9));
      expect(ringStoryEndsAt(tappedAt: 2), closeTo(3.8, 1e-9));
    });
  });

  group('the ladder cards', () {
    test('start 0.9 s apart', () {
      expect(ladderCardStartsAt(0), closeTo(0.2, 1e-9));
      expect(ladderCardStartsAt(1), closeTo(1.1, 1e-9));
      expect(ladderCardStartsAt(2), closeTo(2, 1e-9));
    });

    test('are each fully shown 0.45 s after they start', () {
      for (var index = 0; index < ladderCardCount; index++) {
        expect(
          ladderCardShownAt(index) - ladderCardStartsAt(index),
          closeTo(0.45, 1e-9),
        );
      }
    });

    test('each one has landed before the next starts', () {
      for (var index = 0; index < ladderCardCount - 1; index++) {
        expect(
          ladderCardShownAt(index),
          lessThan(ladderCardStartsAt(index + 1)),
        );
      }
    });

    test('the last one rings only after it has landed', () {
      expect(ladderRingStartsAt, greaterThan(ladderCardShownAt(2)));
      expect(ladderRingStartsAt, lessThan(ladderRingEndsAt));
    });

    test('the story ends after the last card is acknowledged', () {
      expect(ladderStoryTakes, greaterThan(ladderRingEndsAt + 1));
    });
  });

  group('the tools story', () {
    test('each tool sends 1.3 s after the one before', () {
      expect(toolsSendStartsAt(0), closeTo(0.6, 1e-9));
      expect(toolsSendStartsAt(1), closeTo(1.9, 1e-9));
      expect(toolsSendStartsAt(2), closeTo(3.2, 1e-9));
    });

    test('an alert lands 0.7 s after it was sent', () {
      for (var index = 0; index < toolsStoryToolCount; index++) {
        expect(
          toolsAlertLandsAt(index) - toolsSendStartsAt(index),
          closeTo(0.7, 1e-9),
        );
      }
    });

    test('one alert is in flight at a time', () {
      for (var index = 0; index < toolsStoryToolCount - 1; index++) {
        expect(
          toolsAlertLandsAt(index),
          lessThan(toolsSendStartsAt(index + 1)),
        );
      }
    });

    test('the story holds on all three alerts before it ends', () {
      expect(
        toolsStoryTakes,
        greaterThan(toolsAlertLandsAt(toolsStoryToolCount - 1) + 2),
      );
    });
  });
}

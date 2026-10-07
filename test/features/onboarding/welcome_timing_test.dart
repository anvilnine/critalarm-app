import 'package:critalarm/features/onboarding/domain/welcome_timing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the ladder cards', () {
    test('start 0.25 s apart', () {
      expect(ladderCardStartsAt(0), 0);
      expect(ladderCardStartsAt(1), closeTo(0.25, 1e-9));
      expect(ladderCardStartsAt(2), closeTo(0.5, 1e-9));
    });

    test('are each fully shown 0.45 s after they start', () {
      for (var index = 0; index < ladderCardCount; index++) {
        expect(
          ladderCardShownAt(index) - ladderCardStartsAt(index),
          closeTo(0.45, 1e-9),
        );
      }
    });

    test('the last one rings only after it has landed', () {
      expect(ladderRingStartsAt, greaterThan(ladderCardShownAt(2)));
      expect(ladderRingStartsAt, lessThan(ladderRingEndsAt));
    });
  });

  group('the wake', () {
    test('with no tap the face wakes itself after 1 s', () {
      expect(welcomeWokeAt(), 1);
    });

    test('a tap wakes it at the tap', () {
      expect(welcomeWokeAt(tappedAt: 0), 0);
      expect(welcomeWokeAt(tappedAt: 0.4), 0.4);
    });

    test('a tap after it woke itself changes nothing', () {
      expect(welcomeWokeAt(tappedAt: 1.7), 1);
    });

    test('the hop is over before the ladder starts', () {
      expect(welcomeWakeHopTakes, lessThanOrEqualTo(welcomeWakeTakes));
    });
  });

  group('first launch', () {
    test('the ladder starts as soon as the face is awake', () {
      expect(welcomeLadderStartsAt(), closeTo(1.5, 1e-9));
      expect(welcomeLadderStartsAt(tappedAt: 0.2), closeTo(0.7, 1e-9));
    });

    test('with no tap the third card is fully shown by 2.6 s', () {
      expect(welcomeCardShownAt(2), closeTo(2.45, 1e-9));
      expect(welcomeCardShownAt(2), lessThanOrEqualTo(2.6));
    });

    test('a tap brings every card forward by the time it saved', () {
      for (var index = 0; index < ladderCardCount; index++) {
        expect(
          welcomeCardShownAt(index) - welcomeCardShownAt(index, tappedAt: 0.3),
          closeTo(0.7, 1e-9),
        );
      }
    });
  });
}

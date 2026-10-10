import 'package:critalarm/features/onboarding/domain/welcome_timing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}

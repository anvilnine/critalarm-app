import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/features/topics/domain/topic_made_beat.dart';
import 'package:flutter_test/flutter_test.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);

void main() {
  group('the times', () {
    test('the beat is appear, drop and hold, 1.2 s in all', () {
      expect(
        topicCardAppearTakes + topicCardDropTakes + topicMadeHoldTakes,
        topicMadeBeatTakes,
      );
      expect(topicMadeBeatTakes, _ms(1200));
    });

    test('the moves take design system times', () {
      expect(topicCardAppearTakes, AppDurations.quick);
      expect(topicCardDropTakes, AppDurations.slow);
    });

    test('the card lands during the drop, before the hold', () {
      expect(topicCardLandsAt, greaterThan(topicCardAppearTakes));
      expect(
        topicCardLandsAt,
        lessThan(topicCardAppearTakes + topicCardDropTakes),
      );
    });

    test('the still picture is a short beat, shorter than the moving one', () {
      expect(topicMadeStillTakes, greaterThan(Duration.zero));
      expect(topicMadeStillTakes, lessThan(topicMadeBeatTakes));
    });
  });

  group('the card', () {
    test('fades in first and has not moved yet', () {
      expect(topicCardShownAt(Duration.zero), 0);
      expect(topicCardShownAt(_ms(75)), closeTo(0.5, 1e-9));
      expect(topicCardShownAt(_ms(150)), 1);
      expect(topicCardDropAt(_ms(150)), 0);
    });

    test('then drops, and stays put through the hold', () {
      expect(topicCardDropAt(_ms(350)), closeTo(0.5, 1e-9));
      expect(topicCardDropAt(_ms(550)), 1);
      expect(topicCardDropAt(_ms(1200)), 1);
      expect(topicCardShownAt(_ms(1200)), 1);
    });

    test('never leaves 0 to 1, before the start or after the end', () {
      expect(topicCardShownAt(_ms(-50)), 0);
      expect(topicCardDropAt(_ms(-50)), 0);
      expect(topicCardDropAt(_ms(5000)), 1);
    });
  });

  group('the landing tap', () {
    test('is felt in the one frame that crosses the landing', () {
      expect(topicCardLandsBetween(_ms(380), _ms(396)), isTrue);
      expect(topicCardLandsBetween(_ms(364), _ms(380)), isFalse);
      expect(topicCardLandsBetween(_ms(396), _ms(412)), isFalse);
    });

    test('is felt once over a whole run of frames', () {
      var taps = 0;
      var last = Duration.zero;
      for (var ms = 16; ms <= 1200; ms += 16) {
        if (topicCardLandsBetween(last, _ms(ms))) taps++;
        last = _ms(ms);
      }
      expect(taps, 1);
    });

    test('a frame that ends exactly on the landing counts, the next not', () {
      expect(topicCardLandsBetween(_ms(374), topicCardLandsAt), isTrue);
      expect(topicCardLandsBetween(topicCardLandsAt, _ms(406)), isFalse);
    });
  });

  group('the picture size', () {
    test('is its full width on a tall phone', () {
      expect(
        topicMadePictureWidthFor(roomWidth: 345, viewportHeight: 852),
        topicMadePictureMaxWidth,
      );
    });

    test('fits a 667-high phone with room left for the bar and the line', () {
      final width = topicMadePictureWidthFor(
        roomWidth: 327,
        viewportHeight: 667,
      );
      final height =
          width * topicMadePictureDesignHeight / topicMadePictureDesignWidth;
      expect(width, lessThanOrEqualTo(327));
      expect(height, lessThanOrEqualTo(667 * 0.62 + 1e-9));
      // Still big enough to read the topic name.
      expect(width, greaterThan(280));
    });

    test('never asks for more width than there is', () {
      expect(
        topicMadePictureWidthFor(roomWidth: 240, viewportHeight: 852),
        240,
      );
      expect(topicMadePictureWidthFor(roomWidth: -10, viewportHeight: 852), 0);
    });
  });
}

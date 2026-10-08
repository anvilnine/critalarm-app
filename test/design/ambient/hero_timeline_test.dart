import 'package:critalarm/design/ambient/hero_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('heroTimeline', () {
    test('second zero is the resting frame', () {
      expect(heroTimeline(0), heroRestFrame);
    });

    test('the disc breathes 3.5 percent over 9 seconds', () {
      expect(heroTimeline(4.5).discScale, closeTo(1.035, 1e-9));
      expect(heroTimeline(9).discScale, closeTo(1, 1e-9));
      expect(heroTimeline(2.25).discScale, inExclusiveRange(1, 1.035));
    });

    test('the ring starts its breath 1.2 seconds after the disc', () {
      expect(heroTimeline(1.2).ringScale, closeTo(1, 1e-9));
      expect(heroTimeline(1.2 + 4.5).ringScale, closeTo(1.035, 1e-9));
      expect(heroTimeline(1).ringScale, 1);
      // At 4.5 s the disc is at the top and the ring is still on its way.
      expect(
        heroTimeline(4.5).ringScale,
        lessThan(heroTimeline(4.5).discScale),
      );
    });

    test('the first dot floats 9 points over 7 seconds', () {
      expect(heroTimeline(3.5).firstDotRise, closeTo(9, 1e-9));
      expect(heroTimeline(7).firstDotRise, closeTo(0, 1e-9));
    });

    test('the second dot waits 3.4 seconds and then floats', () {
      expect(heroTimeline(3.3).secondDotRise, 0);
      expect(heroTimeline(3.4 + 3.5).secondDotRise, closeTo(9, 1e-9));
    });

    test('the face bobs 3 points over 3.8 seconds', () {
      expect(heroTimeline(1.9).faceRise, closeTo(3, 1e-9));
      expect(heroTimeline(3.8).faceRise, closeTo(0, 1e-9));
    });

    test('every loop wraps: a later second repeats an earlier one', () {
      // 9, 7 and 3.8 share a multiple at 1197 seconds, and the blink cycle
      // is 19 seconds.
      final a = heroTimeline(5.3);
      final b = heroTimeline(5.3 + 1197);
      expect(b.discScale, closeTo(a.discScale, 1e-6));
      expect(b.firstDotRise, closeTo(a.firstDotRise, 1e-6));
      expect(b.faceRise, closeTo(a.faceRise, 1e-6));
    });

    test('nothing leaves its range at any second', () {
      for (var t = 0.0; t < 120; t += 0.07) {
        final f = heroTimeline(t);
        expect(f.discScale, inInclusiveRange(1, 1.035 + 1e-9));
        expect(f.ringScale, inInclusiveRange(1, 1.035 + 1e-9));
        expect(f.firstDotRise, inInclusiveRange(0, 9 + 1e-9));
        expect(f.secondDotRise, inInclusiveRange(0, 9 + 1e-9));
        expect(f.faceRise, inInclusiveRange(0, 3 + 1e-9));
        expect(f.blink, inInclusiveRange(0, 1));
      }
    });
  });

  group('heroBlink', () {
    test('the opening seconds are open', () {
      expect(heroBlink(0), 0);
      expect(heroBlink(1.5), 0);
      expect(heroBlink(2.79), 0);
    });

    test('the first blink lands at the first gap and shuts at its middle', () {
      expect(heroBlink(2.8 + heroBlinkSeconds / 2), closeTo(1, 1e-9));
      expect(heroBlink(2.8 + heroBlinkSeconds + 0.01), 0);
    });

    test('the gaps are not all the same', () {
      expect(heroBlinkGaps.toSet().length, greaterThan(1));
    });

    test('the pattern repeats after one cycle', () {
      final cycle = heroBlinkGaps.reduce((a, b) => a + b);
      expect(
        heroBlink(2.8 + 0.05 + cycle),
        closeTo(heroBlink(2.8 + 0.05), 1e-9),
      );
    });

    test('a blink is shorter than every gap', () {
      for (final gap in heroBlinkGaps) {
        expect(heroBlinkSeconds, lessThan(gap));
      }
    });
  });

  group('heroGlance', () {
    test('is zero before it starts and after it ends', () {
      expect(heroGlance(-1), 0);
      expect(heroGlance(0), 0);
      expect(heroGlance(heroGlanceSeconds), 0);
      expect(heroGlance(heroGlanceSeconds + 5), 0);
    });

    test('holds on the list for 1500 ms', () {
      expect(heroGlance(heroGlanceInSeconds), 1);
      expect(heroGlance(heroGlanceInSeconds + 0.75), 1);
      expect(
        heroGlance(heroGlanceInSeconds + heroGlanceHoldSeconds - 0.001),
        1,
      );
      expect(heroGlanceHoldSeconds, 1.5);
    });

    test('slides out and back without jumping', () {
      var last = 0.0;
      for (var s = 0.0; s < heroGlanceSeconds; s += 0.01) {
        final g = heroGlance(s);
        expect((g - last).abs(), lessThan(0.12));
        last = g;
      }
    });
  });
}

import 'package:critalarm/features/settings/presentation/personalize/widgets/widgets_ring_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('widgetsRingAngle', () {
    test('is upright before the first ring', () {
      for (final t in [0.0, 0.2, widgetsRingBegin]) {
        expect(widgetsRingAngle(t), closeTo(0, 1e-9), reason: 't = $t');
      }
    });

    test('rings twice, one second each, with a gap between', () {
      expect(widgetsRingCount, 2);
      expect(widgetsRingLength, 1);
      const firstEnd = widgetsRingBegin + widgetsRingLength;
      const secondStart = firstEnd + widgetsRingGap;
      expect(widgetsRingEnd, closeTo(secondStart + widgetsRingLength, 1e-9));
      // Moving inside each ring.
      expect(widgetsRingAngle(widgetsRingBegin + 0.2).abs(), greaterThan(1));
      expect(widgetsRingAngle(secondStart + 0.2).abs(), greaterThan(1));
      // Upright in the gap.
      expect(widgetsRingAngle(firstEnd + widgetsRingGap / 2), 0);
    });

    test('both rings are the same', () {
      const gap = widgetsRingLength + widgetsRingGap;
      for (final dt in [0.1, 0.3, 0.55, 0.8]) {
        expect(
          widgetsRingAngle(widgetsRingBegin + dt),
          closeTo(widgetsRingAngle(widgetsRingBegin + gap + dt), 1e-9),
        );
      }
    });

    test('starts and ends each ring upright, so it never snaps', () {
      for (var i = 0; i < widgetsRingCount; i++) {
        final start =
            widgetsRingBegin + i * (widgetsRingLength + widgetsRingGap);
        expect(widgetsRingAngle(start), closeTo(0, 1e-9));
        expect(widgetsRingAngle(start + widgetsRingLength), closeTo(0, 1e-9));
      }
    });

    test('never turns more than 5 degrees either side of upright', () {
      var most = 0.0;
      for (var t = 0.0; t < 4; t += 0.005) {
        final angle = widgetsRingAngle(t).abs();
        if (angle > most) most = angle;
      }
      expect(most, lessThanOrEqualTo(widgetsRingDegrees));
      // And reaches most of it: it is a ring, not a twitch.
      expect(most, greaterThan(widgetsRingDegrees * 0.8));
    });

    test('swings both ways', () {
      var hasPositive = false;
      var hasNegative = false;
      for (var t = widgetsRingBegin; t < widgetsRingBegin + 1; t += 0.01) {
        final angle = widgetsRingAngle(t);
        if (angle > 0.5) hasPositive = true;
        if (angle < -0.5) hasNegative = true;
      }
      expect(hasPositive && hasNegative, isTrue);
    });

    test('rests upright after the second ring, for good', () {
      for (final t in [widgetsRingEnd, widgetsRingEnd + 0.01, 5.0, 60.0]) {
        expect(widgetsRingAngle(t), closeTo(0, 1e-9), reason: 't = $t');
      }
    });

    test('the resting frame is upright at any second', () {
      for (final t in [0.0, widgetsRingBegin + 0.2, widgetsRingBegin + 0.7]) {
        expect(widgetsRingAngle(t, isStill: true), 0);
      }
    });
  });
}

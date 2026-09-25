import 'dart:math' as math;

import 'package:critalarm/design/faces/faces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final a = RingingFrame(
    face: calmFace,
    tilt: 0.2,
    nudge: const Offset(4, -2),
    scale: 1.1,
    flush: 1,
    spin: 1,
    fx: const [RingFx(RingFxKind.sweat, alpha: 0.8)],
  );
  final b = RingingFrame(
    face: alarmedFace,
    tilt: -0.4,
    nudge: const Offset(-6, 8),
    scale: 0.9,
    flash: 1,
    spin: 3,
    fx: const [RingFx(RingFxKind.star)],
  );

  group('RingingFrame.lerp', () {
    test('at 0 draws the first frame', () {
      final f = RingingFrame.lerp(a, b, 0);
      expect(f.tilt, 0.2);
      expect(f.nudge, const Offset(4, -2));
      expect(f.scale, 1.1);
      expect(f.flush, 1);
      expect(f.flash, 0);
      expect(f.spin, 1);
    });

    test('at 1 draws the second frame', () {
      final f = RingingFrame.lerp(a, b, 1);
      expect(f.tilt, closeTo(-0.4, 1e-9));
      expect(f.nudge, const Offset(-6, 8));
      expect(f.scale, closeTo(0.9, 1e-9));
      expect(f.flush, 0);
      expect(f.flash, 1);
      expect(f.spin, 3);
    });

    test('halfway blends the numbers', () {
      final f = RingingFrame.lerp(a, b, 0.5);
      expect(f.tilt, closeTo(-0.1, 1e-9));
      expect(f.nudge, const Offset(-1, 3));
      expect(f.scale, closeTo(1, 1e-9));
      expect(f.flush, 0.5);
      expect(f.flash, 0.5);
      expect(f.spin, 2);
    });

    test('fades the first extras out while the second fade in', () {
      final f = RingingFrame.lerp(a, b, 0.25);
      expect(f.fx.map((fx) => fx.kind), [RingFxKind.sweat, RingFxKind.star]);
      expect(f.fx[0].alpha, closeTo(0.6, 1e-9));
      expect(f.fx[1].alpha, closeTo(0.25, 1e-9));
    });
  });

  group('nextRingingStyle', () {
    test('never picks the style already showing', () {
      for (var seed = 0; seed < 200; seed++) {
        for (final current in RingingStyle.values) {
          expect(
            nextRingingStyle(current, math.Random(seed)),
            isNot(current),
          );
        }
      }
    });

    test('can reach every other style', () {
      final random = math.Random(1);
      final seen = <RingingStyle>{
        for (var i = 0; i < 2000; i++)
          nextRingingStyle(RingingStyle.classic, random),
      };
      expect(seen, RingingStyle.values.toSet()..remove(RingingStyle.classic));
    });
  });
}

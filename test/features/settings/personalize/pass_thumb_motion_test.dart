import 'dart:math' as math;

import 'package:critalarm/features/settings/presentation/personalize/passes/pass_thumb_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('passThumbRock', () {
    test('is upright at t = 0', () {
      expect(passThumbRock(0), 0);
    });

    test('swings 4 degrees either side of upright, the same both ways', () {
      expect(passThumbRock(passThumbRockPeriod / 4), closeTo(4, 1e-9));
      expect(passThumbRock(3 * passThumbRockPeriod / 4), closeTo(-4, 1e-9));
    });

    test('is symmetric: the same distance either side of the middle of the '
        'swing', () {
      for (final t in [0.1, 0.2, 0.3, 0.45, 0.55]) {
        expect(passThumbRock(t), closeTo(-passThumbRock(-t), 1e-9));
        expect(
          passThumbRock(t),
          closeTo(passThumbRock(passThumbRockPeriod / 2 - t), 1e-9),
        );
      }
    });

    test('repeats every 1.2 seconds and comes back to upright', () {
      expect(passThumbRockPeriod, 1.2);
      for (final t in [0.0, 0.17, 0.5, 0.9]) {
        expect(
          passThumbRock(t + passThumbRockPeriod),
          closeTo(passThumbRock(t), 1e-9),
        );
      }
      expect(passThumbRock(passThumbRockPeriod), closeTo(0, 1e-9));
      expect(passThumbRock(passThumbRockPeriod / 2), closeTo(0, 1e-9));
    });

    test('never passes 4 degrees', () {
      for (var t = 0.0; t < 3; t += 0.01) {
        expect(passThumbRock(t).abs(), lessThanOrEqualTo(4 + 1e-9));
      }
    });

    test('the resting frame is upright at any clock', () {
      for (final t in [0.0, 0.3, 5.7]) {
        expect(passThumbRock(t, isStill: true), 0);
      }
    });
  });

  group('passBarScale', () {
    test('stays between 0.5 and 1 for every bar at every moment', () {
      for (var i = 0; i < passBarCount; i++) {
        for (var t = 0.0; t < 4; t += 0.013) {
          final scale = passBarScale(i, t);
          expect(scale, inInclusiveRange(0.5 - 1e-9, 1 + 1e-9));
        }
      }
    });

    test('reaches both ends of the range', () {
      var low = 1.0;
      var high = 0.0;
      for (var t = 0.0; t < 2; t += 0.005) {
        final scale = passBarScale(0, t);
        low = math.min(low, scale);
        high = math.max(high, scale);
      }
      expect(low, closeTo(0.5, 1e-3));
      expect(high, closeTo(1, 1e-3));
    });

    test('repeats every second', () {
      for (var i = 0; i < passBarCount; i++) {
        expect(
          passBarScale(i, 0.37 + passBarPeriod),
          closeTo(passBarScale(i, 0.37), 1e-9),
        );
      }
    });

    test('the delays are 0.15 s on every second bar and 0.3 s on every third '
        '(a bar that is both takes 0.3 s)', () {
      expect(
        [for (var i = 0; i < passBarCount; i++) passBarDelay(i)],
        [
          0, // 1st
          0.15, // 2nd
          0.3, // 3rd
          0.15, // 4th
          0, // 5th
          0.3, // 6th, both: the third wins
          0, // 7th
          0.15, // 8th
        ],
      );
    });

    test('a delayed bar is the same wave, later', () {
      expect(
        passBarScale(1, 0.15 + 0.2),
        closeTo(passBarScale(0, 0.2), 1e-9),
      );
      expect(
        passBarScale(2, 0.3 + 0.2),
        closeTo(passBarScale(0, 0.2), 1e-9),
      );
    });

    test('the resting frame is every bar at full height', () {
      for (var i = 0; i < passBarCount; i++) {
        expect(passBarScale(i, 0.123, isStill: true), 1);
      }
    });
  });

  group('passBarHeights', () {
    test('eight bars from the peaks, the loudest at the ceiling', () {
      final peaks = [for (var i = 0; i < 48; i++) i < 24 ? 0.2 : 0.8];
      final heights = passBarHeights(peaks);
      expect(heights, hasLength(passBarCount));
      expect(heights.reduce(math.max), closeTo(passBarCeiling, 1e-9));
      expect(heights.first, lessThan(heights.last));
      for (final height in heights) {
        expect(height, inInclusiveRange(passBarFloor, passBarCeiling));
      }
    });

    test('a sound with no peaks gets flat low bars that do not move', () {
      for (final peaks in <List<double>?>[
        null,
        const [],
        const [0.5, 0.5],
      ]) {
        expect(
          passBarHeights(peaks),
          List<double>.filled(passBarCount, passBarFloor),
        );
        expect(passBarsMove(peaks), isFalse);
      }
    });

    test('a silent sound is flat too', () {
      expect(
        passBarHeights(List<double>.filled(48, 0)),
        List<double>.filled(passBarCount, passBarFloor),
      );
    });

    test('real peaks move', () {
      expect(passBarsMove(List<double>.filled(48, 0.5)), isTrue);
    });
  });
}

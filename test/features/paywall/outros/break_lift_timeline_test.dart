import 'dart:math' as math;
import 'dart:ui';

import 'package:critalarm/core/paywall/paywall_outro.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_outro_registry.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tile.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift/break_lift_outro.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift/break_lift_timeline.dart';
import 'package:critalarm/features/paywall/presentation/outros/break_lift_ring/break_lift_ring_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

typedef T = BreakLiftTimeline;

const _screens = [Size(390, 844), Size(375, 667)];
const double _frame = 1 / 120;

Rect _landFor(Size size) => Rect.fromCenter(
  center: Offset(size.width / 2, size.height * 0.28),
  width: 174,
  height: 174,
);

Rect _mascotFor(Size size) => Rect.fromCenter(
  center: Offset(size.width / 2, 300),
  width: 120,
  height: 120,
);

BreakLiftRingPose _pose(double t, Size size, {Rect? mascot}) =>
    T.pose(t, size: size, land: _landFor(size), mascot: mascot);

/// Each series is one number that moves with the clock.
Map<String, double Function(double t, Size size)> _series() => {
  'crit x': (t, s) => _pose(t, s, mascot: _mascotFor(s)).centre.dx,
  'crit y': (t, s) => _pose(t, s, mascot: _mascotFor(s)).centre.dy,
  'crit width': (t, s) => _pose(t, s, mascot: _mascotFor(s)).box.width,
  'crit height': (t, s) => _pose(t, s, mascot: _mascotFor(s)).box.height,
  'crit angle': (t, s) => _pose(t, s).angle * 100,
  'night': (t, s) => T.night(t) * 100,
  'words': (t, s) => T.wordsAlpha(t) * 100,
  'trail alpha': (t, s) => T.trailAlpha(t) * 100,
  'trail length': (t, s) => T.trailLength(t, s),
  for (var i = 0; i < T.stars.length; i++)
    'star $i y': (t, s) => T.starAt(i, t, s).dy,
  for (final i in [0, 7, 21, 40, 55])
    ...() {
      final pieces = T.pieces(const Size(390, 844));
      return {
        'piece $i x': (double t, Size s) =>
            T.flightOf(pieces[i], t, k: 1).shift.dx,
        'piece $i y': (double t, Size s) =>
            T.flightOf(pieces[i], t, k: 1).shift.dy,
        'piece $i scale': (double t, Size s) =>
            T.flightOf(pieces[i], t, k: 1).scale * 10,
        'piece $i alpha': (double t, Size s) =>
            T.flightOf(pieces[i], t, k: 1).alpha * 100,
      };
    }(),
};

void _expectBox(Rect a, Rect b) {
  expect(a.left, closeTo(b.left, 1e-9));
  expect(a.top, closeTo(b.top, 1e-9));
  expect(a.right, closeTo(b.right, 1e-9));
  expect(a.bottom, closeTo(b.bottom, 1e-9));
}

void main() {
  test('the beats are in order and the uncover comes before the swap', () {
    final marks = [0, T.hit, T.liftFrom, T.liftTo, T.uncover, T.end];
    expect(marks, orderedEquals([...marks]..sort()));
    expect(T.hit, 0.36);
    expect(T.liftFrom, 0.9);
    expect(T.liftTo, 2.4);
    expect(T.uncover, 2.6);
    expect(T.end, 2.8);
  });

  group('smoothness from the lift on', () {
    for (final size in _screens) {
      test(
        'nothing steps on ${size.width.toInt()} x ${size.height.toInt()}',
        () {
          _series().forEach((name, value) {
            var previous = value(T.liftFrom, size);
            var lastStep = 0.0;
            var first = true;
            for (var i = 1; T.liftFrom + i * _frame <= T.end + 1e-9; i++) {
              final t = T.liftFrom + i * _frame;
              final now = value(t, size);
              final step = now - previous;
              expect(
                step.abs(),
                lessThan(3),
                reason: '$name moves $step at $t',
              );
              // An eased number changes its pace a little from one frame to
              // the next. A jump or a start from rest does not.
              if (!first) {
                expect(
                  (step - lastStep).abs(),
                  lessThan(0.25),
                  reason: '$name changes pace by ${step - lastStep} at $t',
                );
              }
              first = false;
              lastStep = step;
              previous = now;
            }
          });
        },
      );
    }

    test('the rise is one ease, fastest in the middle', () {
      expect(T.lift(T.liftFrom), 0);
      expect(T.lift(T.liftTo), 1);
      expect(T.lift(1.65), closeTo(0.5, 1e-9));
      var last = -1.0;
      for (var t = 0.0; t <= T.end; t += _frame) {
        final lift = T.lift(t);
        expect(lift, greaterThanOrEqualTo(last));
        last = lift;
      }
    });
  });

  group('Crit', () {
    for (final size in _screens) {
      test('is whole inside ${size.width}x${size.height} every 0.05 s', () {
        final screen = Offset.zero & size;
        for (final mascot in <Rect?>[_mascotFor(size), null]) {
          for (var i = 0; i <= 56; i++) {
            final t = i * 0.05;
            final box = _pose(t, size, mascot: mascot).turnedBox;
            expect(
              screen.contains(box.topLeft) && screen.contains(box.bottomRight),
              isTrue,
              reason: 't=$t box=$box mascot=$mascot',
            );
          }
        }
      });

      test('at the end he is exactly on land, upright and unsquashed', () {
        for (final mascot in <Rect?>[_mascotFor(size), null]) {
          final land = _landFor(size);
          final pose = _pose(T.end, size, mascot: mascot);
          _expectBox(pose.box, land);
          expect(pose.angle, 0);
          expect(pose.squashX, 1);
          // He is already there when the end state starts to open.
          final settled = _pose(T.liftTo, size, mascot: mascot);
          _expectBox(settled.box, land);
          expect(settled.angle, 0);
        }
      });
    }

    test('the first frame is the layout: Crit on the mascot', () {
      const size = Size(390, 844);
      final mascot = _mascotFor(size);
      final pose = _pose(0, size, mascot: mascot);
      expect(pose.centre.dx, closeTo(mascot.center.dx, 0.001));
      expect(pose.centre.dy, closeTo(mascot.center.dy, 0.001));
    });

    test('the wind up is the one Break, lift, ring has', () {
      const size = Size(390, 844);
      for (var t = 0.0; t < T.hit; t += 0.03) {
        final mine = _pose(t, size);
        final ring = BreakLiftRingTimeline.pose(
          t,
          size: size,
          land: _landFor(size),
        );
        expect(mine.box, ring.box);
        expect(mine.angle, ring.angle);
      }
    });

    test('he does not jump at the hit', () {
      const size = Size(390, 844);
      final before = _pose(T.hit - 0.001, size);
      final after = _pose(T.hit, size);
      expect((before.centre - after.centre).distance, lessThan(2));
      expect((before.size - after.size).abs(), lessThan(3));
    });
  });

  group('less stimulating', () {
    test('no frame changes more than a third of the screen', () {
      // What the screen is, as the share of the way from the paywall's light
      // to the night, then back to the end state under the fade.
      double screen(double t) => T.night(t) * (1 - T.fadeOut(t));
      const frame = 1 / 60;
      var worst = 0.0;
      for (var t = T.hit; t + frame <= T.end; t += frame) {
        worst = math.max(worst, (screen(t + frame) - screen(t)).abs());
      }
      expect(worst, lessThan(1 / 3));
      // The fade to the end state is the quickest change, and it is gentle.
      expect(
        T.fadeOut(T.uncover + frame) - T.fadeOut(T.uncover),
        lessThan(0.1),
      );
    });

    test('nothing blinks: every piece fades out and stays out', () {
      final pieces = T.pieces(const Size(390, 844));
      for (final piece in pieces) {
        var last = 1.0;
        for (var t = T.hit; t <= T.end; t += _frame) {
          final alpha = T.flightOf(piece, t, k: 1).alpha;
          expect(alpha, lessThanOrEqualTo(last + 1e-12));
          last = alpha;
        }
        expect(last, 0);
      }
    });

    test('the stars do not twinkle and slide at their own rate', () {
      const size = Size(390, 844);
      for (var i = 0; i < T.stars.length; i++) {
        expect(
          T.starAt(i, 1.2, size).dx,
          T.starAt(i, 2.3, size).dx,
        );
        expect(
          T.starAt(i, 2.3, size).dy,
          greaterThan(T.starAt(i, 1.2, size).dy),
        );
      }
      expect({for (final star in T.stars) star.slide}.length, greaterThan(1));
    });

    test('the welcome line fades in and out once, whole', () {
      expect(T.wordsAlpha(1.45), 0);
      expect(T.wordsAlpha(T.wordsTo), closeTo(0, 1e-9));
      expect(T.wordsAlpha(0), 0);
      expect(T.wordsAlpha(T.end), 0);
      var peaks = 0;
      var last = 0.0;
      var rising = true;
      for (var t = 0.0; t <= T.end; t += _frame) {
        final alpha = T.wordsAlpha(t);
        if (rising && alpha < last - 1e-12) {
          peaks++;
          rising = false;
        }
        if (!rising && alpha > last + 1e-12) rising = true;
        last = alpha;
      }
      expect(peaks, 1);
      expect(
        [for (var t = 0.0; t <= T.end; t += _frame) T.wordsAlpha(t)].reduce(
          math.max,
        ),
        1,
      );
    });

    test('the night is on before Crit has arrived and is gone at the swap', () {
      expect(T.night(T.hit), 0);
      expect(T.night(T.liftTo), 1);
      expect(T.fadeOut(T.uncover), 0);
      expect(T.fadeOut(T.end), 1);
    });
  });

  group('the outro', () {
    test('is sound, with the two taps and no score', () {
      expect(breakLift.isSound, isTrue);
      expect(breakLift.seconds, T.end);
      expect(breakLift.uncover, T.uncover);
      expect(breakLift.score, isNull);
      expect(breakLift.scoreSeconds, 0);
      expect(breakLift.beats.map((b) => b.at), [T.hit, 2.4]);
      expect(
        breakLift.beats.map((b) => b.haptic),
        [HapticPattern.light, HapticPattern.light],
      );
    });

    test('its id parses from its key, has a name and is registered', () {
      expect(PaywallOutroId.breakLift.key, 'break_lift');
      expect(PaywallOutroId.fromKey('break_lift'), PaywallOutroId.breakLift);
      expect(PaywallOutroId.parse('break_lift'), PaywallOutroId.breakLift);
      expect(paywallOutroNameKey(PaywallOutroId.breakLift), isNotEmpty);
      expect(
        paywallOutroNameKey(PaywallOutroId.breakLift),
        isNot(paywallOutroNameKey(PaywallOutroId.breakLiftRing)),
      );
      expect(paywallOutroIsBuilt(PaywallOutroId.breakLift), isTrue);
      expect(paywallOutroBuilders[PaywallOutroId.breakLift], breakLift);
    });
  });
}

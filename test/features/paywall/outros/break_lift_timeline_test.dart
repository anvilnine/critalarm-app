import 'dart:math' as math;
import 'dart:ui';

import 'package:critalarm/core/paywall/paywall_outro.dart';
import 'package:critalarm/core/ui_sound/paywall_cues.dart';
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
  'plume alpha': (t, s) => T.plumeAlpha(t) * 100,
  'plume width': T.plumeWidth,
  'plume length': T.plumeLength,
  'plume sway': T.plumeSway,
  'crit squash x': (t, s) => _pose(t, s).squashX * 100,
  'crit squash y': (t, s) => _pose(t, s).squashY * 100,
  for (final layer in BreakLiftLayer.values)
    for (var i = 0; i < T.clouds(layer).length; i++) ...{
      '${layer.name} cloud $i y': (t, s) => T.cloudAt(layer, i, t, s).dy,
      '${layer.name} cloud $i x': (t, s) => T.cloudAt(layer, i, t, s).dx,
    },
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

double _unit(Size size) => math.min(size.width / 390, size.height / 844);

void _expectBox(Rect a, Rect b) {
  expect(a.left, closeTo(b.left, 1e-9));
  expect(a.top, closeTo(b.top, 1e-9));
  expect(a.right, closeTo(b.right, 1e-9));
  expect(a.bottom, closeTo(b.bottom, 1e-9));
}

/// The most one number may move in a frame, and change its pace by. A layer
/// of cloud rides the lift's one ease over its whole reach, so its limits
/// follow its reach. The plume is longer than the rest, and so quicker.
(double step, double pace) _limits(String name) {
  for (final layer in BreakLiftLayer.values) {
    if (name.startsWith(layer.name)) {
      final reach = T.reach(layer);
      return (
        1.15 * math.pi / 2 * reach / (T.liftTo - T.liftFrom) * _frame,
        1.15 *
            reach *
            math.pi *
            math.pi /
            2 /
            math.pow(T.liftTo - T.liftFrom, 2) *
            _frame *
            _frame,
      );
    }
  }
  if (name.startsWith('plume')) return (5.5, 0.4);
  return (3, 0.25);
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
              final limits = _limits(name);
              expect(
                step.abs(),
                lessThan(limits.$1),
                reason: '$name moves $step at $t',
              );
              // An eased number changes its pace a little from one frame to
              // the next. A jump or a start from rest does not.
              if (!first) {
                expect(
                  (step - lastStep).abs(),
                  lessThan(limits.$2),
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

    test('the backdrop never gets lighter than it is at the hit', () {
      // The colours the host draws under the outro: the paywall's own
      // ground, then the night. A paper or any light step is a flash.
      for (final (ground, night) in [
        (const Color(0xFFFFC83A), const Color(0xFF1A1613)),
        (const Color(0xFF14110F), const Color(0xFF0E0C0A)),
        (const Color(0xFFF5F0E6), const Color(0xFF1A1613)),
      ]) {
        double light(Color c) => c.computeLuminance();
        final atHit = light(T.backdrop(T.hit, ground: ground, night: night));
        for (var t = T.hit; t <= T.uncover; t += 1 / 60) {
          expect(
            light(T.backdrop(t, ground: ground, night: night)),
            lessThanOrEqualTo(atHit + 1e-9),
            reason: 'lighter than at the hit at $t on $ground',
          );
        }
      }
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

    test('the layers travel by fixed multiples of one rise: near more than '
        'mid more than far more than the stars', () {
      final starMost =
          T.stars.map((s) => s.slide).reduce(math.max) * T.starReach;
      expect(
        T.reach(BreakLiftLayer.near),
        greaterThan(T.reach(BreakLiftLayer.mid)),
      );
      expect(
        T.reach(BreakLiftLayer.mid),
        greaterThan(T.reach(BreakLiftLayer.far)),
      );
      expect(T.reach(BreakLiftLayer.far), greaterThan(starMost));
      for (final size in _screens) {
        // The near layer crosses more than a screen, the far a fraction.
        expect(
          T.reach(BreakLiftLayer.near) * _unit(size),
          greaterThan(size.height),
        );
        expect(
          T.reach(BreakLiftLayer.far) * _unit(size),
          lessThan(size.height),
        );
        // Each cloud moves by exactly its layer's reach over the lift.
        for (final layer in BreakLiftLayer.values) {
          for (var i = 0; i < T.clouds(layer).length; i++) {
            final travel =
                T.cloudAt(layer, i, T.liftTo, size).dy -
                T.cloudAt(layer, i, T.liftFrom, size).dy;
            expect(travel, closeTo(T.reach(layer) * _unit(size), 1e-6));
          }
        }
      }
    });

    test('every cloud is above the screen when the lift starts and none '
        'moves up', () {
      for (final size in _screens) {
        for (final layer in BreakLiftLayer.values) {
          for (var i = 0; i < T.clouds(layer).length; i++) {
            expect(
              T.cloudBox(layer, i, T.liftFrom, size).bottom,
              lessThan(0),
              reason: '${layer.name} $i is on screen when the lift starts',
            );
            var last = -1e9;
            for (var t = T.hit; t <= T.end; t += _frame) {
              final y = T.cloudAt(layer, i, t, size).dy;
              expect(y, greaterThanOrEqualTo(last));
              last = y;
            }
          }
        }
      }
    });

    test('the near clouds never touch his box', () {
      for (final size in _screens) {
        for (final mascot in <Rect?>[_mascotFor(size), null]) {
          for (var t = 0.0; t <= T.end + 1e-9; t += 0.05) {
            final box = _pose(t, size, mascot: mascot).turnedBox;
            for (var i = 0; i < T.clouds(BreakLiftLayer.near).length; i++) {
              expect(
                T.cloudBox(BreakLiftLayer.near, i, t, size).overlaps(box),
                isFalse,
                reason: 'near $i meets him at $t on $size',
              );
            }
          }
        }
      }
    });

    test('the clouds have the night to show on: none before it comes', () {
      expect(T.cloudAlpha(T.hit), 0);
      expect(T.cloudAlpha(T.liftTo), 1);
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

    test('the plume is gone at rest and follows the lift speed', () {
      const size = Size(390, 844);
      expect(T.plumeAlpha(T.liftFrom), 0);
      expect(T.plumeAlpha(T.liftTo), closeTo(0, 1e-9));
      expect(T.plumeLength(T.liftTo, size), closeTo(0, 1e-9));
      expect(T.plumeLength(0.5, size), 0);
      expect(T.plumeSway(T.liftTo, size), closeTo(0, 1e-9));
      expect(T.plumeAlpha(1.65), greaterThan(T.plumeAlpha(1.2)));
      expect(T.plumeLength(1.65, size), greaterThan(T.plumeLength(1.2, size)));
      // It sways on the clock and never jumps: a sine, bounded by the lift.
      for (var t = T.liftFrom; t <= T.liftTo; t += _frame) {
        expect(T.plumeSway(t, size).abs(), lessThanOrEqualTo(12));
      }
    });

    test('he leans into the flight, stretches a little, and is upright and '
        'unstretched from the end of the lift', () {
      for (final size in _screens) {
        final land = _landFor(size);
        var leaned = false;
        var stretched = false;
        for (var t = T.hit; t <= T.end; t += 0.01) {
          final pose = _pose(t, size);
          if (pose.angle.abs() > 0.03) leaned = true;
          if (pose.squashY > land.height / land.width * 1.04) stretched = true;
          if (t >= T.liftTo) {
            expect(pose.angle, 0, reason: 'at $t');
            expect(pose.squashX, 1, reason: 'at $t');
            expect(pose.squashY, land.height / land.width, reason: 'at $t');
          }
        }
        expect(leaned, isTrue);
        expect(stretched, isTrue);
      }
    });

    test('he sinks and squashes before he goes, eased from rest', () {
      const size = Size(390, 844);
      final before = _pose(0.7, size);
      final at = _pose(T.liftFrom, size);
      expect(at.centre.dy, greaterThan(before.centre.dy));
      expect(at.squashY, lessThan(1));
      expect(T.crouch(0.62), 0);
      expect(T.crouch(T.liftFrom), closeTo(1, 1e-9));
      expect(T.crouch(1.3), closeTo(0, 1e-9));
    });

    test('the night is on before Crit has arrived and is gone at the swap', () {
      expect(T.night(T.hit), 0);
      expect(T.night(T.liftTo), 1);
      expect(T.fadeOut(T.uncover), 0);
      expect(T.fadeOut(T.end), 1);
    });
  });

  group('the outro', () {
    test('is sound, with the two taps and its score', () {
      expect(breakLift.isSound, isTrue);
      expect(breakLift.seconds, T.end);
      expect(breakLift.uncover, T.uncover);
      expect(breakLift.score, PaywallCue.scoreBreakLift);
      expect(breakLift.scoreSeconds, 3.698);
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

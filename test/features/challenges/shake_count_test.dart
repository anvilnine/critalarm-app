import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:critalarm/core/motion/motion_sensor.dart';
import 'package:critalarm/features/challenges/domain/challenge_incident.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:critalarm/features/challenges/domain/shake_count.dart';
import 'package:critalarm/features/challenges/presentation/challenge.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where gravity pulls and what the hand adds, both in g.
typedef _Vector = (double x, double y, double z);

/// A phone flat on a desk with the screen up, the way an iPhone reads it.
const _Vector _flat = (0, 0, -1);

/// Readings in the style of a recording: [seconds] long at [hz] a second.
/// Each is [gravity] at that moment plus [move] at that moment, plus a
/// little sensor noise that is the same on every run.
List<MotionReading> _recording({
  required double seconds,
  _Vector Function(double t)? move,
  _Vector Function(double t)? gravity,
  int hz = 50,
  double noise = 0.02,
  int startMicros = 5000000,
}) {
  final random = Random(7);
  final readings = <MotionReading>[];
  final total = (seconds * hz).round();
  for (var i = 0; i <= total; i++) {
    final t = i / hz;
    final (gx, gy, gz) = gravity?.call(t) ?? _flat;
    final (mx, my, mz) = move?.call(t) ?? (0.0, 0.0, 0.0);
    double jitter() => (random.nextDouble() - 0.5) * 2 * noise;
    readings.add(
      MotionReading(
        x: gx + mx + jitter(),
        y: gy + my + jitter(),
        z: gz + mz + jitter(),
        at: Duration(microseconds: startMicros + (t * 1000000).round()),
      ),
    );
  }
  return readings;
}

/// A hand shaking the phone side to side: [strength] g at the ends of the
/// swing, [perSecond] times out and back each second.
_Vector Function(double t) _shaking({
  double strength = 3,
  double perSecond = 4,
}) =>
    (t) => (strength * sin(2 * pi * perSecond * t), 0, 0);

void main() {
  group('what does not count', () {
    test('a still phone, lying flat', () {
      expect(countShakes(_recording(seconds: 30)), 0);
    });

    test('a still phone, with no noise at all', () {
      expect(countShakes(_recording(seconds: 30, noise: 0)), 0);
    });

    test('a phone lying face down, on its side or propped up', () {
      for (final way in <_Vector>[
        (0, 0, 1),
        (1, 0, 0),
        (0, -1, 0),
        (0, -0.7071, -0.7071),
      ]) {
        expect(
          countShakes(_recording(seconds: 20, gravity: (_) => way)),
          0,
          reason: 'gravity $way',
        );
      }
    });

    test('a noisy sensor on a desk', () {
      expect(countShakes(_recording(seconds: 30, noise: 0.15)), 0);
    });

    test('a phone in a pocket on a walk', () {
      // Two steps a second: the body bobs half a g, sways a fifth of one
      // from foot to foot, and each heel lands with a knock of nearly 1 g
      // that lasts two readings.
      _Vector walk(double t) {
        final sinceStep = (t * 2) % 1 / 2;
        final knock = sinceStep < 0.04 ? 0.9 : 0.0;
        return (
          0.2 * sin(2 * pi * t),
          0.15 * sin(2 * pi * 2 * t + 1),
          0.5 * sin(2 * pi * 2 * t) - knock,
        );
      }

      // Upright in a pocket, so gravity is along the long side.
      expect(
        countShakes(
          _recording(seconds: 60, move: walk, gravity: (_) => (0, -1, 0)),
        ),
        0,
      );
    });

    test('a phone carried in a swinging hand', () {
      // An arm swing: under one g, once a second.
      expect(
        countShakes(
          _recording(
            seconds: 30,
            move: (t) => (0.8 * sin(2 * pi * t), 0, 0.3 * sin(4 * pi * t)),
          ),
        ),
        0,
      );
    });

    test('a gentle wave of the phone', () {
      expect(
        countShakes(
          _recording(
            seconds: 20,
            move: _shaking(strength: 1, perSecond: 1.5),
          ),
        ),
        0,
      );
    });

    test('a phone picked up and turned over', () {
      // Gravity goes from screen up to screen down in a third of a second.
      // The low pass lags behind it, which reads as one hard push and
      // never as a push and a push back.
      _Vector turning(double t) {
        final angle = pi * ((t - 1) / 0.33).clamp(0.0, 1.0);
        return (sin(angle), 0, -cos(angle));
      }

      expect(countShakes(_recording(seconds: 5, gravity: turning)), 0);
    });

    test('a hard movement with no way back', () {
      // One push of 3 g for a tenth of a second, and nothing after it.
      expect(
        countShakes(
          _recording(
            seconds: 4,
            move: (t) =>
                t >= 1 && t < 1.1 ? (3 * sin(pi * (t - 1) / 0.1), 0, 0) : _zero,
          ),
        ),
        0,
      );
    });

    test('two hard knocks a second apart', () {
      // The second is the other way, but far too late to be the way back.
      _Vector knocks(double t) {
        if (t >= 1 && t < 1.06) return (3, 0, 0);
        if (t >= 2 && t < 2.06) return (-3, 0, 0);
        return _zero;
      }

      expect(countShakes(_recording(seconds: 4, move: knocks)), 0);
    });

    test('a swirl no faster than a shake would', () {
      // A hard circle: always strong, never a reversal inside one reading
      // step. It does count once it has come a third of the way round, so
      // it is held to the same pace as a shake and no faster.
      final count = countShakes(
        _recording(
          seconds: 10,
          move: (t) => (
            3 * sin(2 * pi * 4 * t),
            3 * cos(2 * pi * 4 * t),
            0,
          ),
        ),
      );
      expect(count, lessThanOrEqualTo(41));
    });

    test('readings that are not numbers', () {
      final counter = ShakeCounter();
      for (var i = 0; i < 100; i++) {
        expect(
          counter.add(
            MotionReading(
              x: double.nan,
              y: double.infinity,
              z: -1,
              at: Duration(milliseconds: 20 * i),
            ),
          ),
          isFalse,
        );
      }
      expect(counter.count, 0);
    });
  });

  group('what counts', () {
    test('one hard swing out and back is one shake', () {
      // Out for a tenth of a second, back for a tenth, at 3 g.
      _Vector swing(double t) {
        if (t < 1 || t >= 1.2) return _zero;
        return (3 * sin(2 * pi * (t - 1) / 0.2), 0, 0);
      }

      expect(countShakes(_recording(seconds: 4, move: swing)), 1);
    });

    test('fast shaking reaches thirty in under ten seconds', () {
      final count = countShakes(_recording(seconds: 10, move: _shaking()));
      expect(count, greaterThanOrEqualTo(ShakeRule.target));
      // Never more than the gap between counts allows: four a second.
      expect(count, lessThanOrEqualTo(41));
    });

    test('shaking twice a second counts about twice a second', () {
      final count = countShakes(
        _recording(seconds: 10, move: _shaking(perSecond: 2)),
      );
      expect(count, inInclusiveRange(18, 21));
    });

    test('shaking faster than the gap allows is held to four a second', () {
      final count = countShakes(
        _recording(seconds: 10, move: _shaking(strength: 4, perSecond: 8)),
      );
      expect(count, inInclusiveRange(20, 41));
    });

    test('it counts along any side of the phone', () {
      for (final move in <_Vector Function(double)>[
        (t) => (0, 3 * sin(2 * pi * 4 * t), 0),
        (t) => (0, 0, 3 * sin(2 * pi * 4 * t)),
        (t) => (
          2 * sin(2 * pi * 4 * t),
          2 * sin(2 * pi * 4 * t),
          2 * sin(2 * pi * 4 * t),
        ),
      ]) {
        expect(
          countShakes(_recording(seconds: 10, move: move)),
          greaterThanOrEqualTo(ShakeRule.target),
        );
      }
    });

    test('it counts however the phone is held', () {
      for (final way in <_Vector>[(0, 0, 1), (1, 0, 0), (0, -1, 0)]) {
        expect(
          countShakes(
            _recording(seconds: 10, move: _shaking(), gravity: (_) => way),
          ),
          greaterThanOrEqualTo(ShakeRule.target),
          reason: 'gravity $way',
        );
      }
    });

    test('a slower and a faster sensor count much the same', () {
      final counts = [
        for (final hz in [25, 50, 100, 200])
          countShakes(_recording(seconds: 10, move: _shaking(), hz: hz)),
      ];
      for (final count in counts) {
        expect(count, inInclusiveRange(30, 41), reason: '$counts');
      }
    });

    test('a weak shake counts nothing and a hard one does', () {
      int at(double strength) => countShakes(
        _recording(seconds: 10, move: _shaking(strength: strength)),
      );
      expect(at(1.2), 0);
      expect(at(2.2), greaterThanOrEqualTo(ShakeRule.target));
    });

    test('shaking, a rest, then shaking again adds up', () {
      _Vector move(double t) => t < 3 || t >= 6 ? _shaking()(t) : _zero;
      final first = countShakes(_recording(seconds: 3, move: _shaking()));
      final both = countShakes(_recording(seconds: 9, move: move));
      expect(first, greaterThan(8));
      expect(both, inInclusiveRange(first * 2 - 2, first * 2 + 2));
    });
  });

  group('the counter', () {
    test('says which reading completed a shake', () {
      final counter = ShakeCounter();
      var told = 0;
      for (final reading in _recording(seconds: 5, move: _shaking())) {
        if (counter.add(reading)) told++;
      }
      expect(told, counter.count);
      expect(told, greaterThan(10));
    });

    test('two counts are never closer than the gap', () {
      final counter = ShakeCounter();
      Duration? last;
      for (final reading in _recording(
        seconds: 10,
        move: _shaking(strength: 4, perSecond: 9),
        hz: 200,
      )) {
        if (!counter.add(reading)) continue;
        if (last != null) {
          expect(reading.at - last, greaterThanOrEqualTo(ShakeRule.minGap));
        }
        last = reading.at;
      }
      expect(counter.count, greaterThan(10));
    });

    test('a hole in the stream drops a half-made shake', () {
      final counter = ShakeCounter();
      MotionReading at(int ms, double x) => MotionReading(
        x: x,
        y: 0,
        z: -1,
        at: Duration(milliseconds: ms),
      );
      // Settle, then one hard push.
      for (var ms = 0; ms < 1000; ms += 20) {
        counter.add(at(ms, 0));
      }
      counter.add(at(1000, 3));
      // The stream stops for a second and comes back the other way.
      expect(counter.add(at(2000, -3)), isFalse);
      expect(counter.add(at(2020, -3)), isFalse);
      expect(counter.count, 0);
    });

    test('a reading delivered twice counts the same as once', () {
      final once = _recording(seconds: 10, move: _shaking());
      final twice = [
        for (final reading in once) ...[reading, reading],
      ];
      expect(countShakes(once), greaterThanOrEqualTo(ShakeRule.target));
      expect(countShakes(twice), countShakes(once));
    });

    test('a repeated stamp does not drop a half-made shake', () {
      final counter = ShakeCounter();
      MotionReading at(int ms, double x) => MotionReading(
        x: x,
        y: 0,
        z: -1,
        at: Duration(milliseconds: ms),
      );
      for (var ms = 0; ms < 1000; ms += 20) {
        counter.add(at(ms, 0));
      }
      // Out, the same stamp again with another value, then back.
      expect(counter.add(at(1000, 3)), isFalse);
      expect(counter.add(at(1000, 2.5)), isFalse);
      expect(counter.add(at(1020, 3)), isFalse);
      expect(counter.add(at(1120, -3)), isTrue);
      expect(counter.count, 1);
    });

    test('a clock that goes back starts over and does not throw', () {
      final counter = ShakeCounter();
      _recording(seconds: 3, move: _shaking()).forEach(counter.add);
      final before = counter.count;
      expect(before, greaterThan(5));
      // The same three seconds again, from an earlier clock.
      _recording(
        seconds: 3,
        move: _shaking(),
        startMicros: 0,
      ).forEach(counter.add);
      expect(counter.count, inInclusiveRange(before * 2 - 2, before * 2));
    });
  });

  group('the numbers', () {
    test('are the ones the rule was reasoned from', () {
      expect(ShakeRule.target, 30);
      expect(ShakeRule.threshold, 1.5);
      expect(ShakeRule.reversalDot, -0.5);
      expect(ShakeRule.minGap, const Duration(milliseconds: 250));
      expect(ShakeRule.reversalWindow, const Duration(milliseconds: 500));
      expect(ShakeRule.gravitySettle, const Duration(milliseconds: 300));
      expect(ShakeRule.silentAfter, const Duration(seconds: 5));
    });

    test('thirty cannot be done in under seven seconds', () {
      expect(
        ShakeRule.minGap * (ShakeRule.target - 1),
        greaterThan(const Duration(seconds: 7)),
      );
    });

    test('the words on screen name the same target', () {
      final all =
          jsonDecode(File('assets/translations/en.json').readAsStringSync())
              as Map<String, dynamic>;
      final challenges = all['challenges'] as Map<String, dynamic>;
      final shake = challenges['shake'] as Map<String, dynamic>;
      // The prompt takes no arguments, so its number is written out. It
      // is one line for both states, so it names both ways.
      expect(shake['prompt'], contains('${ShakeRule.target}'));
      expect(shake['prompt'], '${ShakeRule.target} shakes or taps');
      expect(shake['hint_taps'], contains('{target}'));
      expect(shake['count'], contains('{target}'));
    });
  });

  group('the face', () {
    test('watches, then is jolted, squeezes, and ends dizzy', () {
      expect(shakeMoodFor(0), ShakeMood.ready);
      expect(shakeMoodFor(1), ShakeMood.jolted);
      expect(shakeMoodFor(9), ShakeMood.jolted);
      expect(shakeMoodFor(10), ShakeMood.squeezed);
      expect(shakeMoodFor(19), ShakeMood.squeezed);
      expect(shakeMoodFor(20), ShakeMood.dizzy);
      expect(shakeMoodFor(30), ShakeMood.dizzy);
      expect(shakeMoodFor(99), ShakeMood.dizzy);
      expect(shakeMoodFor(-3), ShakeMood.ready);
    });

    test('never goes back to an earlier mood as the count climbs', () {
      var last = ShakeMood.ready.index;
      for (var count = 0; count <= ShakeRule.target; count++) {
        final mood = shakeMoodFor(count).index;
        expect(mood, greaterThanOrEqualTo(last));
        last = mood;
      }
      expect(last, ShakeMood.dizzy.index);
    });

    test('progress runs from 0 to 1 and stays inside', () {
      expect(shakeProgress(0), 0);
      expect(shakeProgress(15), 0.5);
      expect(shakeProgress(30), 1);
      expect(shakeProgress(45), 1);
      expect(shakeProgress(-1), 0);
    });

    test('the rock starts and ends at zero, so nothing rests at an angle', () {
      for (var count = 0; count <= ShakeRule.target; count++) {
        expect(shakeRockAngle(count, 0), 0);
        expect(shakeRockAngle(count, 1), 0);
        expect(shakeRockAngle(count, 1.5), 0);
        expect(shakeRockAngle(count, -1), 0);
      }
      expect(shakeRockAngle(0, 0.25), 0);
    });

    test('the rock reaches further the dizzier Crit is, up to 12 degrees', () {
      var last = 0.0;
      for (var count = 1; count <= ShakeRule.target; count++) {
        final reach = shakeRockReach(count);
        expect(reach, greaterThan(last));
        last = reach;
        for (var step = 0; step <= 20; step++) {
          expect(shakeRockAngle(count, step / 20).abs(), lessThan(reach));
        }
      }
      expect(last, closeTo(12 * pi / 180, 1e-9));
      // Out one way first, then a little the other way.
      expect(shakeRockAngle(30, 0.2), greaterThan(0));
      expect(shakeRockAngle(30, 0.7), lessThan(0));
    });
  });

  group('in the registry', () {
    test('shake is the last of the first set, with its saved id', () {
      expect(ChallengeKind.shake.id, 'shake');
      expect(ChallengeKind.fromId('shake'), ChallengeKind.shake);
      expect(challenges.last.kind, ChallengeKind.shake);
    });

    test('it runs for any alarm and names itself', () {
      final challenge = challengeOf(ChallengeKind.shake)!;
      expect(challenge.nameKey, 'challenges.shake.name');
      expect(challenge.promptKey, 'challenges.shake.prompt');
      expect(
        challenge.canRunFor(const ChallengeIncident(topic: 'prod-db')),
        isTrue,
      );
      expect(challenge.canRunFor(const ChallengeIncident(topic: '')), isTrue);
    });
  });
}

const _Vector _zero = (0, 0, 0);

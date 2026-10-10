import 'dart:math' as math;

import 'package:critalarm/features/onboarding/domain/welcome_night_falls_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

WelcomeNightFallsFrame at(double seconds) =>
    welcomeNightFallsFrameAt(seconds, reducedMotion: false);

/// The frame at [fraction] of the loop.
WelcomeNightFallsFrame atFraction(double fraction) =>
    at(fraction * welcomeNightFallsLoopSeconds);

void main() {
  group('the loop', () {
    test('is 10 seconds', () {
      expect(welcomeNightFallsLoopSeconds, 10);
    });

    test('every part repeats every 10 seconds', () {
      for (final s in [0.0, 1.7, 2.65, 4.45, 5.65, 6.35, 7.95, 9.45]) {
        final a = at(s + welcomeNightFallsLoopSeconds);
        final b = at(s + 3 * welcomeNightFallsLoopSeconds);
        expect(a.nightOpacity, closeTo(b.nightOpacity, 1e-4));
        expect(a.sunFall, closeTo(b.sunFall, 1e-4));
        expect(a.ink, closeTo(b.ink, 1e-4));
        expect(a.burstReach, closeTo(b.burstReach, 1e-4));
        expect(a.burstOpacity, closeTo(b.burstOpacity, 1e-4));
        expect(a.dayFaceOpacity, closeTo(b.dayFaceOpacity, 1e-4));
        expect(a.sleepFaceOpacity, closeTo(b.sleepFaceOpacity, 1e-4));
        expect(a.shoutFaceOpacity, closeTo(b.shoutFaceOpacity, 1e-4));
        expect(a.faceScale, closeTo(b.faceScale, 1e-4));
        expect(a.faceTurn, closeTo(b.faceTurn, 1e-4));
        expect(a.clock, b.clock);
        for (var i = 0; i < welcomeNightFallsRingCount; i++) {
          expect(a.rings[i].scale, closeTo(b.rings[i].scale, 1e-4));
          expect(a.rings[i].opacity, closeTo(b.rings[i].opacity, 1e-4));
        }
        for (var i = 0; i < a.starOpacities.length; i++) {
          expect(a.starOpacities[i], closeTo(b.starOpacities[i], 1e-4));
        }
      }
    });

    test('a time before the start is the start', () {
      expect(at(-3).nightOpacity, at(0).nightOpacity);
    });

    test('every value stays in its range over the whole loop', () {
      for (var ms = 0; ms < 10000; ms += 40) {
        final frame = at(ms / 1000);
        for (final v in [
          frame.nightOpacity,
          frame.sunFall,
          frame.sunOpacity,
          frame.ink,
          frame.burstReach,
          frame.burstOpacity,
          frame.dayFaceOpacity,
          frame.sleepFaceOpacity,
          frame.shoutFaceOpacity,
          ...frame.starOpacities,
        ]) {
          expect(v, inInclusiveRange(0, 1), reason: 'at $ms ms');
        }
        for (final ring in frame.rings) {
          expect(ring.opacity, inInclusiveRange(0, 0.5), reason: 'at $ms ms');
          expect(ring.scale, inInclusiveRange(0.9, 2.2), reason: 'at $ms ms');
        }
      }
    });
  });

  group('the day', () {
    test('starts with the sun up, the day face and the dark ink', () {
      final frame = at(0);
      expect(frame.nightOpacity, closeTo(0, 1e-6));
      expect(frame.sunFall, closeTo(0, 1e-6));
      expect(frame.sunOpacity, closeTo(1, 1e-6));
      expect(frame.ink, closeTo(0, 1e-6));
      expect(frame.dayFaceOpacity, closeTo(1, 1e-6));
      expect(frame.sleepFaceOpacity, closeTo(0, 1e-6));
      expect(frame.shoutFaceOpacity, closeTo(0, 1e-6));
      expect(frame.burstReach, closeTo(0, 1e-6));
      expect(frame.clock, WelcomeNightClock.day);
    });

    test('holds until 14 percent of the loop', () {
      final frame = atFraction(welcomeNightFallsDuskFrom);
      expect(frame.nightOpacity, closeTo(0, 1e-6));
      expect(frame.sunFall, closeTo(0, 1e-6));
      expect(frame.sunOpacity, closeTo(1, 1e-6));
    });
  });

  group('night falls', () {
    test('the sun sets and the sky darkens between 14 and 28 percent', () {
      final middle = atFraction(
        (welcomeNightFallsDuskFrom + welcomeNightFallsNightAt) / 2,
      );
      expect(middle.nightOpacity, closeTo(0.5, 1e-9));
      expect(middle.sunFall, closeTo(0.5, 1e-9));
      expect(middle.sunOpacity, closeTo(0.5, 1e-9));
      final night = atFraction(welcomeNightFallsNightAt);
      expect(night.nightOpacity, closeTo(1, 1e-6));
      expect(night.sunFall, closeTo(1, 1e-6));
      expect(night.sunOpacity, closeTo(0, 1e-6));
    });

    test('the ink turns light from 18 to 28 percent', () {
      expect(atFraction(welcomeNightFallsInkLightFrom).ink, closeTo(0, 1e-6));
      expect(
        atFraction(
          (welcomeNightFallsInkLightFrom + welcomeNightFallsInkLightBy) / 2,
        ).ink,
        closeTo(0.5, 1e-9),
      );
      expect(atFraction(welcomeNightFallsInkLightBy).ink, closeTo(1, 1e-6));
    });

    test('the face goes to sleep from 22 to 26 percent', () {
      final before = atFraction(welcomeNightFallsSleepsFrom);
      expect(before.dayFaceOpacity, closeTo(1, 1e-6));
      expect(before.sleepFaceOpacity, closeTo(0, 1e-6));
      final asleep = atFraction(welcomeNightFallsSleepsBy);
      expect(asleep.dayFaceOpacity, closeTo(0, 1e-6));
      expect(asleep.sleepFaceOpacity, closeTo(1, 1e-6));
    });

    test('the stars only twinkle, never go out', () {
      for (var ms = 0; ms < 10000; ms += 50) {
        for (final v in at(ms / 1000).starOpacities) {
          expect(v, inInclusiveRange(0.3, 1));
        }
      }
    });

    test('the stars start at different times', () {
      final stars = at(0.1).starOpacities;
      expect(stars.toSet().length, greaterThan(1));
    });
  });

  group('the clock', () {
    test('reads 17:40, 22:05, 03:12 silent, 03:12 ringing, then 17:40', () {
      expect(atFraction(0.17).clock, WelcomeNightClock.day);
      expect(atFraction(0.18).clock, WelcomeNightClock.evening);
      expect(atFraction(0.29).clock, WelcomeNightClock.evening);
      expect(atFraction(0.30).clock, WelcomeNightClock.silent);
      expect(atFraction(0.55).clock, WelcomeNightClock.silent);
      expect(atFraction(0.56).clock, WelcomeNightClock.ringing);
      expect(atFraction(0.89).clock, WelcomeNightClock.ringing);
      expect(atFraction(0.90).clock, WelcomeNightClock.day);
      expect(atFraction(0.99).clock, WelcomeNightClock.day);
    });
  });

  group('the alarm rings', () {
    test('the burst is nothing until 54 percent and full at 62', () {
      expect(
        atFraction(welcomeNightFallsBurstFrom).burstReach,
        closeTo(0, 1e-6),
      );
      final growing = atFraction(0.58).burstReach;
      expect(growing, greaterThan(0.5), reason: 'it grows fast at first');
      expect(growing, lessThan(1));
      expect(
        atFraction(welcomeNightFallsBurstFullAt).burstReach,
        closeTo(1, 1e-6),
      );
    });

    test('the burst is up until 84 percent and gone at 94', () {
      expect(atFraction(0.7).burstOpacity, closeTo(1, 1e-6));
      // The curve is solved to within a thousandth, so it may start to move
      // a hair early.
      expect(
        atFraction(welcomeNightFallsRingingEndsFrom).burstOpacity,
        closeTo(1, 5e-3),
      );
      expect(
        atFraction(welcomeNightFallsBurstGoneAt).burstOpacity,
        closeTo(0, 1e-6),
      );
      expect(atFraction(0.99).burstOpacity, closeTo(0, 1e-6));
    });

    test('the night leaves under the burst, from 54 to 58 percent', () {
      expect(
        atFraction(welcomeNightFallsBurstFrom).nightOpacity,
        closeTo(1, 1e-6),
      );
      expect(
        atFraction(welcomeNightFallsInkDarkBy).nightOpacity,
        closeTo(0, 1e-6),
      );
    });

    test('the ink is dark again by 58 percent', () {
      expect(atFraction(welcomeNightFallsInkDarkFrom).ink, closeTo(1, 1e-6));
      expect(atFraction(welcomeNightFallsInkDarkBy).ink, closeTo(0, 1e-6));
    });

    test('the face wakes shouting from 55 to 57 percent', () {
      final asleep = atFraction(welcomeNightFallsShoutsFrom);
      expect(asleep.sleepFaceOpacity, closeTo(1, 1e-6));
      expect(asleep.shoutFaceOpacity, closeTo(0, 1e-6));
      final shouting = atFraction(welcomeNightFallsShoutsBy);
      expect(shouting.sleepFaceOpacity, closeTo(0, 1e-6));
      expect(shouting.shoutFaceOpacity, closeTo(1, 1e-6));
    });

    test('the face pops, then shakes from side to side, then settles', () {
      expect(atFraction(0.55).faceScale, closeTo(1, 1e-6));
      expect(atFraction(0.59).faceScale, closeTo(1.18, 1e-9));
      final turns = [
        for (final p in [0.63, 0.67, 0.71, 0.75, 0.79, 0.83])
          atFraction(p).faceTurn * 180 / math.pi,
      ];
      expect(turns[0], closeTo(-3, 1e-3));
      expect(turns[1], closeTo(3, 1e-3));
      expect(turns[2], closeTo(-3, 1e-3));
      expect(turns[3], closeTo(3, 1e-3));
      expect(turns[4], closeTo(-3, 1e-3));
      expect(turns[5], closeTo(3, 1e-3));
      final settled = atFraction(0.9);
      expect(settled.faceScale, closeTo(1, 1e-6));
      expect(settled.faceTurn, closeTo(0, 1e-6));
    });

    test('the face never rests at an angle', () {
      for (final p in [0, 0.1, 0.3, 0.5, 0.54, 0.91, 0.95, 0.999]) {
        expect(atFraction(p.toDouble()).faceTurn, 0, reason: 'at $p');
        expect(atFraction(p.toDouble()).faceScale, 1, reason: 'at $p');
      }
    });

    test('the rings pulse out while it rings and are gone before', () {
      final before = atFraction(0.5);
      for (final ring in before.rings) {
        expect(ring.opacity, closeTo(0, 1e-6));
      }
      final during = atFraction(0.7);
      expect(during.rings.any((ring) => ring.opacity > 0), isTrue);
      final after = atFraction(0.91);
      for (final ring in after.rings) {
        expect(ring.opacity, closeTo(0, 1e-6));
      }
    });

    test('the rings start 0.45 seconds apart', () {
      // The first ring starts when the face starts to shout: at 5.5 s.
      const start = welcomeNightFallsShoutsFrom * welcomeNightFallsLoopSeconds;
      final frame = at(start + 0.45 + 0.2);
      expect(frame.rings[0].scale, greaterThan(frame.rings[1].scale));
      expect(frame.rings[1].scale, greaterThan(frame.rings[2].scale));
    });

    test('the haptic plays when the face is shouting and the burst is up', () {
      final frame = at(welcomeNightFallsBurstLandsAt);
      expect(frame.shoutFaceOpacity, closeTo(1, 1e-6));
      expect(frame.burstReach, greaterThan(0));
      expect(welcomeNightFallsBurstLandsAt, closeTo(5.7, 1e-9));
    });
  });

  group('the day comes back', () {
    test('the day face is back by 92 percent', () {
      final frame = atFraction(welcomeNightFallsAwakeBy);
      expect(frame.dayFaceOpacity, closeTo(1, 1e-6));
      expect(frame.shoutFaceOpacity, closeTo(0, 1e-6));
    });

    test('the sun is up again at the end', () {
      final frame = atFraction(0.99);
      expect(frame.sunFall, closeTo(0, 1e-6));
      expect(frame.sunOpacity, closeTo(1, 1e-6));
      expect(frame.nightOpacity, closeTo(0, 1e-6));
    });
  });

  group('reduced motion', () {
    test('is the same frame at every time', () {
      for (final s in [0.0, 1.0, 3.3, 5.7, 9.9, 123.4]) {
        final frame = welcomeNightFallsFrameAt(s, reducedMotion: true);
        expect(identical(frame, welcomeNightFallsSettled), isTrue);
      }
    });

    test(
      'is the ringing night: dark sky, 03:12 ringing, the face shouting',
      () {
        const frame = welcomeNightFallsSettled;
        expect(frame.nightOpacity, closeTo(1, 1e-6));
        expect(frame.sunOpacity, closeTo(0, 1e-6));
        expect(frame.ink, closeTo(1, 1e-6));
        expect(frame.clock, WelcomeNightClock.ringing);
        expect(frame.shoutFaceOpacity, closeTo(1, 1e-6));
        expect(frame.dayFaceOpacity, closeTo(0, 1e-6));
        expect(frame.sleepFaceOpacity, closeTo(0, 1e-6));
        expect(frame.burstOpacity, closeTo(1, 1e-6));
      },
    );

    test('shows the burst but leaves the night and its stars in view', () {
      const frame = welcomeNightFallsSettled;
      expect(frame.burstReach, greaterThan(0));
      expect(frame.burstReach, lessThan(1));
      expect(frame.starOpacities.every((v) => v > 0.5), isTrue);
    });

    test('moves nothing: no rings, no turn, the face at its own size', () {
      const frame = welcomeNightFallsSettled;
      expect(frame.rings.every((ring) => ring.opacity == 0), isTrue);
      expect(frame.faceTurn, closeTo(0, 1e-6));
      expect(frame.faceScale, closeTo(1, 1e-6));
    });
  });

  group('the type size', () {
    /// The width of the text column on a phone [phone] points wide: the
    /// picture is the phone less 24 on each side, and the text sits 18 in
    /// from the picture's edges.
    double textWidthFor(double phone) => phone - 2 * 24 - 2 * 18;

    test('is 46 at most and a fixed share of the text width below that', () {
      expect(welcomeNightFallsMaxTitleSize, 46);
      expect(welcomeNightFallsTitleSize(1000), 46);
      expect(welcomeNightFallsTitleSize(200), closeTo(34, 1e-9));
    });

    test('from a 320 point phone to a 430 point phone it never exceeds the '
        'share and grows with the width', () {
      var last = 0.0;
      for (var phone = 320.0; phone <= 430; phone += 5) {
        final size = welcomeNightFallsTitleSize(textWidthFor(phone));
        expect(size, lessThanOrEqualTo(46));
        expect(size, greaterThanOrEqualTo(welcomeNightFallsMinTitleSize));
        expect(size, lessThanOrEqualTo(textWidthFor(phone) * 0.17 + 1e-9));
        expect(size, greaterThanOrEqualTo(last));
        last = size;
      }
    });

    test('is about 40 on a 320 point phone and 46 on a 430 point phone', () {
      expect(
        welcomeNightFallsTitleSize(textWidthFor(320)),
        closeTo(40.12, 0.01),
      );
      expect(welcomeNightFallsTitleSize(textWidthFor(430)), 46);
    });

    test('never goes below the smallest size', () {
      expect(
        welcomeNightFallsTitleSize(10),
        welcomeNightFallsMinTitleSize,
      );
    });
  });
}

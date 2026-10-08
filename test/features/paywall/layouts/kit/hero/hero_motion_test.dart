import 'dart:math' as math;

import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the default motion is the approved Hero', () {
    const motion = HeroMotion();
    expect(motion.atmosphere, HeroAtmosphereStyle.drift);
    expect(motion.entrance, HeroEntranceStyle.pop);
    expect(motion.idle, HeroIdleStyle.bob);
    expect(motion.arrival, HeroCardArrival.fade);
    expect(HeroAtmosphereStyle.values.first, HeroAtmosphereStyle.drift);
    expect(HeroEntranceStyle.values.first, HeroEntranceStyle.pop);
    expect(HeroIdleStyle.values.first, HeroIdleStyle.bob);
    expect(HeroCardArrival.values.first, HeroCardArrival.fade);
    expect(motion, const HeroMotion());
    expect(
      motion,
      isNot(const HeroMotion(entrance: HeroEntranceStyle.drop)),
    );
  });

  test('there are enough of each to tell layouts apart', () {
    expect(HeroAtmosphereStyle.values.length, greaterThanOrEqualTo(4));
    expect(HeroEntranceStyle.values.length, greaterThanOrEqualTo(4));
    expect(HeroIdleStyle.values.length, greaterThanOrEqualTo(3));
    expect(HeroCardArrival.values.length, greaterThanOrEqualTo(3));
  });

  group('entrances', () {
    test('every one starts unseen and ends in place at full size', () {
      for (final style in HeroEntranceStyle.values) {
        final start = heroEntrancePose(style, 0, size: 120);
        expect(
          start.opacity == 0 || start.scale == 0,
          isTrue,
          reason: '$style shows at zero',
        );
        final end = heroEntrancePose(style, 1, size: 120);
        expect(end.dx, closeTo(0, 1e-9), reason: '$style');
        expect(end.dy, closeTo(0, 1e-9), reason: '$style');
        expect(end.scale, closeTo(1, 1e-9), reason: '$style');
        expect(end.opacity, 1, reason: '$style');
        expect(end.clipsAtFoot, isFalse, reason: '$style');
      }
    });

    test('the pop is the approved one, to the number', () {
      for (final e in [0.0, 0.2, 0.34, 0.5, 0.6, 0.9, 1.0]) {
        final arrive = AppCurves.easeBack.transform(
          ((e - 0.08) / (0.6 - 0.08)).clamp(0.0, 1.0),
        );
        final pose = heroEntrancePose(HeroEntranceStyle.pop, e, size: 96);
        expect(pose.scale, arrive);
        expect(pose.dy, 26 * (1 - arrive));
        expect(pose.dx, 0);
        expect(pose.opacity, 1);
      }
    });

    test('a drop comes from above and a slide from the left', () {
      final drop = heroEntrancePose(HeroEntranceStyle.drop, 0.2, size: 100);
      expect(drop.dy, lessThan(0));
      expect(drop.dx, 0);
      final slide = heroEntrancePose(HeroEntranceStyle.slide, 0.2, size: 100);
      expect(slide.dx, lessThan(0));
      expect(slide.dy, 0);
    });

    test('a drop bounces: it comes down, lifts, and comes down again', () {
      var last = double.negativeInfinity;
      var wasFalling = true;
      var lifts = 0;
      for (var e = 0.08; e <= 0.7; e += 0.002) {
        final dy = heroEntrancePose(HeroEntranceStyle.drop, e, size: 100).dy;
        // Never below its place.
        expect(dy, lessThanOrEqualTo(1e-9));
        final isFalling = dy >= last;
        if (wasFalling && !isFalling) lifts++;
        wasFalling = isFalling;
        last = dy;
      }
      expect(lifts, greaterThanOrEqualTo(2));
    });

    test('a peek starts under the foot, looks, waits, then rises', () {
      // The mascot's top is 180 points above the foot of its stage.
      double dy(double e) => heroEntrancePose(
        HeroEntranceStyle.peek,
        e,
        size: 100,
        footDrop: 180,
      ).dy;
      // All of it is under the foot until it moves.
      expect(dy(0), 180);
      // The look: its eyes are over the edge.
      expect(dy(0.3), closeTo(180 - 100 * heroPeekShare, 0.5));
      // It holds the look for a beat.
      expect(dy(0.44), closeTo(dy(0.32), 0.5));
      expect(dy(0.76), closeTo(0, 1e-9));
      expect(
        heroEntrancePose(HeroEntranceStyle.peek, 0.4, size: 100).clipsAtFoot,
        isTrue,
      );
      for (var e = 0.0; e <= 1; e += 0.02) {
        // Never above its place by more than the overshoot of a pop.
        expect(dy(e), greaterThan(-0.1 * 180));
      }
      // With no stage it comes up from its own height below.
      expect(heroEntrancePose(HeroEntranceStyle.peek, 0, size: 100).dy, 100);
    });
  });

  group('idles', () {
    test('every one is level and upright on the resting frame', () {
      for (final style in HeroIdleStyle.values) {
        final rest = heroIdlePose(style, seconds: 0, size: 120);
        expect(rest, (dx: 0.0, dy: 0.0, angle: 0.0), reason: '$style');
      }
    });

    test('the bob is the approved one, to the number', () {
      for (final t in [0.4, 1.0, 2.7, 9.3]) {
        final pose = heroIdlePose(HeroIdleStyle.bob, seconds: t, size: 96);
        expect(pose.dy, -3 * math.sin(2 * math.pi * t / 3.2));
        expect(pose.dx, 0);
        expect(pose.angle, 0);
      }
    });

    test('the lean goes toward the preview and comes back to zero', () {
      var widest = 0.0;
      for (var t = 0.01; t < heroLeanEvery * 2; t += 0.01) {
        final pose = heroIdlePose(HeroIdleStyle.lean, seconds: t, size: 100);
        expect(pose.angle, greaterThanOrEqualTo(0));
        expect(pose.angle, lessThanOrEqualTo(heroLeanReach + 1e-9));
        expect(pose.dx, greaterThanOrEqualTo(0));
        widest = math.max(widest, pose.angle);
      }
      expect(widest, closeTo(heroLeanReach, 1e-3));
      for (final t in [0.5, 1.4, 3.2, 4.0, heroLeanEvery + 0.5]) {
        expect(
          heroIdlePose(HeroIdleStyle.lean, seconds: t, size: 100).angle,
          closeTo(0, 1e-9),
        );
      }
    });

    test('the hop marks the start of a turn and is over in half a second', () {
      double lift(double turnSeconds) =>
          heroIdlePose(
            HeroIdleStyle.benefitHop,
            seconds: 3.2,
            size: 100,
            turnSeconds: turnSeconds,
          ).dy -
          heroIdlePose(HeroIdleStyle.bob, seconds: 3.2, size: 100).dy;
      expect(lift(0), closeTo(0, 1e-9));
      expect(lift(0.22), closeTo(-7, 0.01));
      expect(lift(0.4), closeTo(0, 1e-9));
      expect(lift(2), closeTo(0, 1e-9));
    });
  });

  group('how a preview arrives', () {
    test('every one ends with the new card in place, flat and solid', () {
      for (final style in HeroCardArrival.values) {
        for (final direction in [-1, 0, 1]) {
          final end = heroCardArrivalPose(
            style,
            1,
            width: 168,
            direction: direction,
            pull: 20,
          );
          expect(end.incoming.dx, closeTo(0, 1e-9), reason: '$style');
          expect(end.incoming.turn, closeTo(0, 1e-9), reason: '$style');
          expect(end.incoming.scale, closeTo(1, 1e-9), reason: '$style');
          expect(end.incoming.opacity, 1, reason: '$style');
          expect(end.outgoing.opacity, 0, reason: '$style');
        }
      }
    });

    test('every one starts with the old card where the finger left it', () {
      for (final style in HeroCardArrival.values) {
        final start = heroCardArrivalPose(
          style,
          0,
          width: 168,
          direction: 1,
          pull: -18,
        );
        expect(start.outgoing.dx, closeTo(-18, 1e-9), reason: '$style');
        expect(start.outgoing.opacity, 1, reason: '$style');
        expect(start.outgoing.turn, 0, reason: '$style');
        expect(start.incoming.opacity, 0, reason: '$style');
      }
    });

    test('the fade is the approved one, to the number', () {
      for (final enter in [0.0, 0.25, 0.5, 0.8, 1.0]) {
        final pose = heroCardArrivalPose(
          HeroCardArrival.fade,
          enter,
          width: 168,
          direction: -1,
          pull: 12,
        );
        const side = -1 * heroCardSlide;
        expect(
          pose.incoming.dx,
          side * (1 - AppCurves.easeSpring.transform(enter)),
        );
        expect(pose.incoming.opacity, enter);
        expect(
          pose.incoming.scale,
          0.94 + 0.06 * AppCurves.easeBack.transform(enter),
        );
        expect(
          pose.outgoing.dx,
          12 - side * AppCurves.easeOut.transform(enter),
        );
        expect(pose.outgoing.opacity, 1 - enter);
      }
    });

    test('a flip shows one card at a time, edge on half way', () {
      for (var enter = 0.0; enter <= 1; enter += 0.05) {
        final pose = heroCardArrivalPose(
          HeroCardArrival.flip,
          enter,
          width: 168,
        );
        expect(pose.incoming.opacity + pose.outgoing.opacity, 1);
        expect(pose.incoming.turn.abs(), lessThanOrEqualTo(math.pi / 2));
        expect(pose.outgoing.turn.abs(), lessThanOrEqualTo(math.pi / 2));
      }
      final before = heroCardArrivalPose(
        HeroCardArrival.flip,
        0.499,
        width: 168,
      );
      expect(before.outgoing.turn, closeTo(math.pi / 2, 0.02));
      final after = heroCardArrivalPose(
        HeroCardArrival.flip,
        0.5,
        width: 168,
      );
      expect(after.incoming.turn, closeTo(-math.pi / 2, 1e-9));
    });

    test('a slide through follows the hand, and goes left with none', () {
      for (final (direction, way) in [(1, 1.0), (0, 1.0), (-1, -1.0)]) {
        final pose = heroCardArrivalPose(
          HeroCardArrival.slideThrough,
          0.3,
          width: 168,
          direction: direction,
        );
        expect(pose.incoming.dx.sign, way);
        expect(pose.outgoing.dx.sign, -way);
      }
    });
  });

  group('atmospheres', () {
    test('the rays are still at rest and take a minute to go round', () {
      expect(heroRayTurn(0), 0);
      expect(heroRayTurn(heroRayTurnSeconds / 4), closeTo(math.pi / 2, 1e-9));
      expect(heroRayTurn(heroRayTurnSeconds), closeTo(0, 1e-9));
      expect(heroRayTurnSeconds, greaterThanOrEqualTo(30));
    });

    test('a bubble rises, comes round, and fades at both ends', () {
      for (var i = 0; i < heroBubbleCount; i++) {
        final rest = heroBubbleAt(i, 0);
        expect(rest.alpha, inInclusiveRange(0, 1));
        expect(rest.angle, 0);
        var last = heroBubbleAt(i, 0.001).at.dy;
        var wraps = 0;
        for (var t = 0.05; t < 40; t += 0.05) {
          final bubble = heroBubbleAt(i, t);
          expect(bubble.at.dy, inInclusiveRange(-0.09, 1.09));
          expect(bubble.alpha, inInclusiveRange(0, 1));
          if (bubble.at.dy > last) {
            wraps++;
            // It comes back at the foot, unseen.
            expect(bubble.alpha, lessThan(0.1));
          }
          last = bubble.at.dy;
        }
        expect(wraps, greaterThanOrEqualTo(2), reason: 'bubble $i');
      }
    });

    test('confetti falls once and lies flat where it rests', () {
      for (var i = 0; i < heroConfettiCount; i++) {
        final rest = heroConfettiAt(i, 0);
        expect(rest.alpha, 1);
        expect(rest.angle, 0);
        expect(rest.at.dy, inInclusiveRange(0.88, 1));
        expect(rest.at.dx, inInclusiveRange(0, 1));

        // Not thrown yet, then on its way down, then where it rests.
        expect(heroConfettiAt(i, 0.05).alpha, 0);
        final settled = heroConfettiAt(i, heroConfettiSettled);
        expect(settled.angle, closeTo(0, 1e-9));
        expect(settled.at.dx, closeTo(rest.at.dx, 1e-9));
        expect(settled.at.dy, closeTo(rest.at.dy, 1e-9));
        final later = heroConfettiAt(i, heroConfettiSettled + 30);
        expect(later.at.dy, closeTo(rest.at.dy, 1e-9));

        var last = -1.0;
        for (var t = 0.06; t <= heroConfettiSettled; t += 0.02) {
          final piece = heroConfettiAt(i, t);
          expect(piece.at.dy, greaterThanOrEqualTo(last - 1e-9));
          last = piece.at.dy;
        }
      }
    });

    test('rings follow each other out, fade as they go, and loop', () {
      final rest = [for (var i = 0; i < heroRingCount; i++) heroRingAt(i, 0)];
      expect(rest.map((r) => r.out), [
        0,
        closeTo(1 / 3, 1e-9),
        closeTo(2 / 3, 1e-9),
      ]);
      for (var i = 0; i < heroRingCount; i++) {
        for (var t = 0.0; t < 20; t += 0.1) {
          final ring = heroRingAt(i, t);
          expect(ring.out, inInclusiveRange(0, 1));
          expect(ring.alpha, inInclusiveRange(0, 1));
          final again = heroRingAt(i, t + heroRingSeconds);
          expect(again.out, closeTo(ring.out, 1e-6));
        }
        // A ring is unseen as it starts and as it ends.
        expect(
          heroRingAt(i, (1 - i / heroRingCount) * heroRingSeconds).alpha,
          closeTo(0, 1e-6),
        );
      }
    });
  });
}

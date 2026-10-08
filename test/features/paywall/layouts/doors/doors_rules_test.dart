import 'dart:math' as math;
import 'dart:ui';

import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/features/paywall/presentation/layouts/doors/doors_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_arrangement.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the opening', () {
    test('is shut on the first frame and open at rest', () {
      expect(DoorsTimeline.open(0), 0);
      expect(DoorsTimeline.open(DoorsTimeline.restAt), 1);
      expect(DoorsTimeline.swingEnd, lessThanOrEqualTo(DoorsTimeline.restAt));
    });

    test('gives a little, falls back, then swings open without a jump', () {
      const mid = (DoorsTimeline.nudgeStart + DoorsTimeline.nudgeEnd) / 2;
      expect(DoorsTimeline.open(mid), closeTo(DoorsTimeline.nudgeReach, 1e-9));
      expect(DoorsTimeline.open(DoorsTimeline.nudgeEnd), closeTo(0, 1e-9));
      expect(DoorsTimeline.open(DoorsTimeline.prelude), closeTo(0, 1e-9));

      var before = 0.0;
      for (var t = DoorsTimeline.prelude; t <= 2; t += 0.016) {
        final now = DoorsTimeline.open(t);
        expect(now, greaterThanOrEqualTo(before));
        expect(now, inInclusiveRange(0, 1));
        before = now;
      }
    });

    test('after an intro the door is already on its way', () {
      expect(doorsLeadFor(followsIntro: false), 0);
      final lead = doorsLeadFor(followsIntro: true);
      expect(DoorsTimeline.open(lead), inExclusiveRange(0, 1));
    });

    test('its cue plays once, on the frame the swing starts', () {
      const at = DoorsTimeline.prelude;
      expect(doorsReached(at - 0.016, at, at), isTrue);
      expect(doorsReached(at, at + 0.016, at), isFalse);
      expect(doorsReached(0, at - 0.016, at), isFalse);
    });
  });

  group('how far the door stands open', () {
    test('is past edge on for every benefit, and wider for each', () {
      const count = 5;
      var before = math.pi / 2;
      for (var i = 0; i < count; i++) {
        final angle = doorsRestAngle(i, count);
        expect(angle, greaterThan(before));
        expect(angle, lessThan(math.pi));
        before = angle;
      }
      // The first and the last are the same whatever the count.
      expect(doorsRestAngle(0, 4), doorsRestAngle(0, 5));
      expect(doorsRestAngle(3, 4), doorsRestAngle(4, 5));
    });

    test('never lies further out than the wall has room for', () {
      final angle = doorsRestAngle(4, 5, maxReach: 0.3);
      final shape = doorsLeafShapeFor(angle: angle, width: 200, height: 300);
      expect(shape.extent, closeTo(-60, 1e-6));
    });

    test('follows the opening during the entrance', () {
      double at(double open) => doorsAngleAt(open: open, index: 0, count: 4);
      expect(at(0), 0);
      expect(at(0.5), closeTo(doorsRestAngle(0, 4) / 2, 1e-9));
      expect(at(1), doorsRestAngle(0, 4));
    });

    test('swings from one benefit to the next, and back at the wrap', () {
      double at(int index, int previous, double enter) => doorsAngleAt(
        open: 1,
        index: index,
        count: 4,
        previous: previous,
        enter: enter,
      );
      expect(at(1, 0, 0), closeTo(doorsRestAngle(0, 4), 1e-9));
      expect(at(1, 0, 1), doorsRestAngle(1, 4));
      expect(
        at(1, 0, 0.5),
        inExclusiveRange(doorsRestAngle(0, 4), doorsRestAngle(1, 4)),
      );
      // Round to the first benefit again: it swings back.
      expect(
        at(0, 3, 0.5),
        inExclusiveRange(doorsRestAngle(0, 4), doorsRestAngle(3, 4)),
      );
      expect(at(0, 3, 1), doorsRestAngle(0, 4));
    });
  });

  group('the leaf', () {
    DoorsLeafShape at(double angle, {double swing = 1}) => doorsLeafShapeFor(
      angle: angle,
      width: 200,
      height: 300,
      swing: swing,
    );

    test('covers the doorway when shut and lies over the wall when open', () {
      expect(at(0).extent, 200);
      expect(at(math.pi / 2).extent, closeTo(0, 1e-9));
      expect(at(doorsRestAngle(0, 4)).extent, lessThan(0));
    });

    test('is square at every rest and tapers only while it swings', () {
      expect(at(0, swing: 0).taper, 0);
      for (var i = 0; i < 4; i++) {
        expect(at(doorsRestAngle(i, 4)).taper, closeTo(0, 1e-9));
      }
      expect(at(1, swing: 0.5).taper, greaterThan(0));
    });

    test('is at rest once the entrance and a change are over', () {
      expect(doorsSwingAt(open: 0.4, index: 0), 0.4);
      expect(doorsSwingAt(open: 1, index: 0), 1);
      expect(doorsSwingAt(open: 1, index: 2, previous: 1, enter: 0.3), 0.3);
      expect(doorsSwingAt(open: 1, index: 2, previous: 1), 1);
      expect(doorsSwingAt(open: 1, index: 2, previous: 2, enter: 0.3), 1);
    });
  });

  group('where the doorway stands', () {
    for (final stage in const [
      Size(390, 428),
      Size(390, 372),
      Size(375, 390),
      Size(375, 300),
      Size(375, 270),
    ]) {
      test('on a stage of $stage', () {
        final doors = doorsGeometryFor(stage)!;
        final approved = heroArrangementFor(stage);
        final mascot = doors.arrangement.mascot;
        final card = doors.arrangement.card;

        // The mascot and the preview are as large as on the approved stage.
        expect(doors.arrangement.kind, HeroStageKind.pair);
        expect(mascot, approved.mascot);
        expect(card, approved.card);

        // The preview is inside the doorway and the doorway on the stage.
        expect(card.left, greaterThan(doors.doorway.left));
        expect(card.right, lessThan(doors.doorway.right));
        expect(card.top, greaterThan(doors.doorway.top));
        expect(card.bottom, lessThanOrEqualTo(doors.doorway.bottom));
        expect(doors.doorway.right, lessThan(stage.width));
        expect(doors.doorway.bottom, stage.height);

        // The mascot stands across the hinge, in front of the open door.
        expect(mascot.left, lessThan(doors.doorway.left));
        expect(mascot.right, greaterThan(doors.doorway.left));

        // The door opened its widest is still on the screen.
        final widest = doorsLeafShapeFor(
          angle: doorsRestAngle(4, 5, maxReach: doors.maxReach),
          width: doors.doorway.width,
          height: doors.doorway.height,
        );
        expect(
          doors.doorway.left + widest.extent - doorsLeafEdge / 2,
          greaterThan(0),
        );

        // The cross sits inside the doorway, clear of its frame.
        final cross = Rect.fromCenter(
          center: Offset(stage.width - 4 - 22, 22),
          width: 14,
          height: 14,
        );
        expect(doors.doorway.deflate(4).contains(cross.topLeft), isTrue);
        expect(doors.doorway.deflate(4).contains(cross.bottomRight), isTrue);
      });
    }

    test('a stage with no room for a preview has no door', () {
      expect(doorsGeometryFor(const Size(375, 160)), isNull);
      expect(doorsGeometryFor(const Size(375, 0)), isNull);
    });
  });

  group('the motion', () {
    test('is its own: rays, a look first, a lean, a card that turns', () {
      expect(doorsMotion.atmosphere, HeroAtmosphereStyle.rays);
      expect(doorsMotion.entrance, HeroEntranceStyle.peek);
      expect(doorsMotion.idle, HeroIdleStyle.lean);
      expect(doorsMotion.arrival, HeroCardArrival.flip);
    });
  });

  group('the headline', () {
    test('speaks to a Hosted plan that is ending or has ended', () {
      expect(
        doorsHeadlineFor(isHosted: true, source: PaywallSource.planSheetEnding),
        DoorsHeadline.keepOpen,
      );
      expect(
        doorsHeadlineFor(isHosted: true, source: PaywallSource.planSheetEnded),
        DoorsHeadline.openAgain,
      );
    });

    test('is the offer from anywhere else', () {
      expect(
        doorsHeadlineFor(isHosted: true, source: PaywallSource.direct),
        DoorsHeadline.hosted,
      );
      for (final source in PaywallSource.values) {
        expect(
          doorsHeadlineFor(isHosted: false, source: source),
          DoorsHeadline.pro,
        );
      }
    });
  });
}

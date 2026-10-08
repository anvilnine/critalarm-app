import 'dart:ui';

import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/features/paywall/presentation/layouts/doors/doors_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_arrangement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the right door', () {
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

    test('is square when shut and when open, and only then', () {
      DoorsLeafShape at(double open) =>
          doorsLeafShapeFor(open: open, width: 200, height: 300);

      expect(at(0).width, 200);
      expect(at(0).taper, 0);
      expect(at(1).width, closeTo(doorsLeafEdge, 1e-9));
      expect(at(1).taper, closeTo(0, 1e-9));
      expect(at(0.5).taper, greaterThan(0));
      expect(at(0.5).width, inExclusiveRange(doorsLeafEdge, 200));
    });
  });

  group('where the doors stand', () {
    for (final stage in const [
      Size(390, 428),
      Size(390, 380),
      Size(375, 390),
      Size(375, 270),
      Size(375, 250),
    ]) {
      test('on a stage of $stage', () {
        final doors = doorsGeometryFor(stage)!;
        final mascot = doors.arrangement.mascot;
        final card = doors.arrangement.card;
        final bounds = Offset.zero & stage;

        expect(doors.arrangement.kind, HeroStageKind.pair);
        // The preview keeps its large class and its square.
        expect(card.width, inInclusiveRange(heroCardMin, heroCardMax));
        expect(card.height, card.width);
        expect(mascot.width, greaterThanOrEqualTo(doorsMascotMin));

        // The preview is inside the doorway, clear of the open leaf.
        expect(card.left, greaterThanOrEqualTo(doors.doorway.left));
        expect(card.top, greaterThanOrEqualTo(doors.doorway.top));
        expect(
          card.right,
          lessThanOrEqualTo(doors.doorway.right - doorsLeafEdge),
        );
        // The mascot stands on the doorway's left edge, on the floor.
        expect(mascot.left, lessThan(doors.doorway.left));
        expect(mascot.right, greaterThan(doors.doorway.left));
        expect(mascot.bottom, doors.doorway.bottom);
        // It does not cover the shut door.
        expect(mascot.left, greaterThanOrEqualTo(doors.freeDoor.right));

        // Both doors are as tall as each other, on one floor, on stage.
        expect(doors.freeDoor.top, doors.doorway.top);
        expect(doors.freeDoor.bottom, doors.doorway.bottom);
        expect(bounds.contains(doors.doorway.topLeft), isTrue);
        expect(doors.doorway.bottom, lessThanOrEqualTo(stage.height));

        // The light never sits under the close cross.
        final cross = Rect.fromLTWH(stage.width - 44, 0, 44, 44);
        expect(doors.doorway.overlaps(cross), isFalse);
      });
    }

    test('a short stage puts the doorway beside the cross', () {
      final doors = doorsGeometryFor(const Size(375, 270))!;
      expect(doors.doorway.top, heroTopRoom);
      expect(doors.doorway.right, 375 - doorsCrossRoom);
    });

    test('a stage with no room for a doorway has no doors', () {
      expect(doorsGeometryFor(const Size(375, 200)), isNull);
      expect(doorsGeometryFor(const Size(375, 0)), isNull);
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

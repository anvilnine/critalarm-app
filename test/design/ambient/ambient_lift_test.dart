import 'package:critalarm/design/ambient/ambient_lift.dart';
import 'package:critalarm/design/ambient/ambient_page.dart';
import 'package:flutter_test/flutter_test.dart';

class _Lifting implements AmbientEntranceRoute {
  @override
  AmbientEntrance get entrance => AmbientEntrance.lift;
}

void main() {
  group('liftInPose', () {
    test('starts below and hidden, ends at rest', () {
      final start = liftInPose(0);
      expect(start.dy, kLiftRise);
      expect(start.opacity, 0);
      expect(liftInPose(1), LiftPose.rest);
    });

    test('rises without overshoot and fades in late', () {
      var lastDy = double.infinity;
      for (var i = 0; i <= 60; i++) {
        final pose = liftInPose(i / 60);
        expect(pose.dy, lessThanOrEqualTo(lastDy));
        expect(pose.dy, greaterThanOrEqualTo(0));
        lastDy = pose.dy;
      }
      expect(liftInPose(0.45).opacity, 0);
      expect(liftInPose(0.85).opacity, 1);
    });

    test('on a pop it moves and fades from the first frame', () {
      final early = liftInPose(0.95, reverse: true);
      expect(early.dy, greaterThan(0));
      expect(early.opacity, lessThan(1));
      expect(liftInPose(0.65, reverse: true).opacity, 0);
      expect(liftInPose(1, reverse: true), LiftPose.rest);
    });
  });

  group('liftCoveredPose', () {
    test('is at rest while nothing covers it', () {
      expect(liftCoveredPose(0), LiftPose.rest);
      expect(liftCoveredPose(0, reverse: true), LiftPose.rest);
    });

    test('sinks back and is gone early in a push', () {
      final end = liftCoveredPose(1);
      expect(end.dy, closeTo(-kLiftSinkRise, 1e-9));
      expect(end.scale, closeTo(kLiftSinkScale, 1e-9));
      expect(end.opacity, 0);
      expect(liftCoveredPose(0.35).opacity, 0);
    });

    test('comes back late on a pop, after the page above has faded', () {
      expect(liftCoveredPose(0.55, reverse: true).opacity, 0);
      expect(liftCoveredPose(0.15, reverse: true).opacity, 1);
    });

    test('push end and pop start are the same frame', () {
      expect(liftCoveredPose(1), liftCoveredPose(1, reverse: true));
      expect(liftInPose(1), liftInPose(1, reverse: true));
    });
  });

  test('no frame shows both screens, either way', () {
    for (var i = 0; i <= 480; i++) {
      final t = i / 480;
      for (final reverse in [false, true]) {
        final top = liftInPose(t, reverse: reverse).opacity;
        final under = liftCoveredPose(t, reverse: reverse).opacity;
        expect(top == 0 || under == 0, isTrue, reason: 't=$t reverse=$reverse');
      }
    }
  });

  group('coverEntranceOf', () {
    test('reads a route that says how it comes in', () {
      expect(coverEntranceOf(_Lifting()), AmbientEntrance.lift);
    });

    test('is a slide for anything else, and for nothing', () {
      expect(coverEntranceOf(Object()), AmbientEntrance.slide);
      expect(coverEntranceOf(null), AmbientEntrance.slide);
    });
  });
}

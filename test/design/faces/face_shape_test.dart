import 'dart:math' as math;

import 'package:critalarm/design/faces/face_shape.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:flutter_test/flutter_test.dart';

void expectNear(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, 0.001), reason: 'x of $actual');
  expect(actual.dy, closeTo(expected.dy, 0.001), reason: 'y of $actual');
}

void main() {
  final calm = faceFor(FaceState.calm);
  final working = faceFor(FaceState.working);
  final success = faceFor(FaceState.success);

  group('calm', () {
    test('eyes are r 11 dots at (70, 90) and (130, 90)', () {
      expect(calm.leftEye.ballRadius, 0);
      expect(calm.leftEye.pupilRadius, 11);
      expect(calm.leftEye.lid, 0);
      expectNear(calm.leftEye.centre, const Offset(70, 90));
      expectNear(calm.rightEye.centre, const Offset(130, 90));
    });

    test('mouth follows M70 128 Q100 148 130 128', () {
      final m = calm.mouth.points;
      expect(m, hasLength(MouthShape.pointCount));
      // A mouth is a loop: left corner, along the lower lip to the right
      // corner at 6, then back along the upper lip to the left corner again.
      expectNear(m.first, const Offset(70, 128));
      expectNear(m[3], const Offset(100, 138));
      expectNear(m[6], const Offset(130, 128));
      expectNear(m.last, const Offset(70, 128));
    });

    test('a shut mouth has both lips on the same line', () {
      final m = calm.mouth.points;
      for (var i = 1; i <= 5; i++) {
        expectNear(m[i], m[12 - i]);
      }
    });

    test('mouth is closed, so nothing is painted inside it', () {
      expect(calm.mouth.fill, 0);
    });

    test('has no extras and stands up straight', () {
      expect(calm.props, isEmpty);
      expect(calm.tilt, 0);
      expect(calm.head.squashX, 1);
      expect(calm.head.squashY, 1);
    });
  });

  group('working', () {
    test('eyes are shut into > and < chevrons', () {
      expect(working.leftEye.lid, 1);
      expect(working.leftEye.lidWidth, 10);
      expectNear(working.leftEye.lidPoints[0], const Offset(58, 80));
      expectNear(working.leftEye.lidPoints[1], const Offset(78, 90));
      expectNear(working.leftEye.lidPoints[2], const Offset(58, 100));
      expectNear(working.rightEye.lidPoints[1], const Offset(122, 90));
    });

    test('mouth wiggles 1.5 waves between x 70 and x 130', () {
      final m = working.mouth.points;
      expectNear(m.first, const Offset(70, 134));
      expectNear(m[6], Offset(130, 134 + 6 * math.sin(3 * math.pi)));
      // A sixth of the way along the lower lip is the first crest.
      expectNear(m[1], Offset(80, 134 + 6 * math.sin(3 * math.pi / 6)));
    });
  });

  group('success', () {
    test('mouth is a v with its tip at (100, 140)', () {
      final m = success.mouth.points;
      expectNear(m.first, const Offset(88, 128));
      expectNear(m[3], const Offset(100, 140));
      expectNear(m[6], const Offset(112, 128));
    });

    test('eyes are dots at (70, 88) and (130, 88)', () {
      expectNear(success.leftEye.centre, const Offset(70, 88));
      expectNear(success.rightEye.centre, const Offset(130, 88));
    });

    test('lines pop above the head', () {
      expect(success.props, hasLength(1));
      expect(success.props.single.kind, PropKind.popLines);
      expect(success.props.single.alpha, 1);
    });
  });

  group('lerp', () {
    test('0 and 1 return the two ends', () {
      final start = FaceShape.lerp(calm, working, 0);
      final end = FaceShape.lerp(calm, working, 1);
      expectNear(start.leftEye.centre, calm.leftEye.centre);
      expect(start.leftEye.lid, calm.leftEye.lid);
      expectNear(end.leftEye.centre, working.leftEye.centre);
      expect(end.leftEye.lid, working.leftEye.lid);
      expectNear(end.mouth.points[3], working.mouth.points[3]);
    });

    test('halfway moves every number halfway', () {
      final half = FaceShape.lerp(calm, working, 0.5);
      expect(half.leftEye.lid, 0.5);
      expectNear(half.leftEye.centre, const Offset(69, 90));
      expectNear(half.mouth.points.first, const Offset(70, 131));
    });

    test('a shut mouth opens by its upper lip leaving its lower one', () {
      // Calm and yawn are a smile and a wide open mouth. Halfway between
      // them the two lips have come apart, which is a mouth opening rather
      // than one line sliding into another.
      final yawn = faceFor(FaceState.yawn);
      final half = FaceShape.lerp(calm, yawn, 0.5);
      final gapAtStart = (calm.mouth.points[3] - calm.mouth.points[9]).distance;
      final gapAtHalf = (half.mouth.points[3] - half.mouth.points[9]).distance;
      expect(gapAtStart, closeTo(0, 0.001));
      expect(gapAtHalf, greaterThan(8));
      // And the corners stay corners the whole way.
      expectNear(half.mouth.points.first, half.mouth.points.last);
    });

    test('an eye with no lid of its own still has one to close', () {
      // Calm draws no lid, but it has to keep three points so a blink has
      // somewhere to blend to.
      expect(calm.leftEye.resolvedLidPoints, hasLength(3));
      final shut = FaceShape.lerp(calm, calm.blinking, 1);
      expect(shut.leftEye.lid, 1);
      expect(shut.rightEye.lid, 1);
    });

    test('a blink leaves everything but the eyes alone', () {
      final shut = calm.blinking;
      expectNear(shut.mouth.points[6], calm.mouth.points[6]);
      expect(shut.leftBrow.alpha, calm.leftBrow.alpha);
    });

    test('an extra only one face has fades and grows in', () {
      final quarter = FaceShape.lerp(calm, success, 0.25);
      expect(quarter.props, hasLength(1));
      expect(quarter.props.single.kind, PropKind.popLines);
      expect(quarter.props.single.alpha, closeTo(0.25, 0.001));
      expect(quarter.props.single.scale, closeTo(0.25, 0.001));
    });

    test('an extra fades back out on the way to a face without it', () {
      final quarter = FaceShape.lerp(success, calm, 0.25);
      expect(quarter.props.single.alpha, closeTo(0.75, 0.001));
    });

    test('the head can be squashed on the way through', () {
      final squashed = FaceShape.lerp(
        calm,
        FaceShape(
          leftEye: const EyeShape(centre: Offset(70, 90)),
          rightEye: const EyeShape(centre: Offset(130, 90)),
          mouth: MouthShape(
            lineMouth(const Offset(70, 128), const Offset(130, 128)),
          ),
          head: const HeadShape(squashX: 1.1, squashY: 0.9),
        ),
        0.5,
      );
      expect(squashed.head.squashX, closeTo(1.05, 0.001));
      expect(squashed.head.squashY, closeTo(0.95, 0.001));
    });
  });

  test('every face has a pose now, so any two of them can blend', () {
    for (final state in FaceState.values) {
      final shape = faceFor(state);
      expect(
        shape.mouth.points,
        hasLength(MouthShape.pointCount),
        reason: '$state needs $MouthShape.pointCount mouth points',
      );
      expect(shape.leftEye.resolvedLidPoints, hasLength(3), reason: '$state');
      expect(shape.rightEye.resolvedLidPoints, hasLength(3), reason: '$state');
      expect(shape.leftBrow.points, hasLength(3), reason: '$state');
      expect(shape.rightBrow.points, hasLength(3), reason: '$state');
    }
  });

  test('any two faces blend without throwing', () {
    for (final a in FaceState.values) {
      for (final b in FaceState.values) {
        final mixed = FaceShape.lerp(faceFor(a), faceFor(b), 0.5);
        expect(mixed.mouth.points, hasLength(MouthShape.pointCount));
      }
    }
  });
}

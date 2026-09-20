import 'package:critalarm/design/faces/face_shape.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:flutter_test/flutter_test.dart';

void expectNear(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, 0.001), reason: 'x of $actual');
  expect(actual.dy, closeTo(expected.dy, 0.001), reason: 'y of $actual');
}

void main() {
  final calm = faceFor(FaceState.calm);
  final watching = faceFor(FaceState.watching);
  final skeptical = faceFor(FaceState.skeptical);

  group('which faces can blend', () {
    test('every face has a brow above each eye, shown or not', () {
      for (final state in FaceState.values) {
        final shape = faceFor(state);
        expect(shape.leftBrow.points, hasLength(3), reason: '$state');
        expect(shape.rightBrow.points, hasLength(3), reason: '$state');
        expect(shape.leftBrow.alpha, inInclusiveRange(0, 1), reason: '$state');
        expect(shape.rightBrow.alpha, inInclusiveRange(0, 1), reason: '$state');
      }
    });
  });

  group('calm rests with hidden brows', () {
    test('both brows are invisible', () {
      expect(calm.leftBrow.alpha, 0);
      expect(calm.rightBrow.alpha, 0);
    });

    test('they sit flat just above the eyes', () {
      final left = calm.leftBrow.points;
      expect(left.map((p) => p.dy), everyElement(70));
      expect(left.first.dx, lessThan(calm.leftEye.centre.dx));
      expect(left.last.dx, greaterThan(calm.leftEye.centre.dx));
      // Above the eye, which sits at y 90.
      expect(left.first.dy, lessThan(calm.leftEye.centre.dy));
    });
  });

  group('watching', () {
    test('raised left brow M56 68 Q70 58 86 64, sampled at its middle', () {
      expectNear(watching.leftBrow.points[0], const Offset(56, 68));
      expectNear(watching.leftBrow.points[1], const Offset(70.5, 62));
      expectNear(watching.leftBrow.points[2], const Offset(86, 64));
      expect(watching.leftBrow.alpha, 1);
    });

    test('no right brow', () => expect(watching.rightBrow.alpha, 0));

    test('eyes are white balls with the pupils held level', () {
      expect(watching.leftEye.ballRadius, greaterThan(0));
      expect(watching.rightEye.ballRadius, greaterThan(0));
      expectNear(watching.leftEye.centre, const Offset(74, 94));
      expectNear(watching.rightEye.centre, const Offset(128, 94));
      // Pupils parked up and away read as rolling its eyes at you, so they
      // sit in the middle and the live drift does the looking around.
      expect(watching.leftEye.pupilOffset, Offset.zero);
      expect(watching.rightEye.pupilOffset, Offset.zero);
    });

    test('the pupils stay inside the whites', () {
      for (final eye in [watching.leftEye, watching.rightEye]) {
        expect(
          eye.pupilOffset.distance + eye.pupilRadius,
          lessThanOrEqualTo(eye.ballRadius),
        );
      }
    });

    test('mouth is flat from (84, 134) to (118, 134)', () {
      final m = watching.mouth.points;
      expectNear(m.first, const Offset(84, 134));
      expectNear(m[3], const Offset(101, 134));
      expectNear(m[6], const Offset(118, 134));
    });
  });

  group('skeptical', () {
    test('both brows are cocked and visible', () {
      expectNear(skeptical.leftBrow.points[0], const Offset(46, 70));
      expectNear(skeptical.leftBrow.points[1], const Offset(66, 74));
      expectNear(skeptical.leftBrow.points[2], const Offset(86, 74));
      expectNear(skeptical.rightBrow.points[0], const Offset(110, 66));
      expectNear(skeptical.rightBrow.points[1], const Offset(127.5, 52));
      expectNear(skeptical.rightBrow.points[2], const Offset(148, 58));
      expect(skeptical.leftBrow.alpha, 1);
      expect(skeptical.rightBrow.alpha, 1);
    });

    test('mouth is a smirk slanting up from (72, 146) to (126, 138)', () {
      final m = skeptical.mouth.points;
      expectNear(m.first, const Offset(72, 146));
      expectNear(m[6], const Offset(126, 138));
    });
  });

  group('brows blend', () {
    test('halfway is half visible and halfway there', () {
      final half = FaceShape.lerp(calm, watching, 0.5);
      expect(half.leftBrow.alpha, 0.5);
      // Calm rests at (56, 70), watching raises it to (56, 68).
      expectNear(half.leftBrow.points[0], const Offset(56, 69));
      // (71, 70) to (70.5, 62).
      expectNear(half.leftBrow.points[1], const Offset(70.75, 66));
      // (86, 70) to (86, 64).
      expectNear(half.leftBrow.points[2], const Offset(86, 67));
      // The other brow stays hidden all the way across.
      expect(half.rightBrow.alpha, 0);
    });

    test('0 and 1 return the two ends', () {
      final start = FaceShape.lerp(calm, skeptical, 0);
      final end = FaceShape.lerp(calm, skeptical, 1);
      expect(start.rightBrow.alpha, 0);
      expectNear(start.rightBrow.points[1], calm.rightBrow.points[1]);
      expect(end.rightBrow.alpha, 1);
      expectNear(end.rightBrow.points[1], skeptical.rightBrow.points[1]);
    });

    test('pen width blends too', () {
      final thick = FaceShape.lerp(
        calm,
        FaceShape(
          leftEye: calm.leftEye,
          rightEye: calm.rightEye,
          mouth: calm.mouth,
          leftBrow: const BrowShape([
            Offset(56, 70),
            Offset(71, 70),
            Offset(86, 70),
          ], width: 20),
        ),
        0.5,
      );
      expect(thick.leftBrow.width, 15);
    });
  });
}

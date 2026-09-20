import 'package:critalarm/design/faces/face_shape.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:flutter_test/flutter_test.dart';

void expectNear(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, 0.001), reason: 'x of $actual');
  expect(actual.dy, closeTo(expected.dy, 0.001), reason: 'y of $actual');
}

void main() {
  final calm = FaceShape.of(FaceState.calm)!;
  final watching = FaceShape.of(FaceState.watching)!;
  final skeptical = FaceShape.of(FaceState.skeptical)!;

  group('which faces can blend', () {
    test('calm, working, success, watching and skeptical all have a shape', () {
      for (final state in [
        FaceState.calm,
        FaceState.working,
        FaceState.success,
        FaceState.watching,
        FaceState.skeptical,
      ]) {
        expect(FaceShape.of(state), isNotNull, reason: '$state');
      }
    });

    test('every eye has 3 points and every mouth has 13', () {
      for (final state in FaceState.values) {
        final shape = FaceShape.of(state);
        if (shape == null) continue;
        expect(shape.leftEye.points, hasLength(3), reason: '$state');
        expect(shape.rightEye.points, hasLength(3), reason: '$state');
        expect(shape.leftBrow.points, hasLength(3), reason: '$state');
        expect(shape.rightBrow.points, hasLength(3), reason: '$state');
        expect(
          shape.mouth.points,
          hasLength(MouthShape.pointCount),
          reason: '$state',
        );
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
      expect(left.first.dx, lessThan(calm.leftEye.points[1].dx));
      expect(left.last.dx, greaterThan(calm.leftEye.points[1].dx));
      // Above the eye, which sits at y 90.
      expect(left.first.dy, lessThan(calm.leftEye.points[1].dy));
    });
  });

  group('watching matches the face the painter draws today', () {
    test('raised left brow M56 68 Q70 58 86 64, sampled at its middle', () {
      expectNear(watching.leftBrow.points[0], const Offset(56, 68));
      expectNear(watching.leftBrow.points[1], const Offset(70.5, 62));
      expectNear(watching.leftBrow.points[2], const Offset(86, 64));
      expect(watching.leftBrow.alpha, 1);
    });

    test('no right brow', () => expect(watching.rightBrow.alpha, 0));

    test('pupils are dots at (80, 92) and (140, 92)', () {
      expect(watching.leftEye.isDot, isTrue);
      expectNear(watching.leftEye.points[1], const Offset(80, 92));
      expectNear(watching.rightEye.points[1], const Offset(140, 92));
    });

    test('mouth is flat from (84, 134) to (118, 134)', () {
      final m = watching.mouth.points;
      expectNear(m.first, const Offset(84, 134));
      expectNear(m[6], const Offset(101, 134));
      expectNear(m.last, const Offset(118, 134));
    });
  });

  group('skeptical matches the face the painter draws today', () {
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
      expectNear(m.last, const Offset(126, 138));
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

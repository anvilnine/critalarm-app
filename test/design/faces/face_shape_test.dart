import 'dart:math' as math;

import 'package:critalarm/design/faces/face_shape.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:flutter_test/flutter_test.dart';

void expectNear(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, 0.001), reason: 'x of $actual');
  expect(actual.dy, closeTo(expected.dy, 0.001), reason: 'y of $actual');
}

void main() {
  final calm = FaceShape.of(FaceState.calm)!;
  final working = FaceShape.of(FaceState.working)!;
  final success = FaceShape.of(FaceState.success)!;

  group('calm matches the face the painter draws today', () {
    test('eyes are r 11 dots at (70, 90) and (130, 90)', () {
      expect(calm.leftEye.isDot, isTrue);
      expect(calm.leftEye.width, 22);
      expectNear(calm.leftEye.points[1], const Offset(70, 90));
      expectNear(calm.rightEye.points[1], const Offset(130, 90));
    });

    test('mouth follows M70 128 Q100 148 130 128', () {
      final m = calm.mouth.points;
      expect(m, hasLength(MouthShape.pointCount));
      expectNear(m.first, const Offset(70, 128));
      expectNear(m[6], const Offset(100, 138));
      expectNear(m.last, const Offset(130, 128));
    });

    test('has no burst', () => expect(calm.burst, 0));
  });

  group('working', () {
    test('eyes are > and < chevrons with a thin pen', () {
      expect(working.leftEye.isDot, isFalse);
      expect(working.leftEye.width, 10);
      expectNear(working.leftEye.points[0], const Offset(58, 80));
      expectNear(working.leftEye.points[1], const Offset(78, 90));
      expectNear(working.leftEye.points[2], const Offset(58, 100));
      expectNear(working.rightEye.points[1], const Offset(122, 90));
    });

    test('mouth wiggles 1.5 waves between x 70 and x 130', () {
      final m = working.mouth.points;
      expectNear(m.first, const Offset(70, 134));
      expectNear(m.last, Offset(130, 134 + 6 * math.sin(3 * math.pi)));
      // One sixth of the way in is the first crest.
      expectNear(m[2], Offset(80, 134 + 6 * math.sin(3 * math.pi / 6)));
    });
  });

  group('success', () {
    test('mouth is a v with its tip at (100, 140)', () {
      final m = success.mouth.points;
      expectNear(m.first, const Offset(88, 128));
      expectNear(m[6], const Offset(100, 140));
      expectNear(m.last, const Offset(112, 128));
    });

    test('eyes are dots at (70, 88) and (130, 88), burst is full', () {
      expect(success.leftEye.isDot, isTrue);
      expectNear(success.leftEye.points[0], const Offset(70, 88));
      expectNear(success.rightEye.points[2], const Offset(130, 88));
      expect(success.burst, 1);
    });
  });

  group('lerp', () {
    test('0 and 1 return the two ends', () {
      final start = FaceShape.lerp(calm, working, 0);
      final end = FaceShape.lerp(calm, working, 1);
      expectNear(start.leftEye.points[0], calm.leftEye.points[0]);
      expectNear(end.leftEye.points[0], working.leftEye.points[0]);
      expectNear(end.mouth.points[3], working.mouth.points[3]);
    });

    test('halfway moves every point and width halfway', () {
      final half = FaceShape.lerp(calm, working, 0.5);
      expectNear(half.leftEye.points[0], const Offset(64, 85));
      expect(half.leftEye.width, 16);
      expect(half.leftEye.isDot, isFalse);
    });

    test('burst blends too', () {
      expect(FaceShape.lerp(working, success, 0.25).burst, 0.25);
    });
  });

  test('faces drawn the old way have no shape', () {
    for (final state in [
      FaceState.watching,
      FaceState.worried,
      FaceState.alarmed,
      FaceState.acked,
    ]) {
      expect(FaceShape.of(state), isNull, reason: '$state');
    }
  });
}

import 'dart:math' as math;
import 'dart:ui' show Offset, lerpDouble;

import 'package:critalarm/design/faces/face_state.dart';

/// One eye, drawn as a line through three points.
///
/// A dot is three points on one spot drawn with a wide round pen, so a dot can
/// stretch into a `>` by moving the points apart and thinning the pen.
class EyeShape {
  /// An eye through [points] (always three) drawn with a pen [width] wide.
  const EyeShape(this.points, this.width);

  /// A round r 11 dot at [centre], the eye most faces use.
  EyeShape.dot(Offset centre) : points = [centre, centre, centre], width = 22;

  /// Moves every point and the pen width [t] of the way from [a] to [b].
  factory EyeShape.lerp(EyeShape a, EyeShape b, double t) => EyeShape(
    _lerpPoints(a.points, b.points, t),
    lerpDouble(a.width, b.width, t)!,
  );

  /// Three points, in the painter's 200 unit box.
  final List<Offset> points;

  /// Pen width in 200 unit box units.
  final double width;

  /// True when the three points sit on one spot, so the eye is a dot.
  bool get isDot =>
      (points[0] - points[1]).distance < 0.5 &&
      (points[2] - points[1]).distance < 0.5;
}

/// The mouth, drawn as a smooth curve through [pointCount] points.
class MouthShape {
  /// A mouth through [points] (always [pointCount]).
  const MouthShape(this.points, {this.width = 10});

  /// Moves every point and the pen width [t] of the way from [a] to [b].
  factory MouthShape.lerp(MouthShape a, MouthShape b, double t) => MouthShape(
    _lerpPoints(a.points, b.points, t),
    width: lerpDouble(a.width, b.width, t)!,
  );

  /// Every mouth has this many points, so any two can be blended.
  static const int pointCount = 13;

  /// Points in the painter's 200 unit box, left to right.
  final List<Offset> points;

  /// Pen width in 200 unit box units.
  final double width;
}

/// A whole face as shapes that can blend into each other. Only the faces the
/// refresh uses have one: calm, working and success.
class FaceShape {
  /// A face made of two eyes, a mouth and the success lines.
  const FaceShape({
    required this.leftEye,
    required this.rightEye,
    required this.mouth,
    this.burst = 0,
  });

  /// Blends every part [t] of the way from [a] to [b].
  factory FaceShape.lerp(FaceShape a, FaceShape b, double t) => FaceShape(
    leftEye: EyeShape.lerp(a.leftEye, b.leftEye, t),
    rightEye: EyeShape.lerp(a.rightEye, b.rightEye, t),
    mouth: MouthShape.lerp(a.mouth, b.mouth, t),
    burst: lerpDouble(a.burst, b.burst, t)!,
  );

  /// The eye on the left of the screen.
  final EyeShape leftEye;

  /// The eye on the right of the screen.
  final EyeShape rightEye;

  /// The mouth.
  final MouthShape mouth;

  /// How far out the three success lines above the head are, 0 to 1.
  final double burst;

  /// The shape for [state], or null for faces the painter draws the old way.
  static FaceShape? of(FaceState state) => switch (state) {
    FaceState.calm => _calm,
    FaceState.working => _working,
    FaceState.success => _success,
    _ => null,
  };
}

List<Offset> _lerpPoints(List<Offset> a, List<Offset> b, double t) => [
  for (var i = 0; i < a.length; i++) Offset.lerp(a[i], b[i], t)!,
];

/// Samples a curve at [MouthShape.pointCount] evenly spaced steps from 0 to 1.
List<Offset> _sample(Offset Function(double t) at) => [
  for (var i = 0; i < MouthShape.pointCount; i++)
    at(i / (MouthShape.pointCount - 1)),
];

Offset _quad(Offset p0, Offset p1, Offset p2, double t) =>
    p0 * ((1 - t) * (1 - t)) + p1 * (2 * (1 - t) * t) + p2 * (t * t);

final FaceShape _calm = FaceShape(
  leftEye: EyeShape.dot(const Offset(70, 90)),
  rightEye: EyeShape.dot(const Offset(130, 90)),
  // M70 128 Q100 148 130 128, the calm mouth in face_painter.dart.
  mouth: MouthShape(
    _sample(
      (t) => _quad(
        const Offset(70, 128),
        const Offset(100, 148),
        const Offset(130, 128),
        t,
      ),
    ),
  ),
);

final FaceShape _working = FaceShape(
  leftEye: const EyeShape(
    [Offset(58, 80), Offset(78, 90), Offset(58, 100)],
    10,
  ),
  rightEye: const EyeShape(
    [Offset(142, 80), Offset(122, 90), Offset(142, 100)],
    10,
  ),
  // 1.5 waves, 6 units tall, around y 134.
  mouth: MouthShape(
    _sample((t) => Offset(70 + 60 * t, 134 + 6 * math.sin(3 * math.pi * t))),
  ),
);

final FaceShape _success = FaceShape(
  leftEye: EyeShape.dot(const Offset(70, 88)),
  rightEye: EyeShape.dot(const Offset(130, 88)),
  mouth: MouthShape(
    _sample(
      (t) => t <= 0.5
          ? Offset.lerp(const Offset(88, 128), const Offset(100, 140), t * 2)!
          : Offset.lerp(
              const Offset(100, 140),
              const Offset(112, 128),
              (t - 0.5) * 2,
            )!,
    ),
  ),
  burst: 1,
);

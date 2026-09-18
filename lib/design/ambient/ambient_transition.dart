import 'dart:math' as math;

import 'package:critalarm/design/ambient/ambient_shape.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:flutter/material.dart';

/// Navigation directions that drive ambient shape displacement.
enum AmbientDirection { left, right, push, pop }

/// Helper to compute directional movement between tab indices.
AmbientDirection tabDirection({required int current, required int next}) =>
    next > current ? AmbientDirection.right : AmbientDirection.left;

extension AmbientDirectionX on AmbientDirection {
  AmbientDirection get reversed => switch (this) {
    AmbientDirection.left => AmbientDirection.right,
    AmbientDirection.right => AmbientDirection.left,
    AmbientDirection.push => AmbientDirection.pop,
    AmbientDirection.pop => AmbientDirection.push,
  };
}

/// Motion flavors for ambient transition displacement.
enum AmbientMotionVariant { drift, sweep, orbit }

/// Transforms linear animation progress into easing, respecting reduced motion.
double resolveAmbientProgress({
  required double progress,
  required bool reduceMotion,
}) {
  if (reduceMotion) {
    return 1;
  }

  return AppCurves.easeOut.transform(progress.clamp(0.0, 1.0));
}

/// Resolved spatial pose of an ambient shape at an intermediate point in time.
@immutable
class AmbientPose {
  const AmbientPose({
    required this.anchor,
    required this.scale,
    required this.turns,
  });

  final Alignment anchor;
  final double scale;
  final double turns;

  @override
  bool operator ==(Object other) {
    return other is AmbientPose &&
        anchor == other.anchor &&
        scale == other.scale &&
        turns == other.turns;
  }

  @override
  int get hashCode => Object.hash(anchor, scale, turns);
}

/// Computes the dynamic intermediate pose for a shape during transition.
AmbientPose resolveAmbientPose({
  required AmbientShape shape,
  required AmbientMotionVariant variant,
  required AmbientDirection direction,
  required double progress,
}) {
  final t = progress.clamp(0.0, 1.0);
  if (t == 0.0 || t == 1.0) {
    return AmbientPose(
      anchor: shape.anchor,
      scale: shape.scale,
      turns: shape.turns,
    );
  }

  final directionSign = switch (direction) {
    AmbientDirection.left || AmbientDirection.pop => -1.0,
    AmbientDirection.right || AmbientDirection.push => 1.0,
  };

  return switch (variant) {
    AmbientMotionVariant.drift => _driftPose(shape, t, directionSign),
    AmbientMotionVariant.sweep => _sweepPose(shape, t, directionSign),
    AmbientMotionVariant.orbit => _orbitPose(shape, t, directionSign),
  };
}

AmbientPose _driftPose(
  AmbientShape shape,
  double t,
  double directionSign,
) {
  final magnitude = math.sin(math.pi * t) * shape.depth;
  return AmbientPose(
    anchor: Alignment(
      shape.anchor.x - (directionSign * magnitude * 0.08),
      shape.anchor.y + (magnitude * 0.04),
    ),
    scale: shape.scale * (1 + (magnitude * 0.03)),
    turns: shape.turns,
  );
}

AmbientPose _sweepPose(
  AmbientShape shape,
  double t,
  double directionSign,
) {
  final magnitude = math.sin(math.pi * t) * shape.depth;
  return AmbientPose(
    anchor: Alignment(
      shape.anchor.x - (directionSign * magnitude * 0.28),
      shape.anchor.y,
    ),
    scale: shape.scale * (1 + (magnitude * 0.07)),
    turns: shape.turns - (directionSign * magnitude * 0.04),
  );
}

AmbientPose _orbitPose(AmbientShape shape, double t, double directionSign) {
  final orbitProgress = math.sin(math.pi * t) * shape.depth;
  return AmbientPose(
    anchor: Alignment(
      shape.anchor.x + (directionSign * orbitProgress * 0.06),
      shape.anchor.y - (orbitProgress * 0.06),
    ),
    scale: shape.scale * (1 + (orbitProgress * 0.04)),
    turns: shape.turns + (directionSign * orbitProgress * 0.18),
  );
}

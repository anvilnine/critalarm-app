import 'package:critalarm/design/ambient/ambient_shape.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Full visual composition for a screen or state rendered on an ambient
/// canvas.
@immutable
class AmbientProfile {
  const AmbientProfile({
    required this.canvas,
    required this.surfaceOpacity,
    required this.shapes,
  });

  /// The solid or tinted background canvas color behind the shapes.
  final Color canvas;

  /// Target opacity for foreground surfaces/sheets (0.0 to 1.0) so ambient
  /// shapes can subtly diffuse through them.
  final double surfaceOpacity;

  /// Ordered list of geometric shapes drawn in depth layers.
  final List<AmbientShape> shapes;

  /// Interpolates linearly between two ambient profiles.
  // ignore: prefer_constructors_over_static_methods
  static AmbientProfile lerp(AmbientProfile a, AmbientProfile b, double t) {
    assert(
      a.shapes.length == b.shapes.length,
      'Profiles must have matching shape counts.',
    );

    final progress = t.clamp(0.0, 1.0);
    if (progress == 0.0) return a;
    if (progress == 1.0) return b;

    return AmbientProfile(
      canvas: Color.lerp(a.canvas, b.canvas, progress)!,
      surfaceOpacity: _lerp(
        a.surfaceOpacity,
        b.surfaceOpacity,
        progress,
      ).clamp(0.0, 1.0),
      shapes: List<AmbientShape>.unmodifiable([
        for (var index = 0; index < a.shapes.length; index++)
          AmbientShape.lerp(a.shapes[index], b.shapes[index], progress),
      ]),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AmbientProfile &&
        canvas == other.canvas &&
        surfaceOpacity == other.surfaceOpacity &&
        listEquals(shapes, other.shapes);
  }

  @override
  int get hashCode =>
      Object.hash(canvas, surfaceOpacity, Object.hashAll(shapes));
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

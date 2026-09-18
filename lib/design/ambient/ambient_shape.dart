import 'package:flutter/material.dart';

/// A single decorative geometric shape floating in depth on an ambient canvas.
@immutable
class AmbientShape {
  const AmbientShape({
    required this.color,
    required this.opacity,
    required this.anchor,
    required this.scale,
    required this.turns,
    required this.depth,
  });

  /// Base color of the shape.
  final Color color;

  /// Transparency alpha (0.0 to 1.0).
  final double opacity;

  /// Anchor position in normalized coordinates (-1.0 to 1.0).
  final Alignment anchor;

  /// Scale relative to screen shortest side (0.0 to 1.0).
  final double scale;

  /// Rotation in turns (1.0 = 360 degrees).
  final double turns;

  /// Depth coefficient (0.0 foreground to 1.0 background) controlling parallax
  /// displacement speed and response during transitions.
  final double depth;

  /// Interpolates linearly between two ambient shapes.
  // ignore: prefer_constructors_over_static_methods
  static AmbientShape lerp(AmbientShape a, AmbientShape b, double t) {
    final progress = t.clamp(0.0, 1.0);

    return AmbientShape(
      color: Color.lerp(a.color, b.color, progress)!,
      opacity: _lerp(a.opacity, b.opacity, progress).clamp(0.0, 1.0),
      anchor: Alignment.lerp(a.anchor, b.anchor, progress)!,
      scale: _lerp(a.scale, b.scale, progress).clamp(0.0, 1.0),
      turns: _lerp(a.turns, b.turns, progress),
      depth: _lerp(a.depth, b.depth, progress).clamp(0.0, 1.0),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AmbientShape &&
        color == other.color &&
        opacity == other.opacity &&
        anchor == other.anchor &&
        scale == other.scale &&
        turns == other.turns &&
        depth == other.depth;
  }

  @override
  int get hashCode => Object.hash(color, opacity, anchor, scale, turns, depth);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

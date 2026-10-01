import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Where a tilt sits on its path: both axes in -1..1.
typedef TiltPose = ({double x, double y});

/// The tilt at [t] (0..1, one full period) for a tile with [phase] radians of
/// offset.
///
/// A Lissajous path: x runs once per period and y twice, so the pose drifts
/// around instead of retracing a line, and the restart at t = 1 is invisible.
TiltPose tiltPoseAt(double t, {double phase = 0}) {
  final a = 2 * math.pi * t;
  return (x: math.sin(a + phase), y: math.sin(2 * a + phase * 1.7 + 0.6));
}

/// A tile that tilts on its own in 3D, with a glare that follows the tilt and
/// a shadow that slides the other way.
///
/// [clock] is one slow repeating controller (0..1) the parent shares between
/// tiles; [phase] keeps neighbours out of step. With [animate] false the tile
/// holds a fixed slight angle and draws no glare.
class TiltShowcase extends StatelessWidget {
  const TiltShowcase({
    required this.clock,
    required this.child,
    required this.borderRadius,
    this.phase = 0,
    this.animate = true,
    this.maxAngle = 11 * math.pi / 180,
    this.glareOpacity = 0.22,
    super.key,
  });

  final Animation<double> clock;

  /// The artwork. The glare is clipped to [borderRadius] on top of it.
  final Widget child;
  final BorderRadius borderRadius;
  final double phase;
  final bool animate;

  /// The largest rotation on either axis, in radians.
  final double maxAngle;

  /// The glare's peak alpha. Kept low: it is a sheen, not a spotlight.
  final double glareOpacity;

  @override
  Widget build(BuildContext context) {
    // The artwork does not change per frame, so it is built once and handed
    // through.
    final art = child;
    if (!animate) {
      return Transform(
        alignment: Alignment.center,
        transform: _matrix(0.3, -0.3, maxAngle * 0.5),
        child: _shadowed(0.3, -0.3, art, glare: false),
      );
    }
    return AnimatedBuilder(
      animation: clock,
      child: art,
      builder: (context, art) {
        final pose = tiltPoseAt(clock.value, phase: phase);
        return Transform(
          alignment: Alignment.center,
          transform: _matrix(pose.x, pose.y, maxAngle),
          child: _shadowed(pose.x, pose.y, art!, glare: true),
        );
      },
    );
  }

  Matrix4 _matrix(double x, double y, double max) => Matrix4.identity()
    ..setEntry(3, 2, 0.0012)
    ..rotateX(-y * max)
    ..rotateY(x * max);

  Widget _shadowed(double x, double y, Widget art, {required bool glare}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: const Color(0x40000000),
            blurRadius: 28,
            // Opposite the lean, so the tile reads as floating above the page.
            offset: Offset(-x * 12, 18 + y * 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            art,
            if (glare)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _glare(x, y, glareOpacity),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// A soft diagonal band whose centre slides with the tilt.
  static LinearGradient _glare(double x, double y, double opacity) {
    final c = 0.5 + 0.4 * (x + y) / 2;
    double at(double v) => v.clamp(0.0, 1.0);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0x00FFFFFF),
        Color.fromRGBO(255, 255, 255, opacity),
        const Color(0x00FFFFFF),
      ],
      stops: [at(c - 0.3), at(c), at(c + 0.3)],
    );
  }
}

import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:flutter/material.dart';

/// What one drifting shape is.
enum _Kind { disc, ring, pill, spark }

/// Which of the painter's colours a shape takes.
enum _Ink { soft, strong, light }

/// One shape of the atmosphere. [at] is its home, as a share of the stage's
/// width and height. It drifts a few points either way around it, once
/// every [every] seconds.
class _Shape {
  const _Shape(
    this.kind,
    this.at,
    this.size,
    this.ink, {
    required this.every,
    this.turn = 0,
  });

  /// How far a shape drifts from home, in points.
  static const double reach = 7;

  final _Kind kind;
  final Offset at;
  final double size;
  final _Ink ink;
  final double every;

  /// Where in its drift the shape starts, as a share of a full turn.
  final double turn;
}

/// The shapes, back to front. They keep to the edges of the stage, where
/// the mascot and the card are not.
const _shapes = <_Shape>[
  _Shape(_Kind.disc, Offset(0.1, 0.8), 24, _Ink.soft, every: 9, turn: 0.1),
  _Shape(_Kind.ring, Offset(0.9, 0.2), 15, _Ink.strong, every: 11, turn: 0.4),
  _Shape(_Kind.disc, Offset(0.72, 0.07), 7, _Ink.strong, every: 7, turn: 0.7),
  _Shape(_Kind.pill, Offset(0.2, 0.62), 40, _Ink.light, every: 10, turn: 0.55),
  _Shape(_Kind.spark, Offset(0.62, 0.22), 11, _Ink.light, every: 8, turn: 0.2),
  _Shape(_Kind.disc, Offset(0.95, 0.52), 20, _Ink.light, every: 12, turn: 0.9),
  _Shape(_Kind.ring, Offset(0.3, 0.93), 9, _Ink.strong, every: 8, turn: 0.3),
];

/// The air behind the mascot: one large disc it stands in front of and a
/// few small shapes drifting at the edges. [HeroAtmosphere] is the widget
/// that picks the colours. Use the painter where a layout has its own.
///
/// Every shape is round or upright, so the resting frame has nothing at an
/// angle. With [seconds] at zero the shapes sit at home.
class HeroAtmospherePainter extends CustomPainter {
  const HeroAtmospherePainter({
    required this.focus,
    required this.radius,
    required this.seconds,
    required this.entrance,
    required this.showsShapes,
    required this.disc,
    required this.soft,
    required this.strong,
    required this.light,
  });

  /// The middle of the mascot and the card, where the disc sits.
  final Offset focus;
  final double radius;
  final double seconds;

  /// How far through the entrance, 0 to 1.
  final double entrance;

  /// False draws the disc alone, for a stage too short to keep the shapes
  /// clear of the close cross.
  final bool showsShapes;
  final Color disc;
  final Color soft;
  final Color strong;
  final Color light;

  @override
  void paint(Canvas canvas, Size size) {
    // The disc grows out from the middle.
    final grow = AppCurves.easeOut.transform(phase(entrance, 0, 0.7));
    final breathe = seconds == 0
        ? 0.0
        : math.sin(2 * math.pi * seconds / 6) * 0.012;
    canvas.drawCircle(
      focus,
      radius * (0.55 + 0.45 * grow) * (1 + breathe),
      Paint()..color = disc.withValues(alpha: disc.a * grow),
    );
    if (!showsShapes) return;
    for (final (i, shape) in _shapes.indexed) {
      // Each one comes in from further out, one after another.
      final p = AppCurves.easeOut.transform(
        phase(stagger(i, entrance, each: 0.05), 0.1, 0.75),
      );
      if (p <= 0) continue;
      final home = Offset(shape.at.dx * size.width, shape.at.dy * size.height);
      final angle = 2 * math.pi * (seconds / shape.every + shape.turn);
      final drift = seconds == 0
          ? Offset.zero
          : Offset(math.cos(angle), math.sin(angle * 0.7)) * _Shape.reach;
      final from = home + (home - focus) * 0.35;
      final at = Offset.lerp(from, home, p)! + drift;
      final base = switch (shape.ink) {
        _Ink.soft => soft,
        _Ink.strong => strong,
        _Ink.light => light,
      };
      final paint = Paint()..color = base.withValues(alpha: base.a * p);

      switch (shape.kind) {
        case _Kind.disc:
          canvas.drawCircle(at, shape.size, paint);
        case _Kind.ring:
          canvas.drawCircle(
            at,
            shape.size,
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = shape.size * 0.34,
          );
        case _Kind.pill:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: at,
                width: shape.size,
                height: shape.size * 0.4,
              ),
              Radius.circular(shape.size),
            ),
            paint,
          );
        case _Kind.spark:
          // A four point star, upright.
          final r = shape.size;
          final w = r * 0.24;
          canvas.drawPath(
            Path()
              ..moveTo(at.dx, at.dy - r)
              ..quadraticBezierTo(at.dx + w, at.dy - w, at.dx + r, at.dy)
              ..quadraticBezierTo(at.dx + w, at.dy + w, at.dx, at.dy + r)
              ..quadraticBezierTo(at.dx - w, at.dy + w, at.dx - r, at.dy)
              ..quadraticBezierTo(at.dx - w, at.dy - w, at.dx, at.dy - r)
              ..close(),
            paint,
          );
      }
    }
  }

  @override
  bool shouldRepaint(HeroAtmospherePainter old) =>
      seconds != old.seconds ||
      entrance != old.entrance ||
      showsShapes != old.showsShapes ||
      focus != old.focus ||
      radius != old.radius ||
      disc != old.disc ||
      soft != old.soft ||
      strong != old.strong ||
      light != old.light;
}

/// The four colours of the atmosphere on one [PaywallTone], in the current
/// theme.
@immutable
class HeroAtmosphereColors {
  const HeroAtmosphereColors({
    required this.disc,
    required this.soft,
    required this.strong,
    required this.light,
  });

  /// On the canvas these are the approved colours. On any other tone the
  /// disc and the shapes are tints of that tone's ink, so they read on it
  /// in both themes and never add a colour.
  factory HeroAtmosphereColors.of(BuildContext context, PaywallTone tone) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (tone != PaywallTone.canvas) {
      final ink = PaywallToneColors.of(context, tone).ink;
      return HeroAtmosphereColors(
        disc: ink.withValues(alpha: 0.06),
        soft: ink.withValues(alpha: 0.07),
        strong: ink.withValues(alpha: 0.14),
        light: ink.withValues(alpha: 0.1),
      );
    }
    return HeroAtmosphereColors(
      // The dark canvas gets a little of the yellow back, or the stage
      // would be one flat black.
      disc: isDark
          ? Color.alphaBlend(
              colors.yellow.withValues(alpha: 0.07),
              colors.canvasAlt,
            )
          : colors.canvasAlt,
      soft: isDark ? colors.yellow.withValues(alpha: 0.07) : colors.canvasGhost,
      strong: isDark
          ? colors.yellow.withValues(alpha: 0.16)
          : colors.canvasGhostStrong,
      light: colors.surface.withValues(alpha: isDark ? 0.5 : 0.4),
    );
  }

  final Color disc;
  final Color soft;
  final Color strong;
  final Color light;
}

/// The atmosphere alone: the disc and the drifting shapes, filling the box
/// it is given, in the colours of [tone].
///
/// The stage draws one behind the mascot. Use this where a layout wants
/// the same air with no stage: behind a headline, a receipt, a pair of
/// doors. It holds no time: pass the clock as [seconds] (zero when nothing
/// may move) and how far in it is as [entrance].
class HeroAtmosphere extends StatelessWidget {
  const HeroAtmosphere({
    required this.focus,
    required this.radius,
    this.seconds = 0,
    this.entrance = 1,
    this.showsShapes = true,
    this.tone = PaywallTone.canvas,
    this.child,
    super.key,
  });

  /// Where the disc sits, in the box's own points, and how large it is.
  final Offset focus;
  final double radius;

  /// The clock, for the drift. Zero holds every shape at home.
  final double seconds;

  /// How far through the entrance, 0 to 1: the disc grows out and the
  /// shapes drift in from further out, one after another.
  final double entrance;

  /// False draws the disc alone.
  final bool showsShapes;
  final PaywallTone tone;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = HeroAtmosphereColors.of(context, tone);
    return CustomPaint(
      painter: HeroAtmospherePainter(
        focus: focus,
        radius: radius,
        seconds: seconds,
        entrance: entrance,
        showsShapes: showsShapes,
        disc: colors.disc,
        soft: colors.soft,
        strong: colors.strong,
        light: colors.light,
      ),
      child: child,
    );
  }
}

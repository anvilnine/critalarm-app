import 'dart:async';

import 'package:critalarm/design/components/radios.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design_system/motion.dart';
import 'package:flutter/material.dart';

/// How long the whole tick takes: two base transitions.
final Duration tickDuration = AppDurations.base * 2;

/// The point in the timeline where the fill has landed and the tick starts.
/// The fill gets the first third and the tick the rest: the spring curve is
/// most of the way out in half its time, so a longer fill leaves the disc
/// sitting full with nothing happening.
const double tickFillEnds = 1 / 3;

/// Where an [AppAnimatedTick] is at time [t] (0 to 1) of its one play.
///
/// `fill` is how far the disc has grown out from the middle of the ring. It
/// runs on the spring curve, so it swells a hair past 1 before it settles, the
/// way a face pops in. `draw` is how much of the tick's stroke is on, from 0 to
/// 1, and it stays at 0 until the fill has landed.
///
/// With [reduceMotion] there is nothing in between: 0 is the empty ring and
/// anything after it is the finished tick.
({double fill, double draw}) tickProgress(
  double t, {
  bool reduceMotion = false,
}) {
  final v = t.clamp(0.0, 1.0);
  if (v == 0) return (fill: 0, draw: 0);
  if (reduceMotion || v == 1) return (fill: 1, draw: 1);
  if (v <= tickFillEnds) {
    return (fill: AppCurves.easeSpring.transform(v / tickFillEnds), draw: 0);
  }
  final sub = (v - tickFillEnds) / (1 - tickFillEnds);
  return (fill: 1, draw: AppCurves.easeOut.transform(sub));
}

/// A ring that fills and draws a tick when [done] turns true.
///
/// Use it for one thing finishing while the user watches: the first message
/// landing, a checklist step. For a static "included" mark in a list, use
/// `AppFeatureBullet`.
///
/// It plays once, on the change from false to true. A tick built already done
/// shows finished, and one that goes back to false empties at once. With
/// animations switched off it never plays.
///
/// The tick says nothing to a screen reader. Wrap it in a `Semantics` with a
/// label for what is done.
class AppAnimatedTick extends StatefulWidget {
  const AppAnimatedTick({
    required this.done,
    this.size = 24,
    this.fillColor,
    this.tickColor,
    this.ringColor,
    super.key,
  });

  final bool done;

  /// The disc. Defaults to the highlight, which is right on a card and on
  /// the plain canvas. On the acknowledged canvas the highlight is the
  /// canvas itself, so a caller there passes its text colour.
  final Color? fillColor;

  /// The tick drawn on the disc. Defaults to the text colour on highlight.
  final Color? tickColor;

  /// The empty ring. Defaults to a quiet ink.
  final Color? ringColor;

  /// Width and height.
  final double size;

  @override
  State<AppAnimatedTick> createState() => _AppAnimatedTickState();
}

class _AppAnimatedTickState extends State<AppAnimatedTick>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: tickDuration,
    value: widget.done ? 1 : 0,
  );

  @override
  void didUpdateWidget(covariant AppAnimatedTick oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.done == widget.done) return;
    if (!widget.done) {
      _controller.value = 0;
      return;
    }
    final duration = context.motion(tickDuration);
    if (duration == Duration.zero) {
      _controller.value = 1;
    } else {
      _controller.duration = duration;
      unawaited(_controller.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final reduceMotion = context.reduceMotion;

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final (:fill, :draw) = tickProgress(
              _controller.value,
              reduceMotion: reduceMotion,
            );
            return CustomPaint(
              painter: _TickPainter(
                fill: fill,
                draw: draw,
                ringColor:
                    widget.ringColor ??
                    colors.ink.withValues(alpha: radioRingAlpha),
                fillColor: widget.fillColor ?? colors.highlight,
                tickColor: widget.tickColor ?? colors.onHighlight,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Paints the ring, the disc growing over it and the tick, in a 24 unit box.
class _TickPainter extends CustomPainter {
  const _TickPainter({
    required this.fill,
    required this.draw,
    required this.ringColor,
    required this.fillColor,
    required this.tickColor,
  });

  final double fill;
  final double draw;
  final Color ringColor;
  final Color fillColor;
  final Color tickColor;

  static const double _box = 24;
  static const double _ringWidth = 2;
  static const double _tickWidth = 2.6;

  /// The check glyph's path, pulled in to sit inside the disc.
  static final Path _tick = Path()
    ..moveTo(7, 12.4)
    ..lineTo(10.6, 16)
    ..lineTo(17, 8.6);

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / _box, size.height / _box);
    const centre = Offset(_box / 2, _box / 2);
    const radius = _box / 2;

    // The empty ring. The disc covers it once it has grown all the way out,
    // so it is skipped from then on rather than left showing at the edge.
    if (fill < 1) {
      canvas.drawCircle(
        centre,
        radius - _ringWidth / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _ringWidth
          // The ring takes the disc's colour as the disc reaches it, so the
          // two meet as one shape instead of a grey edge round a blue one.
          ..color = Color.lerp(ringColor, fillColor, fill.clamp(0.0, 1.0))!,
      );
    }

    if (fill > 0) {
      canvas.drawCircle(centre, radius * fill, Paint()..color = fillColor);
    }

    if (draw > 0) {
      final pen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _tickWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = tickColor;
      for (final metric in _tick.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * draw), pen);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TickPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.draw != draw ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.tickColor != tickColor;
}

import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/screen_clock.dart';
import 'package:critalarm/features/reliability/domain/wake_answer.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// The way an alarm takes, drawn as four stops joined by a wire: your tool,
// the server, the push and this phone. A stop that is not fine turns red and
// the wire past it is dashed, so the screen says where an alarm would stop
// without a word. A dot travels the wire on one clock. Under reduced motion
// the dot, the ring, the swell and the breathing disc are gone and the
// colour, the glyph and the dashes still say the same thing.

/// Owns the one clock the header and the path move on.
///
/// It builds [builder] once and ticks a [ValueListenable] of seconds, so only
/// the parts that listen redraw on a tick. The clock stops while the route is
/// covered and while the app is not resumed, and under reduce motion it
/// never runs: `isStill` is then true.
class WakeClock extends StatefulWidget {
  const WakeClock({required this.builder, super.key});

  final Widget Function(
    BuildContext context,
    ValueListenable<double> clock, {
    required bool isStill,
  })
  builder;

  @override
  State<WakeClock> createState() => _WakeClockState();
}

class _WakeClockState extends PaywallClockState<WakeClock> {
  final _clock = ValueNotifier<double>(0);

  @override
  double get restAt => 0;

  @override
  void onTick() => _clock.value = t;

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _clock, isStill: isStill);
}

/// The path of four stops with the wire and the dot.
class WakePath extends StatelessWidget {
  const WakePath({
    required this.stops,
    required this.clock,
    required this.isStill,
    super.key,
  });

  final List<WakeStopStatus> stops;
  final ValueListenable<double> clock;
  final bool isStill;

  /// The size of a stop at ordinary text, and at large text.
  static const double nodeSize = 56;
  static const double smallNodeSize = 44;

  /// Room round a node for the ring and the count badge.
  static const double _slack = 14;

  static String stopLabel(WakeStop stop) => switch (stop) {
    WakeStop.tool => LocaleKeys.wake_stop_tool.tr(),
    WakeStop.server => LocaleKeys.wake_stop_server.tr(),
    WakeStop.push => LocaleKeys.wake_stop_push.tr(),
    WakeStop.phone => LocaleKeys.wake_stop_phone.tr(),
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isLarge = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final node = isLarge ? smallNodeSize : nodeSize;
    final bad = wakeBadStops(stops);
    final firstBad = bad.isEmpty ? null : bad.first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: wakeSideMargin),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final column = constraints.maxWidth / stops.length;
          // The wire runs from the middle of the first stop to the middle
          // of the last.
          final x0 = column / 2;
          final x1 = constraints.maxWidth - column / 2;
          final y = (node + _slack) / 2;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _WirePainter(
                    x0: x0,
                    x1: x1,
                    y: y,
                    badX: firstBad == null
                        ? null
                        : x0 + (x1 - x0) * firstBad.stop.index / 3,
                    wire: colors.ink,
                    badWire: colors.critText,
                  ),
                ),
              ),
              if (!isStill)
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      painter: _DotPainter(
                        clock: clock,
                        x0: x0,
                        x1: x1,
                        y: y,
                        color: colors.cobalt,
                        brokenStop: firstBad?.stop,
                        brokenCount: bad.length,
                      ),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final status in stops)
                    Expanded(
                      child: _Stop(
                        status: status,
                        size: node,
                        clock: clock,
                        isStill: isStill,
                        // The last stop swells as the dot lands, when the
                        // dot gets that far.
                        swells: status.stop == WakeStop.phone && bad.isEmpty,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({
    required this.status,
    required this.size,
    required this.clock,
    required this.isStill,
    required this.swells,
  });

  final WakeStopStatus status;
  final double size;
  final ValueListenable<double> clock;
  final bool isStill;
  final bool swells;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isBad = !status.isFine;
    final label = WakePath.stopLabel(status.stop);
    final spoken = isBad
        ? LocaleKeys.wake_stop_problems_aria_label.plural(
            status.problems,
            namedArgs: {'stop': label},
          )
        : LocaleKeys.wake_stop_ok_aria_label.tr(namedArgs: {'stop': label});

    final glyph = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _StopGlyphPainter(
          stop: status.stop,
          color: isBad ? colors.onHighlight : colors.canvas,
          scale: size / WakePath.nodeSize,
        ),
      ),
    );

    Widget node(double ring, double ringStrength, double scale) {
      return Transform.scale(
        scale: scale,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isBad ? colors.crit : colors.ink,
            borderRadius: BorderRadius.circular(size * 19 / 56),
            boxShadow: [
              if (ring > 0)
                BoxShadow(
                  color: colors.crit.withValues(alpha: 0.7 * ringStrength),
                  spreadRadius: ring,
                ),
            ],
          ),
          child: glyph,
        ),
      );
    }

    final Widget drawn;
    if (isStill || !(isBad || swells)) {
      drawn = node(0, 0, 1);
    } else {
      drawn = ValueListenableBuilder<double>(
        valueListenable: clock,
        builder: (context, t, _) {
          if (isBad) {
            final pulse = wakePulseAt(t);
            return node(pulse.reach, pulse.strength, 1);
          }
          return node(0, 0, wakeLandScaleAt(t));
        },
      );
    }

    return Semantics(
      container: true,
      label: spoken,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size + WakePath._slack,
            height: size + WakePath._slack,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                drawn,
                if (status.problems >= 2)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: _CountBadge(count: status.problems),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  AppTypography.small(
                    isBad ? colors.critText : colors.onCanvas,
                    fontSize: 12.5,
                  ).copyWith(
                    fontWeight: isBad ? FontWeight.w700 : FontWeight.w600,
                    height: 1.2,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.crit, width: 2),
      ),
      child: Text(
        '$count',
        // A figure, not words.
        textScaler: TextScaler.noScaling,
        style: AppTypography.body(
          colors.critText,
          fontSize: 12,
        ).copyWith(fontWeight: FontWeight.w800, height: 1),
      ),
    );
  }
}

/// The wire: solid ink up to the first stop that is not fine, dashed red
/// from there to the end.
class _WirePainter extends CustomPainter {
  const _WirePainter({
    required this.x0,
    required this.x1,
    required this.y,
    required this.badX,
    required this.wire,
    required this.badWire,
  });

  final double x0;
  final double x1;
  final double y;
  final double? badX;
  final Color wire;
  final Color badWire;

  static const double _width = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final solid = Paint()
      ..color = wire
      ..strokeWidth = _width
      ..strokeCap = StrokeCap.butt;
    final solidEnd = badX ?? x1;
    canvas.drawLine(Offset(x0, y), Offset(solidEnd, y), solid);
    if (badX == null) return;
    final dashed = Paint()
      ..color = badWire
      ..strokeWidth = _width
      ..strokeCap = StrokeCap.butt;
    const dash = 7.0;
    const gap = 6.0;
    var x = badX!;
    while (x < x1) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + dash, x1), y), dashed);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_WirePainter old) =>
      old.x0 != x0 ||
      old.x1 != x1 ||
      old.y != y ||
      old.badX != badX ||
      old.wire != wire ||
      old.badWire != badWire;
}

/// The travelling dot.
class _DotPainter extends CustomPainter {
  _DotPainter({
    required this.clock,
    required this.x0,
    required this.x1,
    required this.y,
    required this.color,
    required this.brokenStop,
    required this.brokenCount,
  }) : super(repaint: clock);

  final ValueListenable<double> clock;
  final double x0;
  final double x1;
  final double y;
  final Color color;
  final WakeStop? brokenStop;
  final int brokenCount;

  static const double _radius = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final dot = wakePathDotAt(
      clock.value,
      brokenStop: brokenStop,
      brokenCount: brokenCount,
    );
    if (dot == null) return;
    canvas.drawCircle(
      Offset(x0 + (x1 - x0) * dot.progress, y),
      _radius,
      Paint()..color = color.withValues(alpha: dot.opacity),
    );
  }

  @override
  bool shouldRepaint(_DotPainter old) =>
      old.x0 != x0 ||
      old.x1 != x1 ||
      old.y != y ||
      old.color != color ||
      old.brokenStop != brokenStop ||
      old.brokenCount != brokenCount;
}

/// The glyph inside a stop: a `$` for the tool, a cloud, a paper plane and a
/// phone, drawn on a 24 point grid in the middle of the node.
class _StopGlyphPainter extends CustomPainter {
  const _StopGlyphPainter({
    required this.stop,
    required this.color,
    required this.scale,
  });

  final WakeStop stop;
  final Color color;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = (stop == WakeStop.tool ? 18.0 : 26.0) * scale / 24;
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(unit)
      ..translate(-12, -12);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (stop) {
      case WakeStop.tool:
        // A dollar sign, the prompt of a shell, drawn rather than typed so
        // it needs no font.
        final dollar = Path()
          ..moveTo(17, 7.5)
          ..cubicTo(15.5, 5.5, 8.5, 5.2, 8.2, 8.8)
          ..cubicTo(8, 12.2, 16, 11.4, 15.8, 15.2)
          ..cubicTo(15.6, 18.8, 8.5, 18.6, 7, 16.2)
          ..moveTo(12, 3.5)
          ..lineTo(12, 20.5);
        canvas.drawPath(dollar, paint..strokeWidth = 2.4);
      case WakeStop.server:
        final cloud = Path()
          ..moveTo(7, 18)
          ..lineTo(17, 18)
          ..arcToPoint(
            const Offset(17.6, 10.05),
            radius: const Radius.circular(4),
            clockwise: false,
          )
          ..arcToPoint(
            const Offset(7, 9.5),
            radius: const Radius.circular(5.5),
            clockwise: false,
          )
          ..arcToPoint(
            const Offset(7, 18),
            radius: const Radius.circular(4.25),
            clockwise: false,
          )
          ..close();
        canvas.drawPath(cloud, paint);
      case WakeStop.push:
        final plane = Path()
          ..moveTo(4, 12)
          ..lineTo(20, 5)
          ..lineTo(14, 20)
          ..lineTo(11, 14)
          ..close();
        canvas.drawPath(plane, paint);
      case WakeStop.phone:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(7, 3, 10, 18),
            const Radius.circular(2.5),
          ),
          paint,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StopGlyphPainter old) =>
      old.stop != stop || old.color != color || old.scale != scale;
}

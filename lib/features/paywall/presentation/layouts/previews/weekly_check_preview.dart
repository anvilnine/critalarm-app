import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/extras_preview_stage.dart';
import 'package:flutter/material.dart';

/// The loop is this many seconds long.
const double weeklyCheckPreviewLoop = 9;

/// The second a still preview rests on: the whole week, with its tick.
const double weeklyCheckPreviewRestAt = 7;

/// Days in the strip.
const int weeklyCheckPreviewDays = 7;

/// The day the check falls on, counted from 0. There is one check a week,
/// so one day gets a tick and the others only pass.
const int weeklyCheckPreviewCheckDay = 3;

/// The steps of the loop, in order.
enum WeeklyCheckPreviewPhase {
  /// Last week's strip fades out.
  clearing,

  /// The days before the check pass, one at a time.
  daysBefore,

  /// The push leaves the relay and reaches the phone.
  pushTravels,

  /// The day gets its tick.
  tick,

  /// The rest of the week passes.
  daysAfter,

  /// The full strip holds.
  hold,
}

/// When each step starts, in seconds into the loop.
const weeklyCheckPreviewPhases = <(WeeklyCheckPreviewPhase, double)>[
  (WeeklyCheckPreviewPhase.clearing, 0),
  (WeeklyCheckPreviewPhase.daysBefore, 0.5),
  (WeeklyCheckPreviewPhase.pushTravels, 1.9),
  (WeeklyCheckPreviewPhase.tick, 3.1),
  (WeeklyCheckPreviewPhase.daysAfter, 4),
  (WeeklyCheckPreviewPhase.hold, 5.1),
];

/// The second [phase] starts.
double weeklyCheckPreviewStart(WeeklyCheckPreviewPhase phase) =>
    weeklyCheckPreviewPhases.firstWhere((entry) => entry.$1 == phase).$2;

/// One frame of the weekly check preview.
@immutable
class WeeklyCheckPreviewFrame {
  const WeeklyCheckPreviewFrame({
    required this.phase,
    required this.days,
    required this.push,
    required this.pushOpacity,
    required this.tickFill,
    required this.tickDraw,
    required this.opacity,
  });

  final WeeklyCheckPreviewPhase phase;

  /// How far each day has passed, 0 to 1. The check day's number is how
  /// far it is marked as today, which comes before its tick.
  final List<double> days;

  /// How far the push has travelled from the relay to the phone, 0 to 1.
  final double push;

  /// 0 whenever no push is on its way.
  final double pushOpacity;

  /// How far the check day's mark has filled, 0 to 1.
  final double tickFill;

  /// How much of the tick is drawn, 0 to 1.
  final double tickDraw;

  /// How solid the week's marks are. It drops to 0 once, as last week's
  /// strip fades out, and is 1 for everything after.
  final double opacity;
}

/// A slow start and a slow stop, so the push is seen all the way across.
double _glide(double p) => p * p * (3 - 2 * p);

/// The frame of the weekly check preview at clock second [t].
WeeklyCheckPreviewFrame weeklyCheckPreviewFrameAt(double t) {
  final local = loopT(t, weeklyCheckPreviewLoop);

  var current = weeklyCheckPreviewPhases.first.$1;
  for (final (step, start) in weeklyCheckPreviewPhases) {
    if (local >= start) current = step;
  }

  if (current == WeeklyCheckPreviewPhase.clearing) {
    // The frame the loop ended on, on its way out.
    return WeeklyCheckPreviewFrame(
      phase: current,
      days: List.filled(weeklyCheckPreviewDays, 1),
      push: 1,
      pushOpacity: 0,
      tickFill: 1,
      tickDraw: 1,
      opacity: 1 - phase(local, 0, 0.35),
    );
  }

  final before = weeklyCheckPreviewStart(WeeklyCheckPreviewPhase.daysBefore);
  final leaves = weeklyCheckPreviewStart(WeeklyCheckPreviewPhase.pushTravels);
  final lands = weeklyCheckPreviewStart(WeeklyCheckPreviewPhase.tick);
  final after = weeklyCheckPreviewStart(WeeklyCheckPreviewPhase.daysAfter);

  double pass(double start) =>
      AppCurves.easeOut.transform(phase(local, start, start + 0.3));

  final tick = tickProgress(phase(local, lands, lands + 0.6));
  return WeeklyCheckPreviewFrame(
    phase: current,
    days: [
      for (var day = 0; day < weeklyCheckPreviewDays; day++)
        if (day < weeklyCheckPreviewCheckDay)
          pass(before + day * 0.4)
        else if (day == weeklyCheckPreviewCheckDay)
          // Marked as today just before the push leaves.
          pass(leaves - 0.2)
        else
          pass(after + (day - weeklyCheckPreviewCheckDay - 1) * 0.4),
    ],
    push: _glide(phase(local, leaves, lands)),
    pushOpacity:
        phase(local, leaves, leaves + 0.15) *
        (1 - phase(local, lands - 0.15, lands + 0.05)),
    tickFill: tick.fill,
    tickDraw: tick.draw,
    opacity: 1,
  );
}

/// A week of seven days. A push travels to the phone on one of them, that
/// day gets its tick, and the rest of the week passes.
///
/// The check shows nothing on the phone, so the drawn phone stays blank and
/// nothing here rings, pulses or shakes.
///
/// Small, it is the tick over the strip. From [extrasPreviewFullEdge] up it
/// is the relay, the push on its way to the phone, and the strip.
class WeeklyCheckPreview extends StatelessWidget {
  const WeeklyCheckPreview({required this.size, super.key});

  final Size size;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ExtrasPreviewTile(
      size: size,
      color: colors.cream,
      child: PaywallPreviewClock.seconds(
        restAt: weeklyCheckPreviewRestAt,
        builder: (context, t) => CustomPaint(
          size: size,
          painter: _WeeklyCheckPainter(
            frame: weeklyCheckPreviewFrameAt(t),
            ink: colors.ink,
            accent: colors.highlight,
            onAccent: colors.onHighlight,
            dot: colors.cobalt,
          ),
        ),
      ),
    );
  }
}

class _WeeklyCheckPainter extends CustomPainter {
  const _WeeklyCheckPainter({
    required this.frame,
    required this.ink,
    required this.accent,
    required this.onAccent,
    required this.dot,
  });

  final WeeklyCheckPreviewFrame frame;
  final Color ink;

  /// The tick's disc, and the colour drawn on it.
  final Color accent;
  final Color onAccent;

  /// The push on its way.
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide;
    if (u < extrasPreviewFullEdge) {
      _paintGlance(canvas, size, u);
    } else {
      _paintFull(canvas, size, u);
    }
  }

  /// The tick over the strip.
  void _paintGlance(Canvas canvas, Size size, double u) {
    final centre = size.center(Offset.zero);
    final cell = u * 0.085;
    final strip = Offset(centre.dx, centre.dy + u * 0.29);
    _paintStrip(canvas, strip, cell, cell * 0.45, showsTick: false);

    final disc = Offset(centre.dx, centre.dy - u * 0.1);
    final radius = u * 0.21;
    canvas.drawCircle(
      disc,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, u * 0.03)
        ..color = ink.withValues(alpha: 0.22),
    );
    _paintTick(canvas, disc, radius);

    final from = Offset(centre.dx - u * 0.6, disc.dy);
    _paintPush(canvas, Offset.lerp(from, disc, frame.push)!, u * 0.05);
  }

  /// The relay, the push on its way to the phone, and the strip.
  void _paintFull(Canvas canvas, Size size, double u) {
    final pad = u * 0.12;
    final width = math.min(size.width - pad * 2, u * 1.7);
    final left = (size.width - width) / 2;

    // Seven cells and six gaps of 0.3 of a cell fill the width.
    final cell = math.min(u * 0.12, width / (7 + 6 * 0.3));
    final stripY = size.height - pad - cell * 0.75;
    _paintStrip(
      canvas,
      Offset(size.width / 2, stripY),
      cell,
      (width - cell * 7) / 6,
      showsTick: true,
    );

    // The relay and the phone share the room above the strip.
    final top = pad;
    final bottom = stripY - cell * 1.35;
    final midY = (top + bottom) / 2;
    final stroke = math.max(1.5, u * 0.022);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..color = ink;

    final phoneH = math.min(bottom - top, u * 0.5);
    final phoneW = phoneH * 0.56;
    final phone = Rect.fromCenter(
      center: Offset(left + width - phoneW / 2 - stroke, midY),
      width: phoneW,
      height: phoneH,
    );
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(phone, Radius.circular(phoneW * 0.24)),
        line,
      )
      // The bar at the foot of the screen. The screen itself stays blank.
      ..drawLine(
        Offset(phone.center.dx - phoneW * 0.16, phone.bottom - phoneH * 0.1),
        Offset(phone.center.dx + phoneW * 0.16, phone.bottom - phoneH * 0.1),
        line..strokeCap = StrokeCap.round,
      );

    // The relay: two stacked units, each with its light.
    final unitW = u * 0.2;
    final unitH = u * 0.085;
    final unitGap = u * 0.03;
    final relayLeft = left + stroke;
    for (final dy in [-(unitH + unitGap) / 2, (unitH + unitGap) / 2]) {
      final unit = Rect.fromCenter(
        center: Offset(relayLeft + unitW / 2, midY + dy),
        width: unitW,
        height: unitH,
      );
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(unit, Radius.circular(unitH * 0.34)),
          line,
        )
        ..drawCircle(
          Offset(unit.left + unitH * 0.5, unit.center.dy),
          stroke * 0.8,
          Paint()..color = ink,
        );
    }

    // The way between them, as a row of dots.
    final from = Offset(relayLeft + unitW + u * 0.06, midY);
    final to = Offset(phone.left - u * 0.06, midY);
    final dots = math.max(2, ((to.dx - from.dx) / (u * 0.07)).floor());
    for (var i = 0; i <= dots; i++) {
      canvas.drawCircle(
        Offset.lerp(from, to, i / dots)!,
        stroke * 0.55,
        Paint()..color = ink.withValues(alpha: 0.28),
      );
    }

    // The push ends inside the phone, where it fades.
    _paintPush(
      canvas,
      Offset.lerp(Offset(from.dx - u * 0.04, midY), phone.center, frame.push)!,
      u * 0.04,
    );
  }

  void _paintPush(Canvas canvas, Offset at, double radius) {
    if (frame.pushOpacity <= 0) return;
    canvas.drawCircle(
      at,
      radius,
      Paint()..color = dot.withValues(alpha: frame.pushOpacity),
    );
  }

  /// The seven days, centred on [centre]. A day that has passed is filled.
  void _paintStrip(
    Canvas canvas,
    Offset centre,
    double cell,
    double gap, {
    required bool showsTick,
  }) {
    const days = weeklyCheckPreviewDays;
    final width = cell * days + gap * (days - 1);
    final corner = Radius.circular(cell * 0.32);
    for (var day = 0; day < days; day++) {
      final at = Offset(
        centre.dx - width / 2 + cell / 2 + day * (cell + gap),
        centre.dy,
      );
      final isCheckDay = day == weeklyCheckPreviewCheckDay;
      final passed = frame.days[day] * frame.opacity;
      // The check day is a round mark, a size up from the days around it.
      final edge = isCheckDay ? cell * 1.3 : cell;
      final box = RRect.fromRectAndRadius(
        Rect.fromCenter(center: at, width: edge, height: edge),
        isCheckDay ? Radius.circular(edge / 2) : corner,
      );

      // The empty day is always there, so the week reads as seven.
      canvas.drawRRect(box, Paint()..color = ink.withValues(alpha: 0.1));
      if (!isCheckDay) {
        canvas.drawRRect(
          box,
          Paint()..color = ink.withValues(alpha: 0.26 * passed),
        );
        continue;
      }
      // Today: the mark gets an edge while the push is on its way.
      canvas.drawRRect(
        box.deflate(cell * 0.05),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, cell * 0.1)
          ..color = ink.withValues(alpha: 0.45 * passed),
      );
      if (showsTick) {
        _paintTick(canvas, at, edge / 2);
      } else {
        // Too small for a tick: the day takes the tick's colour.
        canvas.drawRRect(
          box,
          Paint()
            ..color = accent.withValues(alpha: frame.tickFill * frame.opacity),
        );
      }
    }
  }

  /// The disc that fills, then the tick drawn on it.
  void _paintTick(Canvas canvas, Offset centre, double radius) {
    if (frame.tickFill <= 0) return;
    canvas.drawCircle(
      centre,
      radius * frame.tickFill,
      Paint()..color = accent.withValues(alpha: frame.opacity),
    );
    if (frame.tickDraw <= 0) return;

    // The design system's tick, on a 24 unit square.
    final unit = radius * 2 * 0.62 / 24;
    final origin = centre - Offset(12 * unit, 12 * unit);
    final whole = Path()
      ..moveTo(origin.dx + 4 * unit, origin.dy + 12 * unit)
      ..lineTo(origin.dx + 10 * unit, origin.dy + 18 * unit)
      ..lineTo(origin.dx + 20 * unit, origin.dy + 6 * unit);
    final metric = whole.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * frame.tickDraw),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, radius * 0.24)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = onAccent.withValues(alpha: frame.opacity),
    );
  }

  @override
  bool shouldRepaint(_WeeklyCheckPainter old) =>
      frame != old.frame ||
      ink != old.ink ||
      accent != old.accent ||
      onAccent != old.onAccent ||
      dot != old.dot;
}

import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/extras_preview_stage.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/preview_glyph_tile.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/preview_size_class.dart';
import 'package:flutter/material.dart';

// Weekly delivery check: four weeks, one square each. The newest is this
// week: a push travels from the relay to the phone and that week gets its
// tick. Small, it is a calendar page with a tick on the shared tile.
//
// A week is the unit because the check runs once a week. Seven squares
// read as the days of one week, which is not what happens.

/// The loop is this many seconds long.
const double weeklyCheckPreviewLoop = 9;

/// The second a still preview rests on: the four weeks, the newest ticked.
const double weeklyCheckPreviewRestAt = 7;

/// Weeks in the strip, oldest first. The last one is this week, the one
/// the loop checks.
const int weeklyCheckPreviewWeeks = 4;

/// The steps of the loop, in order.
enum WeeklyCheckPreviewPhase {
  /// The strip fades out, to play again.
  clearing,

  /// The earlier weeks pass, one at a time.
  weeksBefore,

  /// The push leaves the relay and reaches the phone.
  pushTravels,

  /// This week gets its tick.
  tick,

  /// The full strip holds.
  hold,
}

/// When each step starts, in seconds into the loop.
const weeklyCheckPreviewPhases = <(WeeklyCheckPreviewPhase, double)>[
  (WeeklyCheckPreviewPhase.clearing, 0),
  (WeeklyCheckPreviewPhase.weeksBefore, 0.5),
  (WeeklyCheckPreviewPhase.pushTravels, 1.9),
  (WeeklyCheckPreviewPhase.tick, 3.1),
  (WeeklyCheckPreviewPhase.hold, 4),
];

/// The second [phase] starts.
double weeklyCheckPreviewStart(WeeklyCheckPreviewPhase phase) =>
    weeklyCheckPreviewPhases.firstWhere((entry) => entry.$1 == phase).$2;

/// One frame of the weekly check preview.
@immutable
class WeeklyCheckPreviewFrame {
  const WeeklyCheckPreviewFrame({
    required this.phase,
    required this.weeks,
    required this.push,
    required this.pushOpacity,
    required this.tickFill,
    required this.tickDraw,
    required this.opacity,
  });

  final WeeklyCheckPreviewPhase phase;

  /// How far each week has passed, 0 to 1, oldest first. The last number
  /// is how far this week is marked as the current one, which comes before
  /// its tick.
  final List<double> weeks;

  /// How far the push has travelled from the relay to the phone, 0 to 1.
  final double push;

  /// 0 whenever no push is on its way.
  final double pushOpacity;

  /// How far this week's mark has filled, 0 to 1.
  final double tickFill;

  /// How much of the tick is drawn, 0 to 1.
  final double tickDraw;

  /// How solid the marks are. It drops to 0 once, as the strip fades out,
  /// and is 1 for everything after.
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
      weeks: List.filled(weeklyCheckPreviewWeeks, 1),
      push: 1,
      pushOpacity: 0,
      tickFill: 1,
      tickDraw: 1,
      opacity: 1 - phase(local, 0, 0.35),
    );
  }

  final before = weeklyCheckPreviewStart(WeeklyCheckPreviewPhase.weeksBefore);
  final leaves = weeklyCheckPreviewStart(WeeklyCheckPreviewPhase.pushTravels);
  final lands = weeklyCheckPreviewStart(WeeklyCheckPreviewPhase.tick);

  double pass(double start) =>
      AppCurves.easeOut.transform(phase(local, start, start + 0.3));

  final tick = tickProgress(phase(local, lands, lands + 0.6));
  return WeeklyCheckPreviewFrame(
    phase: current,
    weeks: [
      for (var week = 0; week < weeklyCheckPreviewWeeks - 1; week++)
        pass(before + week * 0.4),
      // Marked as this week just before the push leaves.
      pass(leaves - 0.2),
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

/// Four weeks. A push travels to the phone in the newest one and that
/// week gets its tick.
///
/// The check shows nothing on the phone, so the drawn phone stays blank and
/// nothing here rings, pulses or shakes. The tick is ink on the strip, not
/// on the phone: it marks a week, and says nothing about an alarm.
///
/// Small, it is a calendar mark on the shared tile. As a scene it is the
/// relay, the push on its way to the phone, and the strip.
class WeeklyCheckPreview extends StatelessWidget {
  const WeeklyCheckPreview({required this.size, super.key});

  final Size size;

  @override
  Widget build(BuildContext context) {
    if (size.shortestSide < paywallPreviewSceneMinEdge) {
      return PreviewGlyphTile.mark(PreviewMark.weeklyCheck, size: size);
    }
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
            onInk: colors.cream,
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
    required this.onInk,
  });

  final WeeklyCheckPreviewFrame frame;

  /// Every line, the push and the tick's disc.
  final Color ink;

  /// The tick drawn on its disc.
  final Color onInk;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide;
    final pad = u * 0.12;
    final width = math.min(size.width - pad * 2, u * 1.7);
    final left = (size.width - width) / 2;

    // Four squares in the middle, the same size at every width.
    final cell = u * 0.13;
    final stripY = size.height - pad - cell * 0.75;
    _paintStrip(canvas, Offset(size.width / 2, stripY), cell, cell * 0.42);
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
    if (frame.pushOpacity <= 0) return;
    canvas.drawCircle(
      Offset.lerp(Offset(from.dx - u * 0.04, midY), phone.center, frame.push)!,
      u * 0.04,
      Paint()..color = ink.withValues(alpha: frame.pushOpacity),
    );
  }

  /// The four weeks, centred on [centre]. A week that has passed is
  /// filled, and the newest is a round mark that takes the tick.
  void _paintStrip(Canvas canvas, Offset centre, double cell, double gap) {
    const weeks = weeklyCheckPreviewWeeks;
    final width = cell * weeks + gap * (weeks - 1);
    final corner = Radius.circular(cell * 0.32);
    for (var week = 0; week < weeks; week++) {
      final at = Offset(
        centre.dx - width / 2 + cell / 2 + week * (cell + gap),
        centre.dy,
      );
      final isThisWeek = week == weeks - 1;
      final passed = frame.weeks[week] * frame.opacity;
      // This week is a round mark, a size up from the weeks before it.
      final edge = isThisWeek ? cell * 1.3 : cell;
      final box = RRect.fromRectAndRadius(
        Rect.fromCenter(center: at, width: edge, height: edge),
        isThisWeek ? Radius.circular(edge / 2) : corner,
      );

      // The empty week is always there, so the strip reads as four.
      canvas.drawRRect(box, Paint()..color = ink.withValues(alpha: 0.1));
      if (!isThisWeek) {
        canvas.drawRRect(
          box,
          Paint()..color = ink.withValues(alpha: 0.26 * passed),
        );
        continue;
      }
      // The mark gets an edge while the push is on its way.
      canvas.drawRRect(
        box.deflate(cell * 0.05),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, cell * 0.1)
          ..color = ink.withValues(alpha: 0.45 * passed),
      );
      _paintTick(canvas, at, edge / 2);
    }
  }

  /// The disc that fills, then the tick drawn on it.
  void _paintTick(Canvas canvas, Offset centre, double radius) {
    if (frame.tickFill <= 0) return;
    canvas.drawCircle(
      centre,
      radius * frame.tickFill,
      Paint()..color = ink.withValues(alpha: frame.opacity),
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
        ..color = onInk.withValues(alpha: frame.opacity),
    );
  }

  @override
  bool shouldRepaint(_WeeklyCheckPainter old) =>
      frame != old.frame || ink != old.ink || onInk != old.onInk;
}

import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/extras_preview_stage.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/preview_glyph_tile.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/preview_size_class.dart';
import 'package:flutter/material.dart';

// Weekly delivery check: a test push leaves the relay, crosses to the
// phone and lands. The phone lights and takes a tick, and so does this
// week in the row of four under it. Small, it is a calendar page with a
// tick on the shared tile.
//
// A week is the unit because the check runs once a week. Seven marks
// read as the days of one week, which is not what happens.

/// The loop is this many seconds long.
const double weeklyCheckPreviewLoop = 9;

/// The second a still preview rests on: the push landed, the phone and
/// all four weeks ticked.
const double weeklyCheckPreviewRestAt = 7;

/// Weeks in the strip, oldest first. The last one is this week, the one
/// the loop checks.
const int weeklyCheckPreviewWeeks = 4;

/// The steps of the loop, in order.
enum WeeklyCheckPreviewPhase {
  /// The strip fades out, to play again.
  clearing,

  /// The earlier weeks get their ticks, one at a time.
  weeksBefore,

  /// The push leaves the relay and reaches the phone.
  pushTravels,

  /// The phone lights with its tick, then this week gets one.
  tick,

  /// The finished picture holds.
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

/// How long after the phone lights this week's tick starts.
const double weeklyCheckPreviewWeekAfter = 0.25;

/// One frame of the weekly check preview.
@immutable
class WeeklyCheckPreviewFrame {
  const WeeklyCheckPreviewFrame({
    required this.phase,
    required this.weeks,
    required this.push,
    required this.pushOpacity,
    required this.lit,
    required this.tickFill,
    required this.tickDraw,
    required this.opacity,
  });

  final WeeklyCheckPreviewPhase phase;

  /// How far each earlier week's tick is on, 0 to 1, oldest first. The
  /// last number is how far this week is marked as the current one, which
  /// comes before its tick.
  final List<double> weeks;

  /// How far the push has travelled from the relay to the phone, 0 to 1.
  final double push;

  /// 0 whenever no push is on its way.
  final double pushOpacity;

  /// How far the phone has lit after the push landed, 0 to 1.
  final double lit;

  /// How far this week's mark has filled, 0 to 1. It follows the phone.
  final double tickFill;

  /// How much of the tick is drawn, 0 to 1.
  final double tickDraw;

  /// How solid the marks are. It drops to 0 once, as the picture clears,
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
      lit: 1,
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

  // The phone answers first, and the week is marked a beat after it.
  final tick = tickProgress(
    phase(local, lands + weeklyCheckPreviewWeekAfter, lands + 0.85),
  );
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
    lit: phase(local, lands, lands + 0.3),
    tickFill: tick.fill,
    tickDraw: tick.draw,
    opacity: 1,
  );
}

/// A test push crosses from the relay to the phone, the phone lights with
/// a tick, and this week is ticked in the row of four.
///
/// The real check shows nothing on the phone and makes no sound, so the
/// drawn one only lights and takes a tick: nothing rings, pulses or
/// shakes, and nothing is red. The tick says a push reached this phone
/// this week. It says nothing about an alarm.
///
/// Small, it is a calendar mark on the shared tile. As a scene it is the
/// relay, the push on its way, the phone, and the four weeks.
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
            paper: colors.surface,
            warm: colors.yellow,
            onWarm: colors.inkFixed,
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
    required this.paper,
    required this.warm,
    required this.onWarm,
  });

  final WeeklyCheckPreviewFrame frame;

  /// Every line and every tick's disc.
  final Color ink;

  /// A tick drawn on its disc.
  final Color onInk;

  /// The panel of weeks, the relay and the phone's screen before it lights.
  final Color paper;

  /// The push, the lit screen and the edge of this week's mark.
  final Color warm;

  /// Lines on [warm], which is the same in both themes.
  final Color onWarm;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide;
    final pad = u * 0.09;
    final width = math.min(size.width - pad * 2, u * 1.5);
    final left = (size.width - width) / 2;
    final stroke = math.max(1.5, u * 0.024);
    final marks = frame.opacity;

    // The four weeks, on a panel along the foot of the card.
    final panel = Rect.fromLTWH(
      left,
      size.height - pad - u * 0.25,
      width,
      u * 0.25,
    );
    _paintWeeks(canvas, panel, u);

    // The relay and the phone share the room above it.
    final top = pad;
    final bottom = panel.top - u * 0.06;
    final midY = (top + bottom) / 2;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = ink;

    final phoneH = math.min(bottom - top, u * 0.52);
    final phoneW = phoneH * 0.58;
    final phoneAt = Offset(left + width - phoneW / 2 - u * 0.05, midY);

    // The relay: two stacked units, each with its light.
    final unitW = u * 0.25;
    final unitH = u * 0.11;
    final unitGap = u * 0.035;
    final relayLeft = left + stroke / 2;
    for (final dy in [-(unitH + unitGap) / 2, (unitH + unitGap) / 2]) {
      final unit = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(relayLeft + unitW / 2, midY + dy),
          width: unitW,
          height: unitH,
        ),
        Radius.circular(unitH * 0.34),
      );
      canvas
        ..drawRRect(unit, Paint()..color = paper)
        ..drawRRect(unit, line)
        ..drawCircle(
          Offset(unit.left + unitH * 0.5, unit.center.dy),
          stroke * 0.85,
          Paint()..color = ink,
        )
        ..drawLine(
          Offset(unit.right - unitW * 0.38, unit.center.dy),
          Offset(unit.right - unitH * 0.45, unit.center.dy),
          line,
        );
    }

    // The way between them, as a row of dots. The ones the push has
    // passed stay dark, so a finished check leaves the whole way drawn.
    final from = Offset(relayLeft + unitW + u * 0.055, midY);
    final to = Offset(phoneAt.dx - phoneW / 2 - u * 0.055, midY);
    final dots = math.max(2, ((to.dx - from.dx) / (u * 0.07)).floor());
    final reach = frame.push * 1.25 * marks;
    for (var i = 0; i <= dots; i++) {
      final passed = phase(reach, i / dots, i / dots + 0.08);
      canvas.drawCircle(
        Offset.lerp(from, to, i / dots)!,
        stroke * (0.55 + 0.2 * passed),
        Paint()..color = ink.withValues(alpha: 0.26 + 0.64 * passed),
      );
    }

    // The phone gives a little as the push lands, and stays upright.
    final lit = frame.lit * marks;
    final give = 1 + 0.05 * math.sin(math.pi * frame.lit);
    final phone = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: phoneAt,
        width: phoneW * give,
        height: phoneH * give,
      ),
      Radius.circular(phoneW * 0.24),
    );
    canvas
      ..drawRRect(
        phone,
        Paint()
          ..color = Color.lerp(
            paper,
            warm,
            AppCurves.easeOut.transform(lit),
          )!,
      )
      ..drawRRect(phone, line)
      // The bar at the foot of the screen.
      ..drawLine(
        Offset(phoneAt.dx - phoneW * 0.15, phone.bottom - phoneH * 0.09),
        Offset(phoneAt.dx + phoneW * 0.15, phone.bottom - phoneH * 0.09),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(ink, onWarm, lit)!,
      );
    if (lit > 0) {
      _paintTick(
        canvas,
        phoneAt.translate(0, -phoneH * 0.04),
        phoneW * 0.3 * AppCurves.easeBack.transform(frame.lit),
        disc: onWarm.withValues(alpha: marks),
        tick: warm.withValues(alpha: marks),
        draw: 1,
      );
    }

    // The push ends inside the phone, where it fades.
    if (frame.pushOpacity <= 0) return;
    final at = Offset.lerp(
      Offset(from.dx - u * 0.04, midY),
      phoneAt,
      frame.push,
    )!;
    canvas
      ..drawCircle(
        at,
        u * 0.05,
        Paint()..color = warm.withValues(alpha: frame.pushOpacity),
      )
      ..drawCircle(
        at,
        u * 0.05,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = ink.withValues(alpha: frame.pushOpacity),
      );
  }

  /// The four weeks, spread across [panel]. A week that went through has
  /// its tick. This week has a warm edge, and takes its tick last.
  void _paintWeeks(Canvas canvas, Rect panel, double u) {
    const weeks = weeklyCheckPreviewWeeks;
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, Radius.circular(panel.height * 0.36)),
      Paint()..color = paper,
    );
    final radius = panel.height * 0.29;
    final step = panel.width / weeks;
    for (var week = 0; week < weeks; week++) {
      final at = Offset(panel.left + step * (week + 0.5), panel.center.dy);
      final isThisWeek = week == weeks - 1;
      final amount = frame.weeks[week] * frame.opacity;

      // The empty week is always there, so the row reads as four.
      canvas.drawCircle(
        at,
        radius,
        Paint()..color = ink.withValues(alpha: 0.1),
      );
      if (!isThisWeek) {
        _paintTick(
          canvas,
          at,
          radius * amount,
          disc: ink.withValues(alpha: frame.opacity),
          tick: onInk.withValues(alpha: frame.opacity),
          draw: phase(frame.weeks[week], 0.4, 1),
        );
        continue;
      }
      // This week gets its edge just before the push leaves.
      canvas.drawCircle(
        at,
        radius + u * 0.014,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, u * 0.026)
          ..color = warm.withValues(alpha: amount),
      );
      _paintTick(
        canvas,
        at,
        radius * frame.tickFill,
        disc: ink.withValues(alpha: frame.opacity),
        tick: onInk.withValues(alpha: frame.opacity),
        draw: frame.tickDraw,
      );
    }
  }

  /// A filled disc of [radius] with [draw] of the tick's stroke on it.
  void _paintTick(
    Canvas canvas,
    Offset centre,
    double radius, {
    required Color disc,
    required Color tick,
    required double draw,
  }) {
    if (radius <= 0) return;
    canvas.drawCircle(centre, radius, Paint()..color = disc);
    if (draw <= 0) return;

    // The design system's tick, on a 24 unit square.
    final unit = radius * 2 * 0.62 / 24;
    final origin = centre - Offset(12 * unit, 12 * unit);
    final whole = Path()
      ..moveTo(origin.dx + 4 * unit, origin.dy + 12 * unit)
      ..lineTo(origin.dx + 10 * unit, origin.dy + 18 * unit)
      ..lineTo(origin.dx + 20 * unit, origin.dy + 6 * unit);
    final metric = whole.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * draw),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, radius * 0.24)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = tick,
    );
  }

  @override
  bool shouldRepaint(_WeeklyCheckPainter old) =>
      frame != old.frame ||
      ink != old.ink ||
      onInk != old.onInk ||
      paper != old.paper ||
      warm != old.warm ||
      onWarm != old.onWarm;
}

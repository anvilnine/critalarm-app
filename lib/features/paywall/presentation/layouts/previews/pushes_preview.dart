import 'dart:math' as math;

import 'package:critalarm/core/models/device_registration.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/limits_preview_clock.dart';
import 'package:flutter/material.dart';

// Pushes a day: a counter and a bar drawn to scale. The count fills the
// free allowance and stops, then runs on to the Hosted one. It rests full.

/// Where the counter is in its loop, in the order it happens.
enum PushesPreviewPhase {
  /// At the Hosted allowance. The resting picture.
  full,

  /// Emptying, to play again.
  draining,

  /// Counting up through the free allowance.
  filling,

  /// Stopped at the free allowance.
  stalled,

  /// Counting on to the Hosted allowance.
  running,

  /// The final number settles.
  landing,
}

/// The seconds of the loop at which each phase starts.
abstract final class PushesPreviewTimes {
  static const double drain = 3.2;
  static const double fill = 3.45;
  static const double stall = 4;
  static const double run = 4.45;
  static const double land = 5.9;
  static const double full = 6.15;
}

/// Everything the counter picture needs at one moment.
@immutable
class PushesPreviewFrame {
  const PushesPreviewFrame({
    required this.phase,
    required this.count,
    required this.fill,
    required this.stop,
    required this.pop,
  });

  final PushesPreviewPhase phase;

  /// The number shown.
  final int count;

  /// How much of the bar is filled, 0 to 1. The whole bar is the Hosted
  /// allowance, so the free one is a small part of it.
  final double fill;

  /// How strongly the free mark shows the count stopped at it, 0 to 1.
  final double stop;

  /// Scale of the number. 1 at rest.
  final double pop;

  @override
  bool operator ==(Object other) =>
      other is PushesPreviewFrame &&
      other.phase == phase &&
      other.count == count &&
      other.fill == fill &&
      other.stop == stop &&
      other.pop == pop;

  @override
  int get hashCode => Object.hash(phase, count, fill, stop, pop);
}

/// The phase at clock second [t].
PushesPreviewPhase pushesPreviewPhaseAt(double t) {
  final u = loopT(t, limitsPreviewPeriod);
  if (u < PushesPreviewTimes.drain) return PushesPreviewPhase.full;
  if (u < PushesPreviewTimes.fill) return PushesPreviewPhase.draining;
  if (u < PushesPreviewTimes.stall) return PushesPreviewPhase.filling;
  if (u < PushesPreviewTimes.run) return PushesPreviewPhase.stalled;
  if (u < PushesPreviewTimes.land) return PushesPreviewPhase.running;
  if (u < PushesPreviewTimes.full) return PushesPreviewPhase.landing;
  return PushesPreviewPhase.full;
}

/// The counter at clock second [t], for a free allowance of [free] and a
/// Hosted one of [hosted]. The loop starts and ends full.
PushesPreviewFrame pushesPreviewFrameAt(
  double t, {
  required int free,
  required int hosted,
}) {
  final u = loopT(t, limitsPreviewPeriod);
  final at = pushesPreviewPhaseAt(t);

  final value = switch (at) {
    PushesPreviewPhase.full || PushesPreviewPhase.landing => hosted.toDouble(),
    PushesPreviewPhase.draining =>
      hosted *
          (1 -
              AppCurves.easeOut.transform(
                phase(u, PushesPreviewTimes.drain, PushesPreviewTimes.fill),
              )),
    PushesPreviewPhase.filling =>
      free *
          AppCurves.easeOut.transform(
            phase(u, PushesPreviewTimes.fill, PushesPreviewTimes.stall),
          ),
    PushesPreviewPhase.stalled => free.toDouble(),
    PushesPreviewPhase.running =>
      free +
          (hosted - free) *
              Curves.easeInOutCubic.transform(
                phase(u, PushesPreviewTimes.run, PushesPreviewTimes.land),
              ),
  };

  return PushesPreviewFrame(
    phase: at,
    count: value.round(),
    fill: hosted <= 0 ? 1 : (value / hosted).clamp(0.0, 1.0),
    stop: limitsKeyframes(u, const [
      (PushesPreviewTimes.stall - 0.1, 0.0),
      (PushesPreviewTimes.stall, 1.0),
      (PushesPreviewTimes.run, 1.0),
      (PushesPreviewTimes.run + 0.35, 0.0),
    ]),
    pop: at == PushesPreviewPhase.landing
        ? 0.92 +
              0.08 *
                  AppCurves.easeSpring.transform(
                    phase(u, PushesPreviewTimes.land, PushesPreviewTimes.full),
                  )
        : 1,
  );
}

/// [n] with a comma every three digits, as the rest of the Hosted copy
/// writes its numbers.
String pushesPreviewNumber(int n) {
  final digits = '$n';
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// How the picture is laid out in a box: the bar alone when the box is
/// small, the number over the bar when there is room, and the two
/// allowances written under the bar when there is more.
@immutable
class PushesPreviewLayout {
  const PushesPreviewLayout({
    required this.padding,
    required this.barHeight,
    required this.numberSize,
    required this.scaleSize,
    required this.gap,
  });

  final double padding;
  final double barHeight;

  /// Type size of the count. Zero leaves the bar alone.
  final double numberSize;

  /// Type size of the two allowances under the bar. Zero leaves them out.
  final double scaleSize;
  final double gap;

  bool get isBarAlone => numberSize == 0;
  bool get showsScale => scaleSize > 0;
}

/// [numberAspect] is how wide the largest number is, as a multiple of its
/// type size.
PushesPreviewLayout pushesPreviewLayoutFor(
  Size size, {
  required double numberAspect,
}) {
  if (size.shortestSide < limitsPreviewSmallEdge) {
    return PushesPreviewLayout(
      padding: size.width * 0.12,
      barHeight: math.min(size.height, size.width) * 0.22,
      numberSize: 0,
      scaleSize: 0,
      gap: 0,
    );
  }

  final padding = size.shortestSide * 0.1;
  final w = size.width - 2 * padding;
  final h = size.height - 2 * padding;
  final barHeight = math.min(h * 0.15, w * 0.09);
  final wanted = math.min<double>(math.min(h * 0.11, w * 0.07), 13);
  final scaleSize = wanted >= limitsPreviewMinType ? wanted : 0.0;
  final gap = barHeight * 0.6;
  // The line of type, the space over it, and a point to spare.
  final scaleRoom = scaleSize == 0 ? 0 : scaleSize * 1.3 + gap * 0.6 + 1;
  final numberRoom = h - barHeight - gap - scaleRoom;

  return PushesPreviewLayout(
    padding: padding,
    barHeight: barHeight,
    numberSize: math.min(numberRoom, w / numberAspect),
    scaleSize: scaleSize,
    gap: gap,
  );
}

/// The pushes a day preview.
class PushesPreview extends StatelessWidget {
  const PushesPreview({required this.size, super.key});

  final Size size;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final free = AccountCaps.free.p4Daily ?? 0;
    const hosted = hostedP4Daily;
    final numberStyle = AppTypography.display(colors.yellow).copyWith(
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // Measured once for the box, at the widest the number gets.
    final probe = TextPainter(
      text: TextSpan(
        text: pushesPreviewNumber(hosted),
        style: numberStyle.copyWith(fontSize: 100, letterSpacing: -4),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final layout = pushesPreviewLayoutFor(
      size,
      numberAspect: probe.width / 100,
    );
    probe.dispose();

    return LimitsPreviewTile(
      size: size,
      color: colors.panel,
      child: Padding(
        padding: EdgeInsets.all(layout.padding),
        child: PaywallPreviewClock<PushesPreviewFrame>(
          restAt: limitsPreviewRestAt,
          // Told when to play, it starts on its own turn of the shared loop.
          turnStart: PushesPreviewTimes.drain,
          frameAt: (t) => pushesPreviewFrameAt(t, free: free, hosted: hosted),
          builder: (context, frame) {
            final bar = CustomPaint(
              size: Size(double.infinity, layout.barHeight),
              painter: _BarPainter(
                fill: frame.fill,
                mark: hosted <= 0 ? 0 : free / hosted,
                stop: frame.stop,
                trackColor: colors.onPanel.withValues(alpha: 0.14),
                fillColor: colors.yellow,
                markColor: Color.lerp(colors.crit, colors.critAlt, frame.stop)!,
              ),
            );
            if (layout.isBarAlone) return Center(child: bar);

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: layout.numberSize,
                  child: Transform.scale(
                    scale: frame.pop,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      pushesPreviewNumber(frame.count),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: numberStyle.copyWith(
                        fontSize: layout.numberSize,
                        letterSpacing: -0.04 * layout.numberSize,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: layout.gap),
                bar,
                if (layout.showsScale) ...[
                  SizedBox(height: layout.gap * 0.6),
                  _Scale(
                    layout: layout,
                    free: free,
                    hosted: hosted,
                    frame: frame,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The two allowances under the bar, each under its own end of the scale.
class _Scale extends StatelessWidget {
  const _Scale({
    required this.layout,
    required this.free,
    required this.hosted,
    required this.frame,
  });

  final PushesPreviewLayout layout;
  final int free;
  final int hosted;
  final PushesPreviewFrame frame;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final style = AppTypography.monoBold(
      colors.onPanelMuted,
      fontSize: layout.scaleSize,
    ).copyWith(height: 1.3);

    return LayoutBuilder(
      builder: (context, box) {
        final markX = hosted <= 0 ? 0.0 : box.maxWidth * free / hosted;
        return Row(
          children: [
            SizedBox(width: markX),
            // The mark on the bar carries on down beside the free number.
            Container(
              padding: EdgeInsets.only(left: layout.scaleSize * 0.4),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: colors.crit,
                    width: _markWidth(box.maxWidth),
                  ),
                ),
              ),
              child: Text(
                pushesPreviewNumber(free),
                style: style.copyWith(
                  color: Color.lerp(
                    colors.onPanelMuted,
                    colors.critAlt,
                    frame.stop,
                  ),
                ),
              ),
            ),
            const Spacer(),
            Opacity(
              // Faint until the count gets there.
              opacity: 0.45 + 0.55 * phase(frame.fill, 0.85, 1),
              child: Text(
                pushesPreviewNumber(hosted),
                style: style.copyWith(color: colors.yellow),
              ),
            ),
          ],
        );
      },
    );
  }
}

double _markWidth(double barWidth) => math.max(1.5, barWidth * 0.008);

class _BarPainter extends CustomPainter {
  const _BarPainter({
    required this.fill,
    required this.mark,
    required this.stop,
    required this.trackColor,
    required this.fillColor,
    required this.markColor,
  });

  final double fill;

  /// Where the free allowance ends, as a part of the bar.
  final double mark;
  final double stop;
  final Color trackColor;
  final Color fillColor;
  final Color markColor;

  @override
  void paint(Canvas canvas, Size size) {
    final track = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height * 0.36),
    );
    final markWidth = _markWidth(size.width);
    final markX = size.width * mark;
    // While the count is stopped the mark stands a little taller.
    final lift = size.height * 0.22 * stop;

    canvas
      ..save()
      ..clipRRect(track)
      ..drawRect(Offset.zero & size, Paint()..color = trackColor)
      ..drawRect(
        Rect.fromLTWH(0, 0, size.width * fill, size.height),
        Paint()..color = fillColor,
      )
      ..restore()
      ..drawRect(
        Rect.fromLTRB(markX, -lift, markX + markWidth, size.height + lift),
        Paint()..color = markColor,
      );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.fill != fill ||
      old.mark != mark ||
      old.stop != stop ||
      old.trackColor != trackColor ||
      old.fillColor != fillColor ||
      old.markColor != markColor;
}

import 'dart:math' as math;

import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_block.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/features/paywall/presentation/thanks/stamp/stamp_timeline.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Stamp: a slip shoots out of the button, the mascot catches it, the
/// benefits print on it, a rubber stamp with the product's name lands on
/// it and the mascot holds it up.
const PaywallThanks stampThanks = PaywallThanks(
  seconds: StampTimeline.end,
  cover: StampTimeline.cover,
  buttonAt: StampTimeline.goOn,
  beats: stampBeats,
  builder: _build,
);

/// What is felt on the way, and the one thing heard. While the purchase
/// cue sounds every beat is a haptic alone. The stamp lands after it, so
/// it gets its own cue: one thud.
List<PaywallThanksBeat> stampBeats(int lines) => [
  // The mascot has the slip, on the swell's peak.
  const PaywallThanksBeat.tap(StampTimeline.caught, HapticPattern.medium),
  // Each line prints.
  for (var i = 0; i < lines; i++)
    PaywallThanksBeat.tap(StampTimeline.lineAt(i, lines), HapticPattern.tick),
  // The stamp lands.
  const PaywallThanksBeat(StampTimeline.stampAt, PaywallCue.stamp),
  // The mascot is down again, slip in hand.
  const PaywallThanksBeat.tap(StampTimeline.raised, HapticPattern.light),
];

Widget _build(BuildContext context, PaywallThanksScope scope) =>
    StampThanks(scope: scope);

/// Draws the stamp version for the second its scope's clock reads.
class StampThanks extends StatelessWidget {
  const StampThanks({required this.scope, super.key});

  final PaywallThanksScope scope;

  static const PaywallTone _tone = PaywallTone.canvas;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tone = PaywallToneColors.of(context, _tone);
    final lines = thanksLines(scope);
    final plan = StampPlan.of(
      size: scope.size,
      padding: scope.padding,
      lines: lines.length,
      textScale: MediaQuery.textScalerOf(context).scale(1),
    );
    // The shared parts read a stage: the mascot's box and the headline's.
    final stage = ThanksStage(
      crit: plan.crit,
      words: plan.headline,
      headlineSize: plan.headlineSize,
      lineSize: 0,
      rowGap: 0,
    );
    final origin = scope.origin;
    // The slip comes out of the middle of the button, from behind it.
    final slot = scope.source.dy;
    final mitt = plan.crit.width * 0.085;

    return PaywallClockBuilder(
      clock: scope.clock,
      builder: (context, t, _) {
        final rest = t - StampTimeline.end;
        final box = Rect.lerp(
          thanksStartBox(scope.mascot) ?? plan.crit,
          plan.crit,
          StampTimeline.travel(t),
        )!;
        final fed = StampTimeline.fed(t);
        final lift = StampTimeline.lift(t, lines: lines.length);
        final button = StampTimeline.button(t);
        // The slip goes up with the mascot and gives under the stamp.
        final paper = plan
            .paperAt(fed, slot)
            .translate(
              0,
              -lift * plan.crit.width + 5 * StampTimeline.pressed(t),
            );
        // Until the mascot has it, nothing of it shows below the slot.
        final isOut = fed >= 1 || slot <= plan.paper.bottom;

        return Stack(
          children: [
            ThanksCover(
              color: tone.background,
              centre: scope.source,
              grown: StampTimeline.covered(t),
            ),
            ThanksDisc(stage: stage, tone: _tone, grown: StampTimeline.disc(t)),
            ThanksCrit(
              box: box,
              face: StampTimeline.face(t),
              lift: lift,
              stretch: StampTimeline.stretch(t),
              blink: rest > 0 ? heroBlinkAt(rest) : 0,
              // The slip hangs where its shadow would fall.
              shadow: StampTimeline.travel(t) * (1 - fed),
            ),
            if (fed > 0)
              Positioned.fill(
                child: ClipRect(
                  clipper: isOut ? null : _AboveClipper(slot),
                  child: Stack(
                    children: [
                      Positioned.fromRect(
                        rect: paper,
                        child: Opacity(
                          opacity: slot <= plan.paper.bottom ? fed : 1,
                          child: _Slip(
                            plan: plan,
                            title: LocaleKeys.app_title.tr(),
                            lines: lines,
                            stampText: paywallProductName(scope.product),
                            printed: (i) =>
                                StampTimeline.printed(t, i, lines.length),
                            stamp: StampTimeline.stamp(t),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // The mascot's two hands on the slip's top edge.
            if (fed >= 1)
              for (final side in const [-1.0, 1.0])
                Positioned.fromRect(
                  rect: Rect.fromCircle(
                    center: Offset(
                      paper.center.dx + side * plan.crit.width * 0.3,
                      paper.top + mitt * 0.2,
                    ),
                    radius: mitt,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.faceFill,
                      border: Border.all(
                        color: colors.faceStroke,
                        width: plan.crit.width * 0.034,
                      ),
                    ),
                  ),
                ),
            // The pressed button, which the slip comes out of.
            if (origin != null && button > 0)
              Positioned.fromRect(
                rect: origin,
                child: Transform.scale(
                  scale: button,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.cobalt,
                      borderRadius: BorderRadius.circular(origin.height / 2),
                    ),
                  ),
                ),
              ),
            ThanksWords(
              stage: stage,
              tone: _tone,
              headline: thanksHeadline(scope.product),
              lines: const [],
              headlineIn: StampTimeline.headlineIn(t),
              mark: (_) => const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

/// Keeps what is above a line [y] points down the box.
class _AboveClipper extends CustomClipper<Rect> {
  const _AboveClipper(this.y);

  final double y;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width, math.max(0, y));

  @override
  bool shouldReclip(_AboveClipper old) => y != old.y;
}

/// The slip: the app's name, one ticked line a benefit in the mono face,
/// and the stamp. Paper is light in both themes, as a till slip is, so in
/// the dark theme it takes the canvas's light ink and its type the fixed
/// dark one.
class _Slip extends StatelessWidget {
  const _Slip({
    required this.plan,
    required this.title,
    required this.lines,
    required this.stampText,
    required this.printed,
    required this.stamp,
  });

  final StampPlan plan;
  final String title;
  final List<String> lines;
  final String stampText;

  /// 0 to 1 for each line: how far it is printed.
  final double Function(int index) printed;
  final StampMark stamp;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = isDark ? colors.onCanvas : colors.cream;
    final ink = isDark ? colors.inkFixed : colors.ink;
    final quiet = ink.withValues(alpha: 0.7);
    final faint = ink.withValues(alpha: 0.45);
    final u = plan.unit;
    final pad = StampPlan.pad * u;

    // A picture of a slip: its type does not follow the text size, and
    // the lines under the headline are what a reader is told.
    return MediaQuery.withNoTextScaling(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _PaperPainter(
                color: paper,
                tooth: 5 * u,
                shadows: AppShadows.shadowLg(isDark: isDark),
              ),
            ),
          ),
          Positioned(
            left: pad,
            right: pad,
            top: StampPlan.lead * u,
            height: StampPlan.header * u,
            child: Center(
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                style: AppTypography.monoBold(
                  quiet,
                  fontSize: 11 * u,
                ).copyWith(letterSpacing: 2.4, height: 1.2),
              ),
            ),
          ),
          _rule(plan.rowsTop - StampPlan.rule * u, faint, pad),
          for (final (i, line) in lines.indexed)
            Positioned(
              left: pad,
              right: pad,
              top: plan.rowsTop + plan.rowHeight * i,
              height: plan.rowHeight,
              child: Opacity(
                opacity: printed(i).clamp(0, 1).toDouble(),
                child: Row(
                  children: [
                    AppGlyph(
                      GlyphType.check,
                      size: 15 * u,
                      color: ink,
                    ),
                    SizedBox(width: 10 * u),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          line,
                          maxLines: 1,
                          style: AppTypography.monoBold(
                            ink,
                            fontSize: 16 * u,
                          ).copyWith(height: 1.2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _rule(plan.stampTop - StampPlan.rule * u, faint, pad),
          if (stamp.opacity > 0)
            Positioned(
              left: pad,
              right: pad,
              top: plan.stampTop,
              height: StampPlan.stampRoom * u - 8 * u,
              child: Center(
                child: Opacity(
                  opacity: stamp.opacity.clamp(0, 1).toDouble(),
                  child: Transform.rotate(
                    angle: stamp.angle,
                    child: Transform.scale(
                      scale: stamp.scale,
                      child: _StampMark(
                        text: stampText,
                        color: colors.crit,
                        unit: u,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _rule(double top, Color color, double pad) => Positioned(
    left: pad,
    right: pad,
    top: top,
    height: StampPlan.rule * plan.unit,
    child: CustomPaint(painter: _DashPainter(color)),
  );
}

/// The rubber stamp: the product's name in a double frame.
class _StampMark extends StatelessWidget {
  const _StampMark({
    required this.text,
    required this.color,
    required this.unit,
  });

  final String text;
  final Color color;
  final double unit;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(2.5 * unit),
    decoration: BoxDecoration(
      border: Border.all(color: color, width: 3 * unit),
      borderRadius: BorderRadius.circular(Radii.xs + 4),
    ),
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * unit, vertical: 5 * unit),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.2 * unit),
        borderRadius: BorderRadius.circular(Radii.xs + 1),
      ),
      child: Text(
        text.toUpperCase(),
        maxLines: 1,
        style: AppTypography.monoBold(
          color,
          fontSize: 27 * unit,
        ).copyWith(letterSpacing: 4, height: 1.2),
      ),
    ),
  );
}

/// The paper, with a torn edge along its foot, on its shadow.
class _PaperPainter extends CustomPainter {
  const _PaperPainter({
    required this.color,
    required this.tooth,
    required this.shadows,
  });

  final Color color;
  final double tooth;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final teeth = (size.width / 9).round();
    final step = size.width / teeth;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - tooth);
    for (var i = teeth - 1; i >= 0; i--) {
      path
        ..lineTo(step * (i + 0.5), size.height)
        ..lineTo(step * i, size.height - tooth);
    }
    path.close();
    for (final shadow in shadows) {
      canvas.drawPath(path.shift(shadow.offset), shadow.toPaint());
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PaperPainter old) =>
      color != old.color || tooth != old.tooth || shadows != old.shadows;
}

/// A dashed rule across the middle of the box.
class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + 4, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => color != old.color;
}

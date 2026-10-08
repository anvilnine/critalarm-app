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
                  clipper: isOut ? null : ThanksAboveClipper(slot),
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
              ...thanksHands(context, paper: paper, edge: plan.crit.width),
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
              painter: ThanksPaperPainter(
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
                      child: ThanksStampMark(
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
    child: CustomPaint(painter: ThanksDashPainter(color)),
  );
}

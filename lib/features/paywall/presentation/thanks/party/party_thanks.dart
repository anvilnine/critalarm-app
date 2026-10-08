import 'dart:math' as math;

import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_buy_block.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/features/paywall/presentation/thanks/party/party_timeline.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Receipt party: a slip prints from the button with the limits that were
/// just lifted as its lines, the product's stamp lands on it, confetti
/// bursts from the stamp and each line changes to what the buyer has now.
const PaywallThanks partyThanks = PaywallThanks(
  seconds: PartyTimeline.end,
  cover: PartyTimeline.cover,
  buttonAt: PartyTimeline.goOn,
  beats: partyBeats,
  builder: _build,
);

/// What is felt on the way, and the one thing heard. While the purchase
/// cue sounds every beat is a haptic alone: the stamp is a thud under the
/// hand on the swell's peak, and each line a tick. The confetti comes to
/// lie after the cue is over, so that is heard.
List<PaywallThanksBeat> partyBeats(int lines) => [
  // The mascot has the slip.
  const PaywallThanksBeat.tap(PartyTimeline.caught, HapticPattern.light),
  // The stamp lands and the confetti bursts.
  const PaywallThanksBeat.tap(PartyTimeline.stampAt, HapticPattern.heavy),
  // Each line changes.
  for (var i = 0; i < lines; i++)
    PaywallThanksBeat.tap(PartyTimeline.lineAt(i, lines), HapticPattern.tick),
  // The mascot lands, slip in hand, as the last piece lies still.
  const PaywallThanksBeat(PartyTimeline.settled, PaywallCue.settle),
];

Widget _build(BuildContext context, PaywallThanksScope scope) =>
    PartyThanks(scope: scope);

/// Draws the receipt party for the second its scope's clock reads.
class PartyThanks extends StatelessWidget {
  const PartyThanks({required this.scope, super.key});

  final PaywallThanksScope scope;

  static const PaywallTone _tone = PaywallTone.canvas;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tone = PaywallToneColors.of(context, _tone);
    final rows = limitsRowsFor(scope.benefits);
    final count = scope.benefits.length;
    final plan = ThanksSlipPlan.of(
      size: scope.size,
      padding: scope.padding,
      lines: count,
      textScale: MediaQuery.textScalerOf(context).scale(1),
      foot: PartyTimeline.foot,
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
    // No cobalt among the confetti: that is the button's.
    final inks = [colors.onCanvas, colors.surface, colors.crit, colors.cream];

    return PaywallClockBuilder(
      clock: scope.clock,
      builder: (context, t, _) {
        final rest = t - PartyTimeline.end;
        final box = Rect.lerp(
          thanksStartBox(scope.mascot) ?? plan.crit,
          plan.crit,
          PartyTimeline.travel(t),
        )!;
        final fed = PartyTimeline.fed(t);
        final lift = PartyTimeline.lift(t, lines: count);
        final button = PartyTimeline.button(t);
        // The slip goes up with the mascot and gives under the stamp.
        final paper = plan
            .paperAt(fed, slot)
            .translate(
              0,
              -lift * plan.crit.width + 5 * PartyTimeline.pressed(t),
            );
        // Until the mascot has it, nothing of it shows below the slot.
        final isOut = fed >= 1 || slot <= plan.paper.bottom;

        return Stack(
          children: [
            ThanksCover(
              color: tone.background,
              centre: scope.source,
              grown: PartyTimeline.covered(t),
            ),
            ThanksDisc(stage: stage, tone: _tone, grown: PartyTimeline.disc(t)),
            ThanksCrit(
              box: box,
              face: PartyTimeline.face(t),
              lift: lift,
              stretch: PartyTimeline.stretch(t),
              blink: rest > 0 ? heroBlinkAt(rest) : 0,
              // The slip hangs where its shadow would fall.
              shadow: PartyTimeline.travel(t) * (1 - fed),
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
                            rows: rows,
                            benefits: scope.benefits,
                            stampText: paywallProductName(scope.product),
                            lifted: (i) => PartyTimeline.lifted(t, i, count),
                            struck: (i) => PartyTimeline.struck(t, i, count),
                            valueIn: (i) => PartyTimeline.valueIn(t, i, count),
                            count: (i) => PartyTimeline.count(
                              t,
                              i,
                              count,
                              from: rows?[i].freeCount ?? 0,
                              to: rows?[i].nowCount ?? 0,
                            ),
                            stamp: PartyTimeline.stamp(t),
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
            // The confetti, thrown from the stamp where it landed, over
            // everything and down to the floor under the headline.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: ThanksConfettiPainter(
                    t: PartyTimeline.burst(t),
                    origin: plan.stampCentre,
                    floor: plan.floor + PartyTimeline.floorDrop,
                    inks: inks,
                  ),
                ),
              ),
            ),
            ThanksWords(
              stage: stage,
              tone: _tone,
              headline: thanksHeadline(scope.product),
              lines: const [],
              headlineIn: PartyTimeline.headlineIn(t),
              mark: (_) => const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

/// The slip: the app's name, one line a limit in the mono face, and the
/// stamp. A line starts as the free plan's limit. It is struck through
/// and the product's value comes in beside it. Where a product has no
/// counters a line is a feature, and its padlock becomes a check.
///
/// Paper is light in both themes, as a till slip is, so in the dark theme
/// it takes the canvas's light ink and its type the fixed dark one.
class _Slip extends StatelessWidget {
  const _Slip({
    required this.plan,
    required this.title,
    required this.rows,
    required this.benefits,
    required this.stampText,
    required this.lifted,
    required this.struck,
    required this.valueIn,
    required this.count,
    required this.stamp,
  });

  final ThanksSlipPlan plan;
  final String title;

  /// The limits, or null for a product whose lines are features.
  final List<LimitsRow>? rows;
  final List<PaywallBenefit> benefits;
  final String stampText;

  /// 0 to 1 for each line: how far it has changed, how far the line
  /// through its old limit is drawn, and how far in its new value is.
  final double Function(int index) lifted;
  final double Function(int index) struck;
  final double Function(int index) valueIn;

  /// The number each line's value reads on the way.
  final int Function(int index) count;
  final PartyStamp stamp;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = isDark ? colors.onCanvas : colors.cream;
    final ink = isDark ? colors.inkFixed : colors.ink;
    final quiet = ink.withValues(alpha: 0.7);
    final faint = ink.withValues(alpha: 0.45);
    final u = plan.unit;
    final pad = ThanksSlipPlan.pad * u;
    final rows = this.rows;

    // A picture of a slip: its type does not follow the text size, and
    // each line is read out whole.
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
            top: ThanksSlipPlan.lead * u,
            height: ThanksSlipPlan.header * u,
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
          _rule(plan.rowsTop - ThanksSlipPlan.rule * u, faint, pad),
          for (var i = 0; i < benefits.length; i++)
            Positioned(
              left: pad,
              right: pad,
              top: plan.rowsTop + plan.rowHeight * i,
              height: plan.rowHeight,
              child: rows == null
                  ? _FeatureLine(
                      title: benefits[i].title,
                      unit: u,
                      ink: ink,
                      quiet: quiet,
                      lifted: lifted(i),
                    )
                  : _LimitLine(
                      row: rows[i],
                      unit: u,
                      ink: ink,
                      quiet: quiet,
                      faint: faint,
                      lifted: lifted(i),
                      struck: struck(i),
                      valueIn: valueIn(i),
                      count: count(i),
                    ),
            ),
          _rule(plan.stampTop - ThanksSlipPlan.rule * u, faint, pad),
          if (stamp.opacity > 0)
            Positioned(
              left: pad,
              right: pad,
              top: plan.stampTop,
              height: ThanksSlipPlan.stampRoom * u - 8 * u,
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
    height: ThanksSlipPlan.rule * plan.unit,
    child: CustomPaint(painter: ThanksDashPainter(color)),
  );
}

/// One limit on the slip: its name, the free plan's value, and the
/// product's value once the free one is struck through.
class _LimitLine extends StatelessWidget {
  const _LimitLine({
    required this.row,
    required this.unit,
    required this.ink,
    required this.quiet,
    required this.faint,
    required this.lifted,
    required this.struck,
    required this.valueIn,
    required this.count,
  });

  final LimitsRow row;
  final double unit;
  final Color ink;
  final Color quiet;
  final Color faint;
  final double lifted;
  final double struck;
  final double valueIn;
  final int count;

  @override
  Widget build(BuildContext context) {
    final u = unit;
    // The new value lands with a small pop as its number arrives.
    final pop = 1 + 0.12 * thanksArc(phase(lifted, 0.84, 1));
    // The old limit steps back as the new value comes in beside it.
    final oldSize = (15.5 - 3.5 * valueIn) * u;

    return Semantics(
      label: '${row.label}, ${row.now}',
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                row.label,
                maxLines: 1,
                style: AppTypography.mono(
                  quiet,
                  fontSize: 12.5 * u,
                ).copyWith(height: 1.2),
              ),
            ),
          ),
          SizedBox(width: 8 * u),
          CustomPaint(
            foregroundPainter: _StrikePainter(
              color: Color.lerp(ink, quiet, valueIn)!,
              drawn: struck,
              width: 1.6 * u,
            ),
            child: Text(
              row.free,
              maxLines: 1,
              style: AppTypography.monoBold(
                Color.lerp(ink, faint, valueIn)!,
                fontSize: oldSize,
              ).copyWith(height: 1.2),
            ),
          ),
          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: valueIn.clamp(0, 1).toDouble(),
              child: Padding(
                padding: EdgeInsets.only(left: 8 * u),
                child: Transform.scale(
                  scale: pop,
                  alignment: Alignment.centerRight,
                  child: Text(
                    row.valueAt(math.max(lifted, 0.001), count),
                    maxLines: 1,
                    style: AppTypography.monoBold(
                      ink,
                      fontSize: 15.5 * u,
                    ).copyWith(height: 1.2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One feature on the slip: its name, and a padlock that becomes a check.
class _FeatureLine extends StatelessWidget {
  const _FeatureLine({
    required this.title,
    required this.unit,
    required this.ink,
    required this.quiet,
    required this.lifted,
  });

  final String title;
  final double unit;
  final Color ink;
  final Color quiet;
  final double lifted;

  @override
  Widget build(BuildContext context) {
    final u = unit;
    final on = Curves.easeOut.transform(phase(lifted, 0.3, 0.8));
    final pop = AppCurves.easeBack.transform(on);

    return Semantics(
      label: title,
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                style: AppTypography.monoBold(
                  Color.lerp(quiet, ink, on)!,
                  fontSize: 15.5 * u,
                ).copyWith(height: 1.2),
              ),
            ),
          ),
          SizedBox(width: 8 * u),
          SizedBox.square(
            dimension: 18 * u,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (on < 1)
                  Opacity(
                    opacity: 1 - on,
                    child: AppGlyph(
                      GlyphType.lock,
                      size: 16 * u,
                      color: quiet,
                    ),
                  ),
                if (on > 0)
                  Transform.scale(
                    scale: pop,
                    child: AppGlyph(
                      GlyphType.check,
                      size: 17 * u,
                      color: ink,
                      strokeWidth: 3,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A line through the middle of the box, [drawn] of the way across.
class _StrikePainter extends CustomPainter {
  const _StrikePainter({
    required this.color,
    required this.drawn,
    required this.width,
  });

  final Color color;
  final double drawn;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    if (drawn <= 0) return;
    final y = size.height * 0.52;
    canvas.drawLine(
      Offset(-2, y),
      Offset(-2 + (size.width + 4) * drawn.clamp(0, 1), y),
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_StrikePainter old) =>
      drawn != old.drawn || color != old.color || width != old.width;
}

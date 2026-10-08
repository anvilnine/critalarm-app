import 'dart:math' as math;

import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/design_system/haptics.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/features/paywall/presentation/thanks/limits/limits_timeline.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Limits lifted: every limit of the free plan stands at its cap, each
/// stop breaks and its number rolls up to the product's, and the mascot
/// grows a size. A product with no counters turns its locked cards over.
const PaywallThanks limitsThanks = PaywallThanks(
  seconds: LimitsTimeline.end,
  cover: LimitsTimeline.cover,
  buttonAt: LimitsTimeline.goOn,
  beats: limitsBeats,
  builder: _build,
);

/// What is felt on the way, and the one thing heard. While the purchase
/// cue sounds every beat is a haptic alone: one tap a limit. The mascot
/// grows after it, so that gets the cue for a thing now allowed.
List<PaywallThanksBeat> limitsBeats(int lines) => [
  for (var i = 0; i < lines; i++)
    PaywallThanksBeat.tap(
      LimitsTimeline.liftAt(i, lines),
      i == 0 ? HapticPattern.medium : HapticPattern.light,
    ),
  const PaywallThanksBeat(LimitsTimeline.grow, PaywallCue.lift),
  const PaywallThanksBeat.tap(LimitsTimeline.grown, HapticPattern.light),
];

Widget _build(BuildContext context, PaywallThanksScope scope) =>
    LimitsThanks(scope: scope);

/// The rows for [benefits] with each free value written as the limit it
/// is: a count that is full, an allowance a day, a number of days. Null
/// when one of them has no limit to show. Then the version draws cards.
///
/// The numbers are the ones [limitsRowsFor] reads. Only the words around
/// them are this version's.
List<LimitsRow>? limitsCapRowsFor(List<PaywallBenefit> benefits) {
  final rows = limitsRowsFor(benefits);
  if (rows == null) return null;
  String aDay(int count) => LocaleKeys.paywall_thanks_limits_a_day.tr(
    namedArgs: {'count': limitsCountText(count)},
  );
  return [
    for (final (i, row) in rows.indexed)
      switch (limitsHostedFor(benefits[i])?.id) {
        // A count of things: the free plan's are all in use.
        HostedBenefitId.topics when row.freeCount != null => LimitsRow(
          label: row.label,
          free: LocaleKeys.paywall_thanks_limits_topics_cap.tr(
            namedArgs: {'count': limitsCountText(row.freeCount!)},
          ),
          now: row.now,
          freeCount: row.freeCount,
          nowCount: row.nowCount,
        ),
        // An allowance: so many a day, on both plans.
        HostedBenefitId.pushes when row.rolls => LimitsRow(
          label: LocaleKeys.paywall_thanks_limits_pushes_label.tr(),
          free: aDay(row.freeCount!),
          now: aDay(row.nowCount!),
          freeCount: row.freeCount,
          nowCount: row.nowCount,
        ),
        HostedBenefitId.appIcons => LimitsRow(
          label: row.label,
          free: LocaleKeys.paywall_thanks_limits_icons_cap.tr(),
          now: row.now,
        ),
        // A window of days already reads as one.
        _ => row,
      },
  ];
}

/// Draws the limits version for the second its scope's clock reads.
class LimitsThanks extends StatelessWidget {
  const LimitsThanks({required this.scope, super.key});

  final PaywallThanksScope scope;

  static const PaywallTone _tone = PaywallTone.canvas;

  @override
  Widget build(BuildContext context) {
    final tone = PaywallToneColors.of(context, _tone);
    final rows = limitsCapRowsFor(scope.benefits);
    final count = scope.benefits.length;
    final plan = LimitsPlan.of(
      size: scope.size,
      padding: scope.padding,
      count: count,
      isCards: rows == null,
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

    return PaywallClockBuilder(
      clock: scope.clock,
      builder: (context, t, _) {
        final rest = t - LimitsTimeline.end;
        final box = Rect.lerp(
          thanksStartBox(scope.mascot) ?? plan.crit,
          plan.critAt(LimitsTimeline.size(t, count: count)),
          LimitsTimeline.travel(t),
        )!;
        final ring = LimitsTimeline.ring(t);

        return Stack(
          children: [
            ThanksCover(
              color: tone.background,
              centre: scope.source,
              grown: LimitsTimeline.covered(t),
            ),
            ThanksDisc(
              stage: stage,
              tone: _tone,
              grown: LimitsTimeline.disc(t),
            ),
            // One ring leaves the disc as the mascot grows, and is gone.
            if (ring > 0 && ring < 1)
              Positioned.fromRect(
                rect: Rect.fromCircle(
                  center: plan.crit.center,
                  radius: plan.crit.width * (0.76 + 0.4 * ring),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: tone.ink.withValues(alpha: 0.2 * (1 - ring)),
                      width: 3,
                    ),
                  ),
                ),
              ),
            ThanksCrit(
              box: box,
              face: LimitsTimeline.face(t, count: count),
              lift: LimitsTimeline.lift(t, count: count),
              stretch: LimitsTimeline.stretch(t),
              blink: rest > 0 ? heroBlinkAt(rest) : 0,
              bob: math.max(0, rest),
              shadow: LimitsTimeline.travel(t),
            ),
            ThanksWords(
              stage: stage,
              tone: _tone,
              headline: thanksHeadline(scope.product),
              lines: const [],
              headlineIn: LimitsTimeline.headlineIn(t),
              mark: (_) => const SizedBox.shrink(),
            ),
            for (var i = 0; i < count; i++)
              Positioned.fromRect(
                rect: plan.row(i),
                child: _RowIn(
                  entered: LimitsTimeline.rowIn(t, i),
                  // A picture of the plan: its type grows a little with
                  // the text size and no further, as its box does not.
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.15,
                    child: rows == null
                        ? _Card(
                            benefit: scope.benefits[i],
                            plan: plan,
                            tone: tone,
                            turned: LimitsTimeline.turned(t, i, count),
                            angle: LimitsTimeline.turnAngle(t, i, count),
                          )
                        : _Limit(
                            row: rows[i],
                            plan: plan,
                            tone: tone,
                            lifted: LimitsTimeline.lifted(t, i, count),
                            broken: LimitsTimeline.broken(t, i, count),
                            filled: LimitsTimeline.filled(t, i, count),
                            eased: LimitsTimeline.eased(t, i, count),
                            count: LimitsTimeline.count(
                              t,
                              i,
                              count,
                              from: rows[i].freeCount ?? 0,
                              to: rows[i].nowCount ?? 0,
                            ),
                          ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A row rising in.
class _RowIn extends StatelessWidget {
  const _RowIn({required this.entered, required this.child});

  final double entered;
  final Widget child;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: entered.clamp(0, 1).toDouble(),
    child: Transform.translate(
      offset: Offset(
        0,
        (1 - AppCurves.easeOut.transform(entered.clamp(0, 1))) * Spacing.s3,
      ),
      child: child,
    ),
  );
}

/// One limit: its name, its value, and a bar run up against a stop.
class _Limit extends StatelessWidget {
  const _Limit({
    required this.row,
    required this.plan,
    required this.tone,
    required this.lifted,
    required this.broken,
    required this.filled,
    required this.eased,
    required this.count,
  });

  final LimitsRow row;
  final LimitsPlan plan;
  final PaywallToneColors tone;
  final double lifted;
  final double broken;
  final double filled;

  /// 0 to 1: how far the bar has let go, once it has run to its end.
  final double eased;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final u = plan.unit;
    // The value lands with a small pop as its number arrives.
    final landed = phase(lifted, 0.84, 1);
    final pop = 1 + 0.12 * thanksArc(landed);
    final value = row.valueAt(lifted, count);

    return Semantics(
      label: '${row.label}, ${row.now}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      row.label,
                      maxLines: 1,
                      style: AppTypography.small(
                        Color.lerp(tone.muted, tone.ink, lifted)!,
                        fontSize: 16.5 * u,
                      ).copyWith(fontWeight: FontWeight.w600, height: 1.2),
                    ),
                  ),
                ),
                SizedBox(width: Spacing.s3 * u),
                Transform.scale(
                  scale: pop,
                  alignment: Alignment.bottomRight,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: AppTypography.monoBold(
                      Color.lerp(tone.muted, tone.ink, lifted)!,
                      fontSize: 21 * u,
                    ).copyWith(height: 1.1),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8 * u),
          SizedBox(
            height: 12 * u,
            child: CustomPaint(
              painter: _BarPainter(
                filled: filled,
                broken: broken,
                // A bar at its cap is heavy. Lifted, it is a light line:
                // the number beside it is what reads.
                weight: 1 - (1 - LimitsTimeline.restThick) * eased,
                track: tone.ink.withValues(alpha: 0.14 * (1 - eased)),
                fill: tone.ink.withValues(
                  alpha: 1 - (1 - LimitsTimeline.restInk) * eased,
                ),
                stop: colors.crit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A bar filled to [filled] of its length, with the stop the free plan
/// ends at. As the stop breaks its two halves fly apart and fade.
class _BarPainter extends CustomPainter {
  const _BarPainter({
    required this.filled,
    required this.broken,
    required this.weight,
    required this.track,
    required this.fill,
    required this.stop,
  });

  final double filled;
  final double broken;

  /// The bar's height against the box's.
  final double weight;
  final Color track;
  final Color fill;
  final Color stop;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final bar = h * weight;
    final top = (h - bar) / 2;
    final radius = Radius.circular(bar / 2);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, top, size.width, bar),
          radius,
        ),
        Paint()..color = track,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, top, size.width * filled, bar),
          radius,
        ),
        Paint()..color = fill,
      );
    if (broken >= 1) return;
    final x = size.width * LimitsTimeline.capShare;
    final away = Curves.easeOut.transform(broken);
    final paint = Paint()..color = stop.withValues(alpha: 1 - broken);
    final thick = h * 0.7;
    // The stop stands a little over and under the bar. Its two halves go
    // up and down and on with the bar.
    for (final side in const [-1.0, 1.0]) {
      final centre = Offset(
        x + away * h * 1.6,
        h / 2 + side * (h * 0.55 + away * h * 1.5),
      );
      canvas
        ..save()
        ..translate(centre.dx, centre.dy)
        ..rotate(side * away * 0.9)
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: thick, height: h * 1.2),
            Radius.circular(thick / 2),
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      filled != old.filled ||
      broken != old.broken ||
      weight != old.weight ||
      fill != old.fill ||
      track != old.track;
}

/// One feature as a card. Its locked face is a quiet outline with a
/// padlock. It turns over to its open face: a white card, a check, the
/// feature's name and what it does.
class _Card extends StatelessWidget {
  const _Card({
    required this.benefit,
    required this.plan,
    required this.tone,
    required this.turned,
    required this.angle,
  });

  final PaywallBenefit benefit;
  final LimitsPlan plan;
  final PaywallToneColors tone;
  final double turned;
  final double angle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOpen = turned >= 0.5;
    final u = plan.unit;
    final mark = 26 * u;
    final radius = BorderRadius.circular(Radii.md);

    final title = Text(
      benefit.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.title(
        isOpen ? colors.ink : tone.muted,
        fontSize: 17.5 * u,
      ).copyWith(height: 1.2),
    );

    return Semantics(
      label: plan.hasNote ? '${benefit.title}. ${benefit.line}' : benefit.title,
      excludeSemantics: true,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0014)
          ..rotateX(angle),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isOpen ? colors.surface : tone.ink.withValues(alpha: 0.07),
            borderRadius: radius,
            border: isOpen
                ? null
                : Border.all(
                    color: tone.ink.withValues(alpha: 0.16),
                    width: 1.5,
                  ),
            boxShadow: isOpen ? AppShadows.shadowSm(isDark: isDark) : null,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Spacing.s4 * u),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: mark,
                  child: isOpen
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.highlight,
                          ),
                          child: Center(
                            child: AppGlyph(
                              GlyphType.check,
                              size: mark * 0.56,
                              color: colors.onHighlight,
                              strokeWidth: 3.4,
                            ),
                          ),
                        )
                      : Center(
                          child: AppGlyph(
                            GlyphType.lock,
                            size: mark * 0.8,
                            color: tone.muted,
                          ),
                        ),
                ),
                SizedBox(width: Spacing.s3 * u),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      if (isOpen && plan.hasNote) ...[
                        SizedBox(height: 3 * u),
                        Text(
                          benefit.line,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.small(
                            colors.ink2,
                            fontSize: 14 * u,
                          ).copyWith(height: 1.25),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:critalarm/core/format/number_format.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/domain/leaving_numbers.dart';
import 'package:critalarm/features/paywall/domain/paywall_leaving.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_cue_score.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_measure.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/features/paywall/presentation/layouts/receipt/leaving/leaving_receipt_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/receipt/receipt_paper.dart';
import 'package:critalarm/features/paywall/presentation/layouts/receipt/receipt_rules.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// What the slip prints for [row].
String leavingRowLabel(LeavingRow row) => switch (row) {
  LeavingRow.rang => LocaleKeys.paywall_leaving_receipt_row_rang,
  LeavingRow.answered => LocaleKeys.paywall_leaving_receipt_row_answered,
  LeavingRow.nights => LocaleKeys.paywall_leaving_receipt_row_nights,
  LeavingRow.criticalTopics => LocaleKeys.paywall_leaving_receipt_row_critical,
}.tr();

/// The line under the headline: the span of days the slip counts.
String _spanLine(LeavingFacts facts) {
  final days = leavingSpanDays(facts);
  return days == 1
      ? LocaleKeys.paywall_leaving_receipt_subline_one.tr()
      : LocaleKeys.paywall_leaving_receipt_subline.tr(
          namedArgs: {'days': '$days'},
        );
}

/// The three short lines about what Free gives after the end date. None
/// says history is gone: it is hidden past the seventh day.
List<String> _afterLines(LeavingFacts facts) {
  final args = HostedBenefit.args;
  final critical = switch (leavingCriticalLineFor(facts.criticalTopics)) {
    LeavingCriticalLine.many =>
      LocaleKeys.paywall_leaving_receipt_after_critical.tr(
        namedArgs: {...args, 'n': '${facts.criticalTopics}'},
      ),
    LeavingCriticalLine.one =>
      LocaleKeys.paywall_leaving_receipt_after_critical_one.tr(
        namedArgs: args,
      ),
    LeavingCriticalLine.none =>
      LocaleKeys.paywall_leaving_receipt_after_critical_none.tr(
        namedArgs: args,
      ),
  };
  return [
    LocaleKeys.paywall_leaving_receipt_after_history.tr(namedArgs: args),
    critical,
    LocaleKeys.paywall_leaving_receipt_after_pushes.tr(namedArgs: args),
  ];
}

/// The Receipt for a plan that is ending: "Leaving soon?", the person's own
/// numbers printed on a slip a row at a time, a red stamp with the end date
/// last, and under it three short lines about what Free gives after that
/// date.
///
/// Crit stands on the slip's bottom right corner. He is sad while the slip
/// prints and calm once it is done, and he never hops, nods or rocks: after
/// the entrance nothing on the stage moves. When nothing may move (reduce
/// motion, or the sad opening was shown for this end date already) the
/// finished slip is drawn with Crit calm.
///
/// The numbers come from the route and are drawn here and nowhere else.
class LeavingReceiptComposition extends StatelessWidget {
  const LeavingReceiptComposition({
    required this.scope,
    required this.slip,
    required this.leaving,
    required this.facts,
    super.key,
  });

  final PaywallLayoutScope scope;
  final LeavingSlip slip;
  final PaywallLeaving leaving;
  final LeavingFacts facts;

  /// The after block comes in as the stamp lands, so the print has the eye
  /// until then.
  static const double _afterDelay = 1.1;

  @override
  Widget build(BuildContext context) {
    final tones = PaywallToneColors.of(context, PaywallTone.canvas);
    final sizes = HeroSizes.of(isCompact: scope.isCompact);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final rows = slip.rows.length;
    final width = scope.size.width - heroSideInset * 2;
    // The headline keeps clear of the close cross in the right corner.
    final headlineWidth =
        scope.size.width -
        ReceiptPlan.side -
        (PaywallLayoutScope.closeCrossSize +
            PaywallLayoutScope.closeCrossInset +
            Spacing.s2);
    final endsText = DateFormat(
      'd MMM',
      currentFormatLocale(),
    ).format(leaving.endsOn);

    final headline = LocaleKeys.paywall_leaving_receipt_headline.tr();
    final headlineStyle = AppTypography.headline(
      tones.ink,
      fontSize: sizes.headline,
    );
    final subline = _spanLine(facts);
    final sublineStyle = AppTypography.small(
      tones.ink,
      fontSize: sizes.line,
    ).copyWith(height: 1.35);
    final headlineHeight = paywallTextHeight(
      context,
      headline,
      headlineStyle,
      headlineWidth,
    );
    final sublineHeight = paywallTextHeight(
      context,
      subline,
      sublineStyle,
      headlineWidth,
    );

    final afterLabel = LocaleKeys.paywall_leaving_receipt_after_label
        .tr(namedArgs: {'date': endsText})
        .toUpperCase();
    final afterLabelStyle = AppTypography.small(
      tones.ink,
      fontSize: HeroAlso.labelSize,
    ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.9, height: 1.2);
    final afterStyle = AppTypography.small(
      tones.ink,
      fontSize: sizes.line,
    ).copyWith(fontWeight: FontWeight.w500, height: 1.3);
    final afterLines = _afterLines(facts);
    final afterHeight =
        paywallTextHeight(context, afterLabel, afterLabelStyle, width) +
        HeroAlso.labelGap +
        afterLines.fold<double>(
          0,
          (sum, line) =>
              sum + paywallTextHeight(context, line, afterStyle, width),
        ) +
        sizes.rowGap * (afterLines.length - 1);

    const sublineGap = Spacing.s1 + 2;
    // The headline hangs [Spacing.s1] under the top, level with the cross.
    final fit = leavingReceiptFitFor(
      height: scope.size.height,
      top: Spacing.s1 + headlineHeight + sizes.headlineGap,
      sublineBlock: sublineGap + sublineHeight,
      afterHeight: afterHeight,
      stageGap: sizes.stageGap,
      bottomGap: sizes.bottomGap,
      rows: rows,
      textScale: textScale,
    );
    final hasSubline = fit.showsSubline;
    final stage = Size(scope.size.width, fit.stage);
    final layout = leavingReceiptLayoutFor(
      stage,
      rows: rows,
      textScale: textScale,
      showsFace: fit.showsFace,
    );

    final lines = [
      for (final row in slip.rows)
        ReceiptLine(
          text: leavingRowLabel(row.row),
          value: '${row.value}',
          label: leavingRowLabel(row.row),
          onTap: () {},
        ),
    ];
    final active = [for (final row in slip.rows) row.row].indexOf(
      slip.strongest ?? LeavingRow.rang,
    );
    // The frame's safe area has taken the status bar out of the media
    // query, so its height is read from the view: the air runs under it.
    final view = View.of(context);
    final bleedTop = view.viewPadding.top / view.devicePixelRatio;

    return PaywallCueScore(
      clock: scope.clock,
      // The print is heard a row at a time, then the stamp.
      beats: leavingReceiptCues(rows),
      // The three lines under the slip are pinned at the foot of the box. What
      // is above them scrolls when nothing else is left to give, so the lines
      // are never cut by the buy block.
      child: SizedBox(
        height: scope.size.height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(
                        left: ReceiptPlan.side,
                        right:
                            scope.size.width - ReceiptPlan.side - headlineWidth,
                        top: Spacing.s1,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          HeroRise(
                            clock: scope.clock,
                            index: 0,
                            child: Semantics(
                              header: true,
                              child: Text(headline, style: headlineStyle),
                            ),
                          ),
                          if (hasSubline) ...[
                            const SizedBox(height: sublineGap),
                            HeroRise(
                              clock: scope.clock,
                              index: 1,
                              child: Text(subline, style: sublineStyle),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: sizes.headlineGap),
                    RepaintBoundary(
                      child: PaywallClockBuilder(
                        clock: scope.clock,
                        builder: (context, t, _) => _LeavingStage(
                          layout: layout,
                          t: t,
                          isStill: scope.clock.isStill,
                          atRest: leaving.atRest,
                          bleedTop: bleedTop,
                          title: LocaleKeys.app_title.tr(),
                          lines: lines,
                          active: active,
                          stampText: LocaleKeys.paywall_leaving_receipt_stamp
                              .tr(namedArgs: {'date': endsText.toUpperCase()}),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: fit.scrolls ? sizes.stageGap : fit.room.gap),
            Padding(
              padding: EdgeInsets.only(
                left: ReceiptPlan.side,
                right: heroSideInset,
                bottom: fit.scrolls ? sizes.bottomGap : fit.room.under,
              ),
              child: HeroRise(
                clock: scope.clock,
                index: 2,
                after: _afterDelay,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(afterLabel, style: afterLabelStyle),
                    const SizedBox(height: HeroAlso.labelGap),
                    for (final (i, line) in afterLines.indexed) ...[
                      if (i > 0) SizedBox(height: sizes.rowGap),
                      Text(line, style: afterStyle),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One frame of the stage: the air, the slip hanging from the slot, and
/// Crit on the slip's corner. There is no card, no loop and no hand.
class _LeavingStage extends StatelessWidget {
  const _LeavingStage({
    required this.layout,
    required this.t,
    required this.isStill,
    required this.atRest,
    required this.bleedTop,
    required this.title,
    required this.lines,
    required this.active,
    required this.stampText,
  });

  final LeavingReceiptLayout layout;
  final double t;
  final bool isStill;
  final bool atRest;
  final double bleedTop;
  final String title;
  final List<ReceiptLine> lines;
  final int active;
  final String stampText;

  @override
  Widget build(BuildContext context) {
    final inks = ReceiptInks.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final air = HeroAtmosphereColors.of(context, PaywallTone.canvas);
    final plan = layout.plan;
    final stage = plan.stage;
    // Nothing may move: the finished slip, with Crit calm.
    final actor = isStill
        ? LeavingReceiptTimeline.actor(0, atRest: true)
        : LeavingReceiptTimeline.actor(t, atRest: atRest);
    final parts = plan.stops.length;
    final focus = layout.showsFace
        ? layout.mascot.center
        : layout.plan.paper.bottomRight;

    return SizedBox.fromSize(
      size: stage,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The air behind Crit. It holds still: nothing loops here.
          Positioned(
            left: 0,
            right: 0,
            top: -bleedTop,
            bottom: 0,
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: HeroAtmospherePainter(
                  focus: focus.translate(0, bleedTop),
                  radius: math.max(
                    0,
                    math.min(
                      layout.mascot.longestSide * 0.8,
                      stage.height - focus.dy,
                    ),
                  ),
                  seconds: 0,
                  entrance: isStill ? 1 : heroEntranceAt(t),
                  showsShapes: true,
                  disc: air.disc,
                  soft: air.soft,
                  strong: air.strong,
                  light: air.light,
                ),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: plan.paper,
            child: Transform.rotate(
              angle: isStill ? 0 : ReceiptTimeline.sway(t),
              alignment: Alignment.topCenter,
              child: ReceiptPaper(
                plan: plan,
                title: title,
                lines: lines,
                name: '',
                price: null,
                stampText: stampText,
                active: active,
                linesStyle: ReceiptLinesStyle.figures,
                showsTotal: false,
                out: isStill ? null : ReceiptTimeline.feed(t, plan.stops),
                inks: isStill
                    ? null
                    : [
                        for (var i = 0; i < parts; i++)
                          ReceiptTimeline.ink(t, i, parts),
                      ],
                marker: isStill ? 1 : _marker(t, active, parts),
                stamp: isStill
                    ? const ReceiptStamp(
                        opacity: 1,
                        scale: 1,
                        angle: ReceiptTimeline.stampAngle,
                      )
                    : ReceiptTimeline.stamp(t),
              ),
            ),
          ),
          // The slot, over the top of the paper.
          Positioned.fromRect(
            rect: plan.slot,
            child: ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: inks.slot,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  boxShadow: AppShadows.shadowSm(isDark: isDark),
                ),
                child: Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.9,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: inks.slit,
                        borderRadius: BorderRadius.circular(Radii.xs),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Crit in the print-phase form only: the form with the loop's idle
          // would bob and rock.
          if (layout.showsFace)
            Positioned.fromRect(
              rect: layout.mascot,
              child: ExcludeSemantics(
                child: HeroMascot(
                  size: layout.mascot.width,
                  entranceStyle: receiptMotion.entrance,
                  face: actor.face,
                  fromFace: actor.fromFace,
                  faceBlend: actor.faceBlend,
                  hop: actor.hop,
                  entrance: actor.entrance,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The yellow band prints with its row: it is as solid as that row's ink.
  static double _marker(double t, int active, int parts) =>
      active < 0 ? 0 : ReceiptTimeline.ink(t, active + 1, parts);
}

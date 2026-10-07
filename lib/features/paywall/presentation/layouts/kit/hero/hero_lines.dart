import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_entrance.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_player.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_measure.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The side inset of the words, the same as the buy block's.
const double heroSideInset = 20;

/// The short line the list shows for [benefit]: a sentence of its own for
/// every benefit there is.
String heroLineFor(PaywallBenefit benefit) {
  final key = switch (benefit.id) {
    PaywallBenefitId.topics => LocaleKeys.paywall_hero_lines_topics,
    PaywallBenefitId.pushes => LocaleKeys.paywall_hero_lines_pushes,
    PaywallBenefitId.history => LocaleKeys.paywall_hero_lines_history,
    PaywallBenefitId.widgets => LocaleKeys.paywall_hero_lines_widgets,
    PaywallBenefitId.appIcons => LocaleKeys.paywall_hero_lines_app_icons,
    PaywallBenefitId.wakeUpChallenges =>
      LocaleKeys.paywall_hero_lines_wake_up_challenges,
    PaywallBenefitId.reliabilityChecks =>
      LocaleKeys.paywall_hero_lines_reliability_checks,
    PaywallBenefitId.customSounds =>
      LocaleKeys.paywall_hero_lines_custom_sounds,
    PaywallBenefitId.customAlarmScreens =>
      LocaleKeys.paywall_hero_lines_custom_alarm_screens,
  };
  return key.tr(namedArgs: HostedBenefit.args);
}

/// What the words of the approved composition measure on one phone: the
/// type sizes and the gaps. Use `HeroSizes.of` so a layout's own words
/// match, or write another for a tighter or looser column.
class HeroSizes {
  const HeroSizes({
    required this.headline,
    required this.line,
    required this.check,
    required this.rowGap,
    required this.stageGap,
    required this.headlineGap,
    required this.bottomGap,
  });

  /// The approved sizes: [isCompact] is `scope.isCompact`, a phone 667
  /// points tall or under.
  factory HeroSizes.of({required bool isCompact}) => isCompact
      ? const HeroSizes(
          headline: 26,
          line: 14.5,
          check: 18,
          rowGap: 5,
          stageGap: Spacing.s2,
          headlineGap: 10,
          bottomGap: Spacing.s3,
        )
      : const HeroSizes(
          headline: 30,
          line: 16,
          check: 20,
          rowGap: 9,
          stageGap: Spacing.s3,
          headlineGap: 14,
          bottomGap: 20,
        );

  /// Font sizes of the headline and of a line, and the edge of a check.
  final double headline;
  final double line;
  final double check;

  /// Between two lines.
  final double rowGap;

  /// Between the stage and the headline.
  final double stageGap;

  /// Between the headline and the lines.
  final double headlineGap;

  /// Between the last line and the buy block.
  final double bottomGap;

  /// Between a check and its words.
  static const double checkGap = 10;
}

/// A column of benefit lines, measured before it is drawn: the two styles,
/// each row's fixed height and where its middle is.
///
/// A line keeps its height whether it is the strong one or not, so the
/// list never moves as the stage plays. Measure in `build` and hand the
/// result to [HeroBenefitLines]. `width` is the column's full width, check
/// included.
class HeroLinesMetrics {
  HeroLinesMetrics.measure(
    BuildContext context, {
    required this.lines,
    required double width,
    required this.sizes,
    PaywallTone tone = PaywallTone.canvas,
  }) : textWidth = width - sizes.check - HeroSizes.checkGap,
       strong = AppTypography.small(
         PaywallToneColors.of(context, tone).ink,
         fontSize: sizes.line,
       ).copyWith(fontWeight: FontWeight.w700, height: 1.3),
       quiet =
           AppTypography.small(
             PaywallToneColors.of(context, tone).ink,
             fontSize: sizes.line,
           ).copyWith(
             fontWeight: FontWeight.w500,
             height: 1.3,
             color: PaywallToneColors.of(context, tone).muted,
           ) {
    rowHeights = [
      for (final line in lines)
        math.max(
          sizes.check,
          paywallTextHeight(context, line, strong, textWidth),
        ),
    ];
  }

  final List<String> lines;
  final HeroSizes sizes;

  /// The width the words have, beside the check.
  final double textWidth;

  /// The line of the turn on the stage, and every other line.
  final TextStyle strong;
  final TextStyle quiet;
  late final List<double> rowHeights;

  /// The height of the whole column, gaps included.
  double get height =>
      rowHeights.fold<double>(0, (sum, h) => sum + h) +
      sizes.rowGap * math.max(0, lines.length - 1);

  /// Where the middle of each line is, when the first line's top is [top]
  /// points down the box a tap is read in. Feed it to [heroLineAt].
  List<double> centresFrom(double top) {
    final centres = <double>[];
    var y = top;
    for (final (i, height) in rowHeights.indexed) {
      if (i > 0) y += sizes.rowGap;
      centres.add(y + height / 2);
      y += height;
    }
    return centres;
  }
}

/// The benefits as plain lines, each a small filled check and its words.
/// The line of the turn on the stage is the strong one, and its check pops
/// once as it takes the stage. Rows have fixed heights and rise in during
/// the entrance.
///
/// Every line is a button: a tap puts its turn on the stage, within 22
/// points of its middle, so the tap area is 44 points tall however close
/// the lines sit. Line `i` follows turn `i` of the player's loop.
///
/// Set [handlesTaps] to false where the lines sit inside a larger box that
/// reads the taps itself with [heroLineAt] and [HeroLinesMetrics.centresFrom]
/// (the approved composition does, so the room under the last line still
/// counts). The lines stay buttons for a screen reader either way.
class HeroBenefitLines extends StatelessWidget {
  const HeroBenefitLines({
    required this.player,
    required this.metrics,
    this.labels,
    this.isPickable = true,
    this.handlesTaps = true,
    this.firstRise = 1,
    super.key,
  });

  final HeroPlayer player;
  final HeroLinesMetrics metrics;

  /// What a screen reader adds after each line: the longer sentence the
  /// short line leaves out. Null adds nothing.
  final List<String>? labels;

  /// False for the one line of a product with one benefit: nothing to
  /// pick, so no line is a button.
  final bool isPickable;
  final bool handlesTaps;

  /// The [HeroRise] index of the first line. The headline above is 0.
  final int firstRise;

  @override
  Widget build(BuildContext context) {
    final sizes = metrics.sizes;
    final said = labels;
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, line) in metrics.lines.indexed) ...[
          if (i > 0) SizedBox(height: sizes.rowGap),
          HeroRise(
            clock: player.clock,
            index: i + firstRise,
            after: player.loop.prelude,
            child: SizedBox(
              height: metrics.rowHeights[i],
              child: HeroBenefitLine(
                player: player,
                index: i,
                text: line,
                label: isPickable && said != null ? said[i] : null,
                onTap: isPickable ? () => player.touch(index: i) : null,
                checkSize: sizes.check,
                strong: metrics.strong,
                quiet: metrics.quiet,
              ),
            ),
          ),
        ],
      ],
    );
    if (!handlesTaps || !isPickable) return column;
    final centres = metrics.centresFrom(0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapUp: (details) {
        final line = heroLineAt(details.localPosition.dy, centres);
        if (line != null) player.touch(index: line);
      },
      child: column,
    );
  }
}

/// One benefit as a plain line: a small filled check and the words. It is
/// the strong one while turn [index] has the stage. [HeroBenefitLines]
/// draws a column of them. Use one alone for a single line elsewhere.
class HeroBenefitLine extends StatelessWidget {
  const HeroBenefitLine({
    required this.player,
    required this.index,
    required this.text,
    required this.strong,
    required this.quiet,
    this.label,
    this.onTap,
    this.checkSize = 20,
    super.key,
  });

  final HeroPlayer player;
  final int index;
  final String text;
  final TextStyle strong;
  final TextStyle quiet;
  final String? label;

  /// Null for a line that picks nothing.
  final VoidCallback? onTap;
  final double checkSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return PaywallClockBuilder(
      clock: player.clock,
      builder: (context, t, check) {
        final frame = player.frameAt(t);
        final isActive = frame.activeIndex == index;
        // The check of the line that just took the stage pops once.
        final pop = isActive && frame.previous != null
            ? math.sin(math.pi * phase(frame.sceneSeconds, 0, 0.34))
            : 0.0;
        return Semantics(
          label: label == null ? text : '$text. $label',
          button: onTap != null,
          selected: onTap == null ? null : isActive,
          onTap: onTap,
          excludeSemantics: true,
          child: Row(
            children: [
              Transform.scale(scale: 1 + 0.22 * pop, child: check),
              const SizedBox(width: HeroSizes.checkGap),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: context.motion(AppDurations.base),
                  style: isActive ? strong : quiet,
                  child: Text(text),
                ),
              ),
            ],
          ),
        );
      },
      child: Container(
        width: checkSize,
        height: checkSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.highlight,
        ),
        alignment: Alignment.center,
        child: AppGlyph(
          GlyphType.check,
          size: checkSize * 0.56,
          color: colors.onHighlight,
          strokeWidth: 3.4,
        ),
      ),
    );
  }
}

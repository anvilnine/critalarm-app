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

/// The width the headline is set in: [width] less the extra room kept at its
/// right for the close control. [endRoom] is measured from the screen's edge,
/// and the side inset is already there.
double heroHeadlineWidth({required double width, double endRoom = 0}) =>
    width - math.max(0, endRoom - heroSideInset);

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

/// The sizes of the "Also included" group that sits under a lead.
abstract final class HeroAlso {
  static const double labelSize = 10.5;

  /// Between the lead line and the label. A layout that draws no lead line
  /// has no gap there: the label sits under the headline's own gap.
  static const double beforeGap = 12;

  /// Between the label and the first other benefit.
  static const double labelGap = 6;

  /// The other benefits are smaller than the lead line, with a smaller check.
  static const double itemSize = 13;
  static const double itemCheck = 14;
}

/// Whether a paywall draws the "Also included" group: it has a lead and at
/// least one other benefit.
bool heroShowsAlsoIncluded({
  required bool hasLead,
  required int benefitCount,
}) => hasLead && benefitCount >= 2;

/// Where the middle of each row is. [top] points down the box a tap is
/// read in. [alsoBlock] is the height of the label and its gaps. It sits
/// between the first row and the second and takes the place of [rowGap]
/// there. Zero means no group.
List<double> heroRowCentres({
  required List<double> rowHeights,
  required double rowGap,
  required double top,
  double alsoBlock = 0,
}) {
  final centres = <double>[];
  var y = top;
  for (final (i, height) in rowHeights.indexed) {
    if (i == 1 && alsoBlock > 0) {
      y += alsoBlock;
    } else if (i > 0) {
      y += rowGap;
    }
    centres.add(y + height / 2);
    y += height;
  }
  return centres;
}

/// A column of benefit lines, measured before it is drawn: the two styles,
/// each row's fixed height and where its middle is.
///
/// A line keeps its height whether it is the strong one or not, so the
/// list never moves as the stage plays. Measure in `build` and hand the
/// result to [HeroBenefitLines]. `width` is the column's full width, check
/// included.
class HeroLinesMetrics {
  /// With [alsoIncluded] (the label's words) and at least two lines, the
  /// first line is the lead and the others are the quiet group under the
  /// label. [showsLead] false leaves the lead's line out: the words above
  /// already say it, so the group starts under the headline. Its row is
  /// then zero tall and no tap lands on it.
  HeroLinesMetrics.measure(
    BuildContext context, {
    required this.lines,
    required double width,
    required this.sizes,
    PaywallTone tone = PaywallTone.canvas,
    String? alsoIncluded,
    bool showsLead = true,
  }) : textWidth = width - sizes.check - HeroSizes.checkGap,
       itemTextWidth = width - HeroAlso.itemCheck - HeroSizes.checkGap,
       hasAlso = alsoIncluded != null && lines.length >= 2,
       alsoLabel = alsoIncluded,
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
           ),
       itemStrong = AppTypography.small(
         PaywallToneColors.of(context, tone).ink,
         fontSize: HeroAlso.itemSize,
       ).copyWith(fontWeight: FontWeight.w700, height: 1.3),
       itemQuiet = AppTypography.small(
         _itemInk(PaywallToneColors.of(context, tone), tone),
         fontSize: HeroAlso.itemSize,
       ).copyWith(fontWeight: FontWeight.w500, height: 1.3),
       itemCheckFill = _itemInk(PaywallToneColors.of(context, tone), tone),
       itemCheckMark = PaywallToneColors.of(context, tone).background,
       labelStyle =
           AppTypography.small(
             _itemInk(PaywallToneColors.of(context, tone), tone),
             fontSize: HeroAlso.labelSize,
           ).copyWith(
             fontWeight: FontWeight.w700,
             letterSpacing: 0.9,
             height: 1.2,
           ) {
    leadIsDrawn = !hasAlso || showsLead;
    rowHeights = [
      for (final (i, line) in lines.indexed)
        if (!leadIsDrawn && i == 0)
          0.0
        else if (hasAlso && i > 0)
          math.max(
            HeroAlso.itemCheck,
            paywallTextHeight(context, line, itemStrong, itemTextWidth),
          )
        else
          math.max(
            sizes.check,
            paywallTextHeight(context, line, strong, textWidth),
          ),
    ];
    alsoBlock = !hasAlso
        ? 0
        : (leadIsDrawn ? HeroAlso.beforeGap : 0) +
              paywallTextHeight(
                context,
                alsoIncluded!.toUpperCase(),
                labelStyle,
                width,
              ) +
              HeroAlso.labelGap;
  }

  /// The ink of the quiet group: muted, except on the yellow canvas where
  /// muted text is too faint to read at this size.
  static Color _itemInk(PaywallToneColors colors, PaywallTone tone) =>
      tone == PaywallTone.canvas ? colors.ink : colors.muted;

  final List<String> lines;
  final HeroSizes sizes;

  /// The width the words have, beside the check.
  final double textWidth;

  /// The width the group's words have, beside its smaller check.
  final double itemTextWidth;

  /// The line of the turn on the stage, and every other line.
  final TextStyle strong;
  final TextStyle quiet;

  /// The same two for the group under the label.
  final TextStyle itemStrong;
  final TextStyle itemQuiet;

  /// The small check of the group: this fill and this mark.
  final Color itemCheckFill;
  final Color itemCheckMark;

  /// The label's words, or null when the lines have no group.
  final String? alsoLabel;
  final TextStyle labelStyle;

  /// True when the first line is the lead and the rest sit under a label.
  final bool hasAlso;

  /// False when the lead has no line of its own. Its row is zero tall.
  late final bool leadIsDrawn;

  /// The height of the label and its gaps, zero with no group.
  late final double alsoBlock;
  late final List<double> rowHeights;

  /// The height of the whole column, gaps included.
  double get height {
    if (!hasAlso) {
      return rowHeights.fold<double>(0, (sum, h) => sum + h) +
          sizes.rowGap * math.max(0, lines.length - 1);
    }
    // The lead, the label block, then the others with a gap between.
    return rowHeights.fold<double>(0, (sum, h) => sum + h) +
        alsoBlock +
        sizes.rowGap * math.max(0, lines.length - 2);
  }

  /// Where the middle of each line is, when the first line's top is [top]
  /// points down the box a tap is read in. Feed it to [heroLineAt].
  ///
  /// A lead with no line has a middle that no tap can reach.
  List<double> centresFrom(double top) {
    if (!hasAlso) {
      return heroRowCentres(
        rowHeights: rowHeights,
        rowGap: sizes.rowGap,
        top: top,
      );
    }
    if (leadIsDrawn) {
      return heroRowCentres(
        rowHeights: rowHeights,
        rowGap: sizes.rowGap,
        top: top,
        alsoBlock: alsoBlock,
      );
    }
    return [
      double.negativeInfinity,
      ...heroRowCentres(
        rowHeights: rowHeights.sublist(1),
        rowGap: sizes.rowGap,
        top: top + alsoBlock,
      ),
    ];
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
    final said = labels;
    final hasAlso = metrics.hasAlso;
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, line) in metrics.lines.indexed)
          // A lead with no line of its own draws nothing here.
          if (metrics.leadIsDrawn || i > 0) ...[
            if (hasAlso && i == 1)
              // The label takes the place of the gap above the first of the
              // others. With no lead line it rises in the lead's place.
              HeroRise(
                clock: player.clock,
                index: metrics.leadIsDrawn ? i + firstRise : firstRise,
                after: player.loop.prelude,
                child: SizedBox(
                  height: metrics.alsoBlock,
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: HeroAlso.labelGap),
                      child: Text(
                        metrics.alsoLabel!.toUpperCase(),
                        style: metrics.labelStyle,
                      ),
                    ),
                  ),
                ),
              )
            else if (i > 0)
              SizedBox(height: metrics.sizes.rowGap),
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
                  checkSize: hasAlso && i > 0
                      ? HeroAlso.itemCheck
                      : metrics.sizes.check,
                  strong: hasAlso && i > 0
                      ? metrics.itemStrong
                      : metrics.strong,
                  quiet: hasAlso && i > 0 ? metrics.itemQuiet : metrics.quiet,
                  checkFill: hasAlso && i > 0 ? metrics.itemCheckFill : null,
                  checkMark: hasAlso && i > 0 ? metrics.itemCheckMark : null,
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
    this.checkFill,
    this.checkMark,
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

  /// The check's fill and the mark inside it. Null is the highlight pair.
  final Color? checkFill;
  final Color? checkMark;

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
          color: checkFill ?? colors.highlight,
        ),
        alignment: Alignment.center,
        child: AppGlyph(
          GlyphType.check,
          size: checkSize * 0.56,
          color: checkMark ?? colors.onHighlight,
          strokeWidth: 3.4,
        ),
      ),
    );
  }
}

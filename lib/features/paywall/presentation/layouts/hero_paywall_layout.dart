import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/hero/hero_stage.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The mascot on a stage, reacting to one benefit playing large beside it,
/// over a headline and the benefits as plain lines.
///
/// The stage is the one thing that moves. It takes every point of height
/// the words under it do not need, so the screen is full on any phone. The
/// line of the benefit playing is the strong one in the list.
///
/// An id with no layout of its own draws this one.
class HeroPaywallLayout extends StatelessWidget {
  const HeroPaywallLayout({super.key});

  /// The side inset of the buy block.
  static const double _side = 20;

  @override
  Widget build(BuildContext context) {
    return PaywallFrame(
      // The mascot stands in the top left, so the cross takes the right.
      closeOnLeft: false,
      restAt: heroEntranceSeconds,
      builder: (context, scope) => _Hero(scope: scope),
    );
  }
}

/// The line the list shows for [benefit]: a short sentence of its own
/// where the layout has one, the benefit's title where it has none.
String heroLineFor(PaywallBenefit benefit) {
  final key = switch (benefit.id) {
    PaywallBenefitId.topics => LocaleKeys.paywall_hero_lines_topics,
    PaywallBenefitId.pushes => LocaleKeys.paywall_hero_lines_pushes,
    PaywallBenefitId.history => LocaleKeys.paywall_hero_lines_history,
    PaywallBenefitId.widgets => LocaleKeys.paywall_hero_lines_widgets,
    PaywallBenefitId.appIcons => LocaleKeys.paywall_hero_lines_app_icons,
    PaywallBenefitId.weeklyCheck => LocaleKeys.paywall_hero_lines_weekly_check,
    PaywallBenefitId.fireDrills ||
    PaywallBenefitId.wakeUpChallenges ||
    PaywallBenefitId.customAlarmScreens ||
    PaywallBenefitId.morningSummary => null,
  };
  return key == null ? benefit.title : key.tr(namedArgs: HostedBenefit.args);
}

/// What the composition measures on one phone.
class _Sizes {
  const _Sizes({
    required this.headline,
    required this.line,
    required this.check,
    required this.rowGap,
    required this.stageGap,
    required this.headlineGap,
    required this.bottomGap,
  });

  factory _Sizes.of({required bool isCompact}) => isCompact
      ? const _Sizes(
          headline: 26,
          line: 14.5,
          check: 18,
          rowGap: 5,
          stageGap: Spacing.s2,
          headlineGap: 10,
          bottomGap: Spacing.s3,
        )
      : const _Sizes(
          headline: 30,
          line: 16,
          check: 20,
          rowGap: 9,
          stageGap: Spacing.s3,
          headlineGap: 14,
          bottomGap: 20,
        );

  final double headline;
  final double line;
  final double check;
  final double rowGap;

  /// Between the stage and the headline.
  final double stageGap;

  /// Between the headline and the lines.
  final double headlineGap;

  /// Between the last line and the buy block.
  final double bottomGap;

  static const double checkGap = 10;
}

class _Hero extends StatelessWidget {
  const _Hero({required this.scope});

  final PaywallLayoutScope scope;

  /// The stage stops growing here. Past it the mascot and the card are at
  /// their largest, and more height is only more air.
  static const double _stageMax = 380;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final sizes = _Sizes.of(isCompact: scope.isCompact);
    final width = scope.size.width - HeroPaywallLayout._side * 2;
    final textWidth = width - sizes.check - _Sizes.checkGap;
    final benefits = scope.benefits;
    final isOne = benefits.length == 1;

    final headline = scope.isHosted
        ? LocaleKeys.paywall_hero_headline_hosted.tr()
        : LocaleKeys.paywall_hero_headline_pro.tr();
    final headlineStyle = AppTypography.headline(
      colors.onCanvas,
      fontSize: sizes.headline,
    );
    final strongStyle = AppTypography.small(
      colors.onCanvas,
      fontSize: sizes.line,
    ).copyWith(fontWeight: FontWeight.w700, height: 1.3);
    final quietStyle = strongStyle.copyWith(
      color: colors.onCanvasMuted,
      fontWeight: FontWeight.w500,
    );
    final sentenceStyle = AppTypography.small(
      colors.onCanvasMuted,
      fontSize: sizes.line,
    ).copyWith(height: 1.35);

    final lines = [for (final b in benefits) heroLineFor(b)];
    // A line keeps its height whether it is the strong one or not, so the
    // list never moves as the stage plays.
    double rowHeight(String text) => math.max(
      sizes.check,
      paywallTextHeight(context, text, strongStyle, textWidth),
    );
    final rowHeights = [for (final line in lines) rowHeight(line)];
    final sentence = isOne ? benefits.single.line : null;
    final sentenceHeight = sentence == null
        ? 0.0
        : Spacing.s1 +
              paywallTextHeight(context, sentence, sentenceStyle, textWidth);
    final words =
        paywallTextHeight(context, headline, headlineStyle, width) +
        sizes.headlineGap +
        rowHeights.fold(0, (sum, h) => sum + h) +
        sizes.rowGap * math.max(0, lines.length - 1) +
        sentenceHeight;

    // The stage takes what the words leave. Past its largest, the spare
    // height is shared out: most above and below the words, some to the
    // stage.
    final left = scope.size.height - words - sizes.stageGap - sizes.bottomGap;
    final spare = math.max(0, left - _stageMax);
    final stageHeight = math.max(0, math.min(left, _stageMax) + spare * 0.4);
    final stageGap = sizes.stageGap + spare * 0.3;

    final loop = HeroLoop([for (final b in benefits) b.previewId]);
    final bleedTop = MediaQuery.viewPaddingOf(context).top;

    // At the default text size this fits exactly. Where a large text size
    // leaves the stage no room, the words scroll in their own box and the
    // frame still does not.
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaywallClockBuilder(
            clock: scope.clock,
            builder: (context, t, _) {
              final isStill = scope.clock.isStill;
              return HeroStage(
                size: Size(scope.size.width, stageHeight.floorToDouble()),
                loop: loop,
                frame: loop.frameAt(t, isStill: isStill),
                seconds: isStill ? 0 : t,
                bleedTop: bleedTop,
              );
            },
          ),
          SizedBox(height: stageGap),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: HeroPaywallLayout._side,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Rise(
                  clock: scope.clock,
                  index: 0,
                  child: Semantics(
                    header: true,
                    child: Text(headline, style: headlineStyle),
                  ),
                ),
                SizedBox(height: sizes.headlineGap),
                for (final (i, line) in lines.indexed) ...[
                  if (i > 0) SizedBox(height: sizes.rowGap),
                  _Rise(
                    clock: scope.clock,
                    index: i + 1,
                    child: SizedBox(
                      height: rowHeights[i],
                      child: _Line(
                        clock: scope.clock,
                        loop: loop,
                        index: i,
                        text: line,
                        // What the short line leaves out is still said.
                        label: isOne ? null : benefits[i].line,
                        sizes: sizes,
                        strong: strongStyle,
                        quiet: quietStyle,
                      ),
                    ),
                  ),
                ],
                if (sentence != null)
                  _Rise(
                    clock: scope.clock,
                    index: 2,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: Spacing.s1,
                        left: sizes.check + _Sizes.checkGap,
                      ),
                      child: Text(sentence, style: sentenceStyle),
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

/// Brings one part of the words up into place during the entrance, each a
/// little after the one above it.
class _Rise extends StatelessWidget {
  const _Rise({required this.clock, required this.index, required this.child});

  final PaywallClock clock;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => PaywallClockBuilder(
    clock: clock,
    builder: (context, t, child) {
      final p = AppCurves.easeOut.transform(
        phase(stagger(index, t, each: 0.06, start: 0.3), 0, 0.36),
      );
      return Opacity(
        opacity: p,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - p)),
          child: child,
        ),
      );
    },
    child: child,
  );
}

/// One benefit as a plain line: a small filled check and the words. The
/// line of the benefit on the stage is the strong one.
class _Line extends StatelessWidget {
  const _Line({
    required this.clock,
    required this.loop,
    required this.index,
    required this.text,
    required this.label,
    required this.sizes,
    required this.strong,
    required this.quiet,
  });

  final PaywallClock clock;
  final HeroLoop loop;
  final int index;
  final String text;
  final String? label;
  final _Sizes sizes;
  final TextStyle strong;
  final TextStyle quiet;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      label: label == null ? text : '$text. $label',
      excludeSemantics: true,
      child: PaywallClockBuilder(
        clock: clock,
        builder: (context, t, check) {
          final frame = loop.frameAt(t, isStill: clock.isStill);
          final isActive = frame.activeIndex == index;
          // The check of the line that just took the stage pops once.
          final pop = isActive && frame.previous != null
              ? math.sin(math.pi * phase(frame.sceneSeconds, 0, 0.34))
              : 0.0;
          return Row(
            children: [
              Transform.scale(scale: 1 + 0.22 * pop, child: check),
              const SizedBox(width: _Sizes.checkGap),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: context.motion(AppDurations.base),
                  style: isActive ? strong : quiet,
                  child: Text(text),
                ),
              ),
            ],
          );
        },
        child: Container(
          width: sizes.check,
          height: sizes.check,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.highlight,
          ),
          alignment: Alignment.center,
          child: AppGlyph(
            GlyphType.check,
            size: sizes.check * 0.56,
            color: colors.onHighlight,
            strokeWidth: 3.4,
          ),
        ),
      ),
    );
  }
}

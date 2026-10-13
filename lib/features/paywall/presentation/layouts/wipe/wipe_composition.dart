import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/wipe/wipe_leaving_table.dart';
import 'package:critalarm/features/paywall/presentation/layouts/wipe/wipe_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/wipe/wipe_stage.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The approved composition with the wipe's stage on top: the stage, the
/// pips, a headline and the benefits as plain lines, all the kit's parts.
///
/// The stage uses the sideways drag for its divider, so a benefit is
/// chosen by a tap on its line, and by the loop.
///
/// For a plan that is leaving (see `wipeRunsBackwards`) the stage runs
/// backwards and the lines are replaced by a two column list of what the
/// plan keeps today and what it keeps from the day after it ends. The loop
/// still cycles the pictures. The list does not follow it.
class WipeComposition extends StatefulWidget {
  const WipeComposition({required this.scope, super.key});

  final PaywallLayoutScope scope;

  @override
  State<WipeComposition> createState() => _WipeCompositionState();
}

class _WipeCompositionState extends State<WipeComposition> {
  HeroPlayer? _player;

  PaywallLayoutScope get scope => widget.scope;

  // A choice of the hand redraws the words: when nothing may move no clock
  // ticks to do it.
  void _onPlayer() => setState(() {});

  HeroPlayer get _playing =>
      _player ??= HeroPlayer(clock: scope.clock)..addListener(_onPlayer);

  @override
  void dispose() {
    _player
      ?..removeListener(_onPlayer)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tones = PaywallToneColors.of(context, PaywallTone.canvas);
    final sizes = HeroSizes.of(isCompact: scope.isCompact);
    final width = scope.size.width - heroSideInset * 2;
    final benefits = scope.benefits;

    final name = scope.isHosted
        ? LocaleKeys.paywall_kit_name_hosted.tr()
        : LocaleKeys.paywall_kit_name_pro.tr();
    final variant = PaywallRouteInfo.headlineOf(context);
    final leaving = PaywallRouteInfo.leavingOf(context);
    final reversed = wipeRunsBackwards(
      isHosted: scope.isHosted,
      variant: variant,
      leaving: leaving,
      listed: benefits,
    );
    // The sides of a leaving plan are named by date: the day after the plan
    // ends, and today. Otherwise without either product the app is the free
    // one.
    final String before;
    final String after;
    if (reversed) {
      final ends = leaving!.endsOn;
      before = DateFormat(
        'd MMM',
      ).format(DateTime(ends.year, ends.month, ends.day + 1));
      after = LocaleKeys.paywall_leaving_wipe_today.tr();
    } else {
      before = LocaleKeys.paywall_wipe_tag_free.tr();
      after = name;
    }
    final headline = switch (wipeHeadlineFor(
      isHosted: scope.isHosted,
      variant: variant,
    )) {
      WipeHeadline.hosted => LocaleKeys.paywall_wipe_headline_hosted.tr(),
      WipeHeadline.pro => LocaleKeys.paywall_wipe_headline_pro.tr(),
      WipeHeadline.ended => LocaleKeys.paywall_wipe_ended_headline.tr(
        namedArgs: {'name': name},
      ),
      // A leaving headline with no leaving run is not reached: the run
      // needs the date, and a route that has none is the plain Wipe.
      WipeHeadline.leaving =>
        reversed
            ? LocaleKeys.paywall_leaving_wipe_headline.tr(
                namedArgs: {'date': before, 'name': name},
              )
            : LocaleKeys.paywall_wipe_headline_hosted.tr(),
    };
    final headlineStyle = AppTypography.headline(
      tones.ink,
      fontSize: sizes.headline,
    );

    final metrics = HeroLinesMetrics.measure(
      context,
      lines: [for (final b in benefits) heroLineFor(b)],
      width: width,
      sizes: sizes,
    );
    final lines = metrics.lines;
    final headlineHeight = paywallTextHeight(
      context,
      headline,
      headlineStyle,
      width,
    );
    final table = reversed
        ? WipeLeavingMetrics.measure(
            context,
            text: wipeLeavingTextFor(
              rows: wipeLeavingRowsFor(benefits),
              afterHead: before,
              critical: leaving!.facts?.criticalTopics,
            ),
            width: width,
            sizes: sizes,
          )
        : null;
    final words =
        headlineHeight + sizes.headlineGap + (table?.height ?? metrics.height);
    final centres = metrics.centresFrom(headlineHeight + sizes.headlineGap);

    final room = heroStageRoomFor(
      height: scope.size.height,
      words: words,
      gap: sizes.stageGap,
      bottomGap: sizes.bottomGap,
    );

    // After an intro the mascot is already there, so the entrance and the
    // sweep both start part of the way in.
    final lead = wipeLeadFor(followsIntro: scope.followsIntro);
    final player = _playing
      ..clock = scope.clock
      ..loop = HeroLoop([
        for (final b in benefits) b.previewId,
      ], prelude: -lead);

    return PaywallCueScore(
      clock: scope.clock,
      beats: wipeEntranceCues(lead: lead),
      player: player,
      turnCue: PaywallCue.next,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WipeStage(
              player: player,
              size: Size(scope.size.width, room.stage),
              before: before,
              after: after,
              lead: lead,
              reversed: reversed,
              label: reversed
                  ? LocaleKeys.paywall_leaving_wipe_compare_label.tr(
                      namedArgs: {'before': before, 'after': after},
                    )
                  : LocaleKeys.paywall_wipe_compare_label.tr(
                      namedArgs: {'before': before, 'name': name},
                    ),
              showing: (frame) => frame.activeIndex >= lines.length
                  ? null
                  : LocaleKeys.paywall_hero_stage_label.tr(
                      namedArgs: {'benefit': lines[frame.activeIndex]},
                    ),
            ),
            SizedBox(
              height: room.gap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: heroSideInset),
                child: HeroPips(
                  player: player,
                  count: lines.length,
                  color: tones.ink,
                ),
              ),
            ),
            // The room under the last line counts as that line, so it has
            // its full tap area.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTapUp: (details) {
                final line = heroLineAt(details.localPosition.dy, centres);
                if (line != null) player.touch(index: line);
              },
              child: Padding(
                padding: EdgeInsets.only(
                  left: heroSideInset,
                  right: heroSideInset,
                  bottom: math.max(0, room.under),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HeroRise(
                      clock: scope.clock,
                      index: 0,
                      after: -lead,
                      child: Semantics(
                        header: true,
                        child: Text(headline, style: headlineStyle),
                      ),
                    ),
                    SizedBox(height: sizes.headlineGap),
                    if (table != null)
                      WipeLeavingTable(metrics: table)
                    else
                      HeroBenefitLines(
                        player: player,
                        metrics: metrics,
                        labels: [for (final b in benefits) b.line],
                        handlesTaps: false,
                      ),
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

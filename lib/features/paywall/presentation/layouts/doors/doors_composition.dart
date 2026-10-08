import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/doors/doors_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/doors/doors_scene.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The approved composition with the doorway's stage on top: the stage,
/// the pips, a headline and the benefits as plain lines, all the kit's
/// parts on the app's own canvas.
class DoorsComposition extends StatefulWidget {
  const DoorsComposition({
    required this.scope,
    required this.headline,
    super.key,
  });

  final PaywallLayoutScope scope;
  final String headline;

  @override
  State<DoorsComposition> createState() => _DoorsCompositionState();
}

class _DoorsCompositionState extends State<DoorsComposition> {
  HeroPlayer? _player;

  PaywallLayoutScope get scope => widget.scope;

  // A choice of the hand redraws the words: when nothing may move no clock
  // ticks to do it.
  void _onPlayer() => setState(() {});

  HeroPlayer get _playing => _player ??= HeroPlayer(
    clock: scope.clock,
  )..addListener(_onPlayer);

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

    final headline = widget.headline;
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
    final words = headlineHeight + sizes.headlineGap + metrics.height;
    final centres = metrics.centresFrom(headlineHeight + sizes.headlineGap);

    final room = heroStageRoomFor(
      height: scope.size.height,
      words: words,
      gap: sizes.stageGap,
      bottomGap: sizes.bottomGap,
    );
    final stage = Size(scope.size.width, room.stage);
    final doors = doorsGeometryFor(stage);

    // The stage and the words come in as the door opens. After an intro
    // the door is already on its way.
    final lead = doorsLeadFor(followsIntro: scope.followsIntro);
    final prelude = DoorsTimeline.prelude - lead;
    final player = _playing
      ..clock = scope.clock
      ..loop = HeroLoop([
        for (final b in benefits) b.previewId,
      ], prelude: prelude);

    String? showing(HeroFrame frame) => frame.activeIndex >= lines.length
        ? null
        : LocaleKeys.paywall_hero_stage_label.tr(
            namedArgs: {'benefit': lines[frame.activeIndex]},
          );

    return PaywallCueScore(
      clock: scope.clock,
      // With no room for a doorway the approved stage has its own sounds.
      beats: doors == null
          ? heroEntranceCues(doorsMotion, prelude: prelude)
          : doorsCues(lead: lead),
      player: player,
      turnCue: PaywallCue.next,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (doors == null)
              // No room for a doorway: the approved stage, moving the same
              // way.
              HeroLiveStage(
                player: player,
                size: stage,
                label: showing,
                bleedTop: MediaQuery.viewPaddingOf(context).top,
                motion: doorsMotion,
              )
            else
              DoorsStage(
                player: player,
                size: stage,
                geometry: doors,
                count: benefits.length,
                label: showing,
                lead: lead,
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
                      after: prelude,
                      child: Semantics(
                        header: true,
                        child: Text(headline, style: headlineStyle),
                      ),
                    ),
                    SizedBox(height: sizes.headlineGap),
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

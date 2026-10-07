import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/wipe/wipe_stage.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The approved composition with the wipe's stage on top: the stage, the
/// pips, a headline and the benefits as plain lines, all the kit's parts.
///
/// The stage uses the sideways drag for its divider, so a benefit is
/// chosen by a tap on its line, and by the loop.
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
    final before = scope.isHosted
        ? LocaleKeys.paywall_wipe_tag_free.tr()
        : LocaleKeys.paywall_wipe_tag_standard.tr();
    final headline = scope.isHosted
        ? LocaleKeys.paywall_wipe_headline_hosted.tr()
        : LocaleKeys.paywall_wipe_headline_pro.tr();
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

    final player = _playing
      ..clock = scope.clock
      ..loop = HeroLoop([for (final b in benefits) b.previewId]);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WipeStage(
            player: player,
            size: Size(scope.size.width, room.stage),
            before: before,
            after: name,
            label: LocaleKeys.paywall_wipe_compare_label.tr(
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
    );
  }
}

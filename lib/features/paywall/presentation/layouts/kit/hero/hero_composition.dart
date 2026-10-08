import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_arrangement.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_entrance.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_lines.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_motion.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_pips.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_player.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_stage.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_layout_scope.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_measure.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// A [HeroStage] that plays: it redraws from a [HeroPlayer] on every tick
/// of the player's clock and answers the hand through a [HeroTouchArea].
///
/// Use it for a stage in a layout of your own. [size] is the stage's box.
/// The other options are the stage's: see [HeroStage]. [label] is what a
/// screen reader says for the picture at a frame.
class HeroLiveStage extends StatelessWidget {
  const HeroLiveStage({
    required this.player,
    required this.size,
    this.label,
    this.bleedTop = 0,
    this.arrange = heroArrangementFor,
    this.tone = PaywallTone.canvas,
    this.sceneBuilder,
    this.beside,
    this.showsShapes,
    this.motion = const HeroMotion(),
    this.swipes = true,
    super.key,
  });

  final HeroPlayer player;
  final Size size;
  final String? Function(HeroFrame frame)? label;
  final double bleedTop;
  final HeroArranger arrange;
  final PaywallTone tone;
  final HeroSceneBuilder? sceneBuilder;
  final Widget? beside;
  final bool? showsShapes;
  final HeroMotion motion;

  /// False leaves sideways drags to the layout. See [HeroTouchArea].
  final bool swipes;

  @override
  Widget build(BuildContext context) {
    return HeroTouchArea(
      player: player,
      swipes: swipes,
      child: PaywallClockBuilder(
        clock: player.clock,
        builder: (context, t, _) {
          final frame = player.frameAt(t);
          return Semantics(
            container: true,
            image: true,
            label: label?.call(frame),
            child: HeroStage(
              size: size,
              frame: frame,
              seconds: player.stageSeconds(t),
              bleedTop: bleedTop,
              pull: player.pullAt(t),
              arrange: arrange,
              tone: tone,
              sceneBuilder: sceneBuilder,
              beside: beside,
              showsShapes: showsShapes,
              motion: motion,
            ),
          );
        },
      ),
    );
  }
}

/// Draws the headline of a [HeroComposition] in the room measured for
/// `headline`, in [style].
typedef HeroHeadlineBuilder =
    Widget Function(BuildContext context, String headline, TextStyle style);

/// The whole approved composition: the stage on top, taking every point of
/// height the words do not need, then the pips, the headline, and the
/// benefits as plain lines. Return it from a `PaywallFrame` builder.
///
/// It answers the hand: a swipe across the stage goes to the next benefit
/// or the previous one, a tap on a line puts that benefit on the stage,
/// and a tap on the stage plays the current one again. The chosen benefit
/// plays its turn, holds, and the loop goes on. While a finger is down on
/// the stage the loop waits.
///
/// With nothing but [scope] it is the Hero layout. A layout that changes
/// one thing passes that one thing:
/// - [headline], or [headlineBuilder] to draw it another way.
/// - [lines], the short line of each benefit.
/// - [loop], a table of turns of its own, or the approved one with a
///   `prelude` so a beat of the layout's own plays first.
/// - [arrange], [tone], [sceneBuilder], [beside], [showsShapes]: the
///   stage's, see [HeroStage].
/// - [motion], a [HeroMotion] that names another atmosphere, entrance,
///   idle or way for a preview to arrive.
/// - [player], to read the frame from outside: for a backdrop that
///   follows the loop.
///
/// Give the frame `restAt: loop.entranceEnd` ([heroEntranceSeconds] for
/// the approved loop) and a `tone` that matches [tone].
///
/// At the default text size it fits exactly. Where a large text size
/// leaves the stage no room, the words scroll in their own box and the
/// frame still does not.
class HeroComposition extends StatefulWidget {
  const HeroComposition({
    required this.scope,
    this.headline,
    this.headlineBuilder,
    this.lines,
    this.loop,
    this.player,
    this.arrange = heroArrangementFor,
    this.tone = PaywallTone.canvas,
    this.sceneBuilder,
    this.beside,
    this.showsShapes,
    this.motion = const HeroMotion(),
    super.key,
  });

  final PaywallLayoutScope scope;

  /// Null is the approved headline for the scope's product.
  final String? headline;
  final HeroHeadlineBuilder? headlineBuilder;

  /// One short line per benefit. Null is [heroLineFor] each.
  final List<String>? lines;

  /// Null is the approved loop for the scope's benefits.
  final HeroLoop? loop;

  /// Null makes one and keeps it.
  final HeroPlayer? player;
  final HeroArranger arrange;
  final PaywallTone tone;
  final HeroSceneBuilder? sceneBuilder;
  final Widget? beside;
  final bool? showsShapes;

  /// The stage's motion variants. See [HeroMotion].
  final HeroMotion motion;

  @override
  State<HeroComposition> createState() => _HeroCompositionState();
}

class _HeroCompositionState extends State<HeroComposition> {
  HeroPlayer? _own;
  HeroPlayer? _listened;

  PaywallLayoutScope get scope => widget.scope;

  HeroPlayer get _player =>
      widget.player ?? (_own ??= HeroPlayer(clock: scope.clock));

  // A choice of the hand redraws the words: when nothing may move no clock
  // ticks to do it.
  void _onPlayer() => setState(() {});

  void _listen() {
    final player = _player;
    if (identical(player, _listened)) return;
    _listened?.removeListener(_onPlayer);
    _listened = player..addListener(_onPlayer);
  }

  @override
  void dispose() {
    _listened?.removeListener(_onPlayer);
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tones = PaywallToneColors.of(context, widget.tone);
    final sizes = HeroSizes.of(isCompact: scope.isCompact);
    final width = scope.size.width - heroSideInset * 2;
    final benefits = scope.benefits;
    final isOne = benefits.length == 1;

    final headline =
        widget.headline ??
        (scope.isHosted
            ? LocaleKeys.paywall_hero_headline_hosted.tr()
            : LocaleKeys.paywall_hero_headline_pro.tr());
    final headlineStyle = AppTypography.headline(
      tones.ink,
      fontSize: sizes.headline,
    );
    final sentenceStyle = AppTypography.small(
      tones.muted,
      fontSize: sizes.line,
    ).copyWith(height: 1.35);

    final metrics = HeroLinesMetrics.measure(
      context,
      lines: widget.lines ?? [for (final b in benefits) heroLineFor(b)],
      width: width,
      sizes: sizes,
      tone: widget.tone,
    );
    final lines = metrics.lines;
    final rowHeights = metrics.rowHeights;
    final sentence = isOne ? benefits.single.line : null;
    final sentenceHeight = sentence == null
        ? 0.0
        : Spacing.s1 +
              paywallTextHeight(
                context,
                sentence,
                sentenceStyle,
                metrics.textWidth,
              );
    final headlineHeight = paywallTextHeight(
      context,
      headline,
      headlineStyle,
      width,
    );
    final words =
        headlineHeight +
        sizes.headlineGap +
        rowHeights.fold(0, (sum, h) => sum + h) +
        sizes.rowGap * math.max(0, lines.length - 1) +
        sentenceHeight;

    // Where the middle of each line is, down the block of words. A tap is
    // matched to a line with these.
    final centres = metrics.centresFrom(headlineHeight + sizes.headlineGap);

    // The stage takes what the words leave. The room under the last line
    // belongs to the lines, so the last one has its full tap area. It ends
    // where the buy block starts.
    final room = heroStageRoomFor(
      height: scope.size.height,
      words: words,
      gap: sizes.stageGap,
      bottomGap: sizes.bottomGap,
    );

    final player = _player
      ..clock = scope.clock
      ..loop = widget.loop ?? HeroLoop([for (final b in benefits) b.previewId]);
    _listen();
    final after = player.loop.prelude;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HeroLiveStage(
            player: player,
            size: Size(scope.size.width, room.stage),
            label: (frame) => frame.activeIndex >= lines.length
                ? null
                : LocaleKeys.paywall_hero_stage_label.tr(
                    namedArgs: {'benefit': lines[frame.activeIndex]},
                  ),
            bleedTop: MediaQuery.viewPaddingOf(context).top,
            arrange: widget.arrange,
            tone: widget.tone,
            sceneBuilder: widget.sceneBuilder,
            beside: widget.beside,
            showsShapes: widget.showsShapes,
            motion: widget.motion,
          ),
          SizedBox(
            height: room.gap,
            child: lines.length < 2
                ? null
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: heroSideInset,
                    ),
                    child: HeroPips(
                      player: player,
                      count: lines.length,
                      color: tones.ink,
                    ),
                  ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTapUp: isOne
                ? null
                : (details) {
                    final line = heroLineAt(details.localPosition.dy, centres);
                    if (line != null) player.touch(index: line);
                  },
            child: Padding(
              padding: EdgeInsets.only(
                left: heroSideInset,
                right: heroSideInset,
                bottom: room.under,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HeroRise(
                    clock: scope.clock,
                    index: 0,
                    after: after,
                    child: Semantics(
                      header: true,
                      child:
                          widget.headlineBuilder?.call(
                            context,
                            headline,
                            headlineStyle,
                          ) ??
                          Text(headline, style: headlineStyle),
                    ),
                  ),
                  SizedBox(height: sizes.headlineGap),
                  HeroBenefitLines(
                    player: player,
                    metrics: metrics,
                    // What the short line leaves out is still said.
                    labels: [for (final b in benefits) b.line],
                    isPickable: !isOne,
                    handlesTaps: false,
                  ),
                  if (sentence != null)
                    HeroRise(
                      clock: scope.clock,
                      index: 2,
                      after: after,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: Spacing.s1,
                          left: sizes.check + HeroSizes.checkGap,
                        ),
                        child: Text(sentence, style: sentenceStyle),
                      ),
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

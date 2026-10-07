import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/hosted_benefit.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_frame.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/sentence/sentence_rules.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// The kit's stage over one sentence in display type. The sentence has a
/// stem that never changes and an underlined ending that rolls to the
/// benefit on the stage, then one quiet row naming every benefit.
///
/// The stage, the pips, the loop and the hand are the kit's. A swipe
/// across the stage or across the sentence rolls the ending, and a tap on
/// a name in the row puts that benefit on the stage.
class SentenceComposition extends StatefulWidget {
  const SentenceComposition({required this.scope, super.key});

  final PaywallLayoutScope scope;

  @override
  State<SentenceComposition> createState() => _SentenceCompositionState();
}

class _SentenceCompositionState extends State<SentenceComposition> {
  /// The row of names is one tap area tall, with its words in the middle.
  static const double _rosterHeight = 44;

  /// Under the last line of the ending, so its underline is never cut.
  static const double _tailSlack = 4;

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
    final scale = MediaQuery.textScalerOf(context).scale(100) / 100;

    // Display type, larger than the kit's headline: the sentence is the
    // list. At a large text size it steps down to the kit's size.
    final fontSize = scale > 1.3
        ? sizes.headline
        : (scope.isCompact ? 32.0 : 40.0);
    final stemStyle = AppTypography.headline(tones.ink, fontSize: fontSize);
    final tailStyle = stemStyle.copyWith(
      decoration: TextDecoration.underline,
      decorationColor: tones.ink,
      decorationThickness: 1.6,
    );
    final nameStyle = AppTypography.small(
      tones.ink,
      fontSize: sizes.line - 1,
    ).copyWith(fontWeight: FontWeight.w600);

    final stem = scope.isHosted
        ? LocaleKeys.paywall_sentence_stem_hosted.tr()
        : LocaleKeys.paywall_sentence_stem_pro.tr();
    final tails = [
      for (final b in benefits)
        sentenceTailKeyFor(b.id).tr(namedArgs: HostedBenefit.args),
    ];
    final names = [for (final b in benefits) sentenceNameKeyFor(b.id).tr()];

    // The ending's box is as tall as the tallest ending, so nothing under
    // it moves as the endings roll.
    final stemHeight = paywallTextHeight(context, stem, stemStyle, width);
    final tailBox =
        tails.fold<double>(
          0,
          (tallest, tail) => math.max(
            tallest,
            paywallTextHeight(context, tail, tailStyle, width),
          ),
        ) +
        _tailSlack;
    final words = stemHeight + tailBox + _rosterHeight;

    final room = heroStageRoomFor(
      height: scope.size.height,
      words: words,
      gap: sizes.stageGap,
      bottomGap: Spacing.s1,
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
          HeroLiveStage(
            player: player,
            size: Size(scope.size.width, room.stage),
            label: (frame) => frame.activeIndex >= benefits.length
                ? null
                : LocaleKeys.paywall_hero_stage_label.tr(
                    namedArgs: {
                      'benefit': heroLineFor(benefits[frame.activeIndex]),
                    },
                  ),
            bleedTop: MediaQuery.viewPaddingOf(context).top,
          ),
          SizedBox(
            height: room.gap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: heroSideInset),
              child: HeroPips(
                player: player,
                count: benefits.length,
                color: tones.ink,
              ),
            ),
          ),
          Padding(
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
                  // A swipe across the sentence rolls it, as on the stage.
                  child: HeroTouchArea(
                    player: player,
                    child: _Sentence(
                      player: player,
                      stem: stem,
                      tails: tails,
                      stemStyle: stemStyle,
                      tailStyle: tailStyle,
                      tailBox: tailBox,
                    ),
                  ),
                ),
                HeroRise(
                  clock: scope.clock,
                  index: 2,
                  child: SizedBox(
                    height: _rosterHeight,
                    child: _Roster(
                      player: player,
                      names: names,
                      said: [for (final b in benefits) b.line],
                      style: nameStyle,
                      muted: tones.muted,
                    ),
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

/// The stem, and under it the ending of the turn on the stage. While the
/// stage changes its picture the old ending rolls out and the new one
/// rolls in, clipped to the ending's box like a digit on a counter.
class _Sentence extends StatelessWidget {
  const _Sentence({
    required this.player,
    required this.stem,
    required this.tails,
    required this.stemStyle,
    required this.tailStyle,
    required this.tailBox,
  });

  final HeroPlayer player;
  final String stem;
  final List<String> tails;
  final TextStyle stemStyle;
  final TextStyle tailStyle;
  final double tailBox;

  Widget _ending(int index, double at, double opacity) => Positioned(
    top: at * tailBox,
    left: 0,
    right: 0,
    child: Opacity(
      opacity: opacity,
      child: Text(tails[index], style: tailStyle),
    ),
  );

  @override
  Widget build(BuildContext context) => PaywallClockBuilder(
    clock: player.clock,
    builder: (context, t, stemLine) {
      final frame = player.frameAt(t);
      final now = frame.activeIndex.clamp(0, tails.length - 1);
      final before = frame.previous?.index;
      final p = AppCurves.easeOut.transform(frame.cardEnter.clamp(0, 1));
      final roll = sentenceRollAt(
        enter: p,
        direction: frame.direction,
        isChange: before != null && before != now && before < tails.length,
      );
      final leaving = roll.leaving;
      return Semantics(
        header: true,
        label: LocaleKeys.paywall_sentence_sentence_label.tr(
          namedArgs: {'stem': stem, 'tail': tails[now]},
        ),
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            stemLine!,
            SizedBox(
              height: tailBox,
              child: ClipRect(
                child: Stack(
                  children: [
                    if (leaving != null && before != null)
                      _ending(before, leaving, 1 - p),
                    _ending(now, roll.arriving, leaving == null ? 1 : p),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
    child: Text(stem, style: stemStyle),
  );
}

/// One quiet row naming every benefit. The name of the one in the sentence
/// is ink, the rest are muted, and each is a button that puts its benefit
/// on the stage. The row shrinks to stay on one line.
class _Roster extends StatelessWidget {
  const _Roster({
    required this.player,
    required this.names,
    required this.said,
    required this.style,
    required this.muted,
  });

  static const double _between = 18;

  final HeroPlayer player;
  final List<String> names;

  /// What a screen reader adds after each name.
  final List<String> said;
  final TextStyle style;
  final Color muted;

  @override
  Widget build(BuildContext context) => PaywallClockBuilder(
    clock: player.clock,
    builder: (context, t, _) {
      final active = player.frameAt(t).activeIndex;
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, name) in names.indexed)
              Semantics(
                button: true,
                selected: i == active,
                label: '$name. ${said[i]}',
                excludeSemantics: true,
                onTap: () => player.touch(index: i),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => player.touch(index: i),
                  child: Container(
                    height: 44,
                    alignment: AlignmentDirectional.centerStart,
                    padding: EdgeInsetsDirectional.only(
                      end: i == names.length - 1 ? 0 : _between,
                    ),
                    child: AnimatedDefaultTextStyle(
                      duration: context.motion(AppDurations.base),
                      style: i == active ? style : style.copyWith(color: muted),
                      child: Text(name),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

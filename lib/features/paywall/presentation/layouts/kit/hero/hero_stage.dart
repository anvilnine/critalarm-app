import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_arrangement.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_atmosphere.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_mascot.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/extras_preview_stage.dart';
import 'package:flutter/material.dart';

/// Draws the picture of one turn on the stage, in a box [size] points
/// large. [playFrom] is the clock second the turn's own motion starts at
/// zero: read time through `PaywallPreviewClock` against it, as a preview
/// does, and the picture waits, holds and replays with the loop.
typedef HeroSceneBuilder =
    Widget Function(
      BuildContext context,
      HeroScene scene,
      Size size,
      double? playFrom,
    );

/// The stage: the mascot and one turn's picture on a disc with soft shapes
/// drifting behind.
///
/// It draws the [frame] it is given and holds no time of its own, so the
/// resting frame is just another frame. This is the still part. To have it
/// play and answer the hand, use `HeroLiveStage`, which feeds it from a
/// `HeroPlayer`.
///
/// What a layout can change, each on its own:
/// - [arrange] places the mascot and the card. The default is the approved
///   pair, which drops the card and then the mascot as the stage shrinks.
/// - [tone] is what the stage is painted on. It colours the atmosphere.
/// - [sceneBuilder] draws each turn's picture in place of the benefit's
///   preview. The stage still rounds its corners, lifts it on a shadow,
///   fades one turn into the next and slides it under a swipe.
/// - [beside] replaces the card altogether with one widget that stays
///   through every turn: a receipt, a door, a phone. It gets the card's
///   box and entrance and nothing else.
class HeroStage extends StatelessWidget {
  const HeroStage({
    required this.size,
    required this.frame,
    required this.seconds,
    this.bleedTop = 0,
    this.pull = 0,
    this.arrange = heroArrangementFor,
    this.tone = PaywallTone.canvas,
    this.sceneBuilder,
    this.beside,
    this.showsShapes,
    super.key,
  });

  final Size size;
  final HeroFrame frame;

  /// The clock, for the drift of the shapes and the cue of a preview on
  /// its way out. Zero when nothing may move.
  final double seconds;

  /// How far the shapes run up past the stage, under the status bar.
  final double bleedTop;

  /// How far the finger holds the card off its place, in points.
  final double pull;

  /// Places the mascot and the card in [size].
  final HeroArranger arrange;

  /// What the stage is painted on.
  final PaywallTone tone;

  /// Draws a turn's picture. Null draws the turn's preview.
  final HeroSceneBuilder? sceneBuilder;

  /// One widget in the card's place for every turn. It wins over
  /// [sceneBuilder].
  final Widget? beside;

  /// Whether the small shapes drift around the disc. Null keeps the
  /// approved rule: only when the mascot and the card both stand.
  final bool? showsShapes;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final arrangement = arrange(size);
    final scene = frame.scene;
    final e = frame.entrance;
    final air = HeroAtmosphereColors.of(context, tone);

    // The card follows the mascot in from the side.
    final cardArrive = AppCurves.easeBack.transform(phase(e, 0.42, 0.92));
    final cardIn = phase(e, 0.42, 0.6);

    return ExcludeSemantics(
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: -bleedTop,
              bottom: 0,
              child: CustomPaint(
                painter: HeroAtmospherePainter(
                  focus: arrangement.kind == HeroStageKind.none
                      ? Offset(size.width / 2, bleedTop + size.height / 2)
                      : arrangement.group.center.translate(0, bleedTop),
                  // As wide as the pair, and never past the stage's foot,
                  // where the words start.
                  radius: math.min(
                    arrangement.kind == HeroStageKind.none
                        ? size.shortestSide * 0.5
                        : arrangement.group.longestSide * 0.56,
                    size.height -
                        (arrangement.kind == HeroStageKind.none
                            ? size.height / 2
                            : arrangement.group.center.dy),
                  ),
                  seconds: seconds,
                  entrance: e,
                  showsShapes:
                      showsShapes ?? arrangement.kind == HeroStageKind.pair,
                  disc: air.disc,
                  soft: air.soft,
                  strong: air.strong,
                  light: air.light,
                ),
              ),
            ),
            if (arrangement.kind == HeroStageKind.pair &&
                (scene != null || beside != null))
              Positioned.fromRect(
                rect: arrangement.card,
                child: Opacity(
                  opacity: cardIn,
                  child: Transform.translate(
                    offset: Offset(28 * (1 - cardArrive) + pull, 0),
                    child: Transform.scale(
                      scale: 0.82 + 0.18 * cardArrive,
                      child:
                          beside ??
                          _Card(
                            // The approved card is a square, to the
                            // last fraction of a point.
                            size: _cardSize(arrangement.card),
                            frame: frame,
                            isDark: isDark,
                            sceneBuilder: sceneBuilder,
                          ),
                    ),
                  ),
                ),
              ),
            if (arrangement.kind != HeroStageKind.none)
              Positioned.fromRect(
                rect: arrangement.mascot,
                child: HeroMascot.frame(
                  frame,
                  size: arrangement.mascot.width,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Size _cardSize(Rect card) => (card.width - card.height).abs() < 0.01
    ? Size.square(card.width)
    : card.size;

/// How far a preview travels sideways as a swipe brings it in or sends it
/// out, in points.
const double heroCardSlide = 30;

/// The picture of the turn playing, lifted off the stage. The one on
/// its way out fades under the one coming in. After a swipe the new one
/// comes in from the side the finger pulled it from, and the old one
/// leaves from where the finger let it go.
class _Card extends StatelessWidget {
  const _Card({
    required this.size,
    required this.frame,
    required this.isDark,
    required this.sceneBuilder,
  });

  final Size size;
  final HeroFrame frame;
  final bool isDark;
  final HeroSceneBuilder? sceneBuilder;

  Widget _picture(BuildContext context, HeroScene scene, double? playFrom) {
    final own = sceneBuilder;
    if (own != null) {
      // A layout's own picture gets the card's corners.
      return ClipRRect(
        borderRadius: BorderRadius.circular(
          extrasPreviewRadius(size.shortestSide),
        ),
        child: own(context, scene, size, playFrom),
      );
    }
    final preview = scene.preview;
    if (preview == null) return SizedBox.fromSize(size: size);
    return PaywallPreview(
      preview,
      sizeClass: PaywallPreviewClass.large,
      size: size,
      playFrom: playFrom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scene = frame.scene!;
    final previous = frame.previous;
    final enter = frame.cardEnter;
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(
        extrasPreviewRadius(size.shortestSide),
      ),
      boxShadow: AppShadows.shadowLg(isDark: isDark),
    );
    final side = frame.direction * heroCardSlide;
    // The finger's pull is handed over: the stage lets go of it as the
    // old preview takes it away.
    final out = frame.pull - side * AppCurves.easeOut.transform(enter);
    final into = side * (1 - AppCurves.easeSpring.transform(enter));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (previous != null && enter < 1)
          Transform.translate(
            key: ValueKey(frame.previousTurn),
            offset: Offset(out, 0),
            child: Opacity(
              opacity: 1 - enter,
              child: DecoratedBox(
                decoration: decoration,
                child: _picture(context, previous, frame.previousPlayFrom),
              ),
            ),
          ),
        Transform.translate(
          key: ValueKey(frame.turn),
          offset: Offset(into, 0),
          child: Opacity(
            opacity: enter,
            child: Transform.scale(
              scale: 0.94 + 0.06 * AppCurves.easeBack.transform(enter),
              child: DecoratedBox(
                decoration: decoration,
                child: _picture(context, scene, frame.playFrom),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

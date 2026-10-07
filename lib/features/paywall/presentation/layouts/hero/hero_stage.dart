import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/hero/hero_arrangement.dart';
import 'package:critalarm/features/paywall/presentation/layouts/hero/hero_atmosphere.dart';
import 'package:critalarm/features/paywall/presentation/layouts/hero/hero_faces.dart';
import 'package:critalarm/features/paywall/presentation/layouts/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/hero/hero_props.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/extras_preview_stage.dart';
import 'package:flutter/material.dart';

/// The top of the Hero layout: the mascot and one benefit's preview on a
/// stage of soft shapes.
///
/// It draws the [frame] it is given and holds no time of its own, so the
/// resting frame is just another frame. [bleedTop] is how far the shapes
/// run up past the stage, under the status bar.
class HeroStage extends StatelessWidget {
  const HeroStage({
    required this.size,
    required this.frame,
    required this.seconds,
    required this.bleedTop,
    this.pull = 0,
    super.key,
  });

  final Size size;
  final HeroFrame frame;

  /// The clock, for the drift of the shapes and the cue of a preview on
  /// its way out. Zero when nothing may move.
  final double seconds;
  final double bleedTop;

  /// How far the finger holds the card off its place, in points.
  final double pull;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final arrangement = heroArrangementFor(size);
    final scene = frame.scene;
    final e = frame.entrance;

    // The mascot pops up from a little below, past its size and back.
    final arrive = AppCurves.easeBack.transform(phase(e, 0.08, 0.6));
    final bob = frame.bob == 0
        ? 0.0
        : -3 * math.sin(2 * math.pi * frame.bob / 3.2);
    final lift = bob - frame.hop * arrangement.mascot.width * 0.08;

    // The card follows it in from the side.
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
                  showsShapes: arrangement.kind == HeroStageKind.pair,
                  // The dark canvas gets a little of the yellow back, or
                  // the stage would be one flat black.
                  disc: isDark
                      ? Color.alphaBlend(
                          colors.yellow.withValues(alpha: 0.07),
                          colors.canvasAlt,
                        )
                      : colors.canvasAlt,
                  soft: isDark
                      ? colors.yellow.withValues(alpha: 0.07)
                      : colors.canvasGhost,
                  strong: isDark
                      ? colors.yellow.withValues(alpha: 0.16)
                      : colors.canvasGhostStrong,
                  light: colors.surface.withValues(alpha: isDark ? 0.5 : 0.4),
                ),
              ),
            ),
            if (arrangement.kind == HeroStageKind.pair && scene != null)
              Positioned.fromRect(
                rect: arrangement.card,
                child: Opacity(
                  opacity: cardIn,
                  child: Transform.translate(
                    offset: Offset(28 * (1 - cardArrive) + pull, 0),
                    child: Transform.scale(
                      scale: 0.82 + 0.18 * cardArrive,
                      child: _Card(
                        edge: arrangement.card.width,
                        frame: frame,
                        isDark: isDark,
                      ),
                    ),
                  ),
                ),
              ),
            if (arrangement.kind != HeroStageKind.none)
              Positioned.fromRect(
                rect: arrangement.mascot,
                child: Transform.translate(
                  offset: Offset(0, 26 * (1 - arrive) + lift),
                  child: Transform.scale(
                    scale: arrive,
                    alignment: Alignment.bottomCenter,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        FaceWidget(
                          state: FaceState.happy,
                          shape: heroShapeAt(frame),
                          size: arrangement.mascot.width,
                        ),
                        if (frame.props.isNotEmpty)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: HeroPropsPainter(
                                props: frame.props,
                                fill: colors.faceFill,
                                stroke: colors.faceStroke,
                                lens: colors.inkFixed,
                                glint: colors.onHighlight,
                                bow: colors.highlight,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// How far a preview travels sideways as a swipe brings it in or sends it
/// out, in points.
const double heroCardSlide = 30;

/// The preview of the benefit playing, lifted off the stage. The one on
/// its way out fades under the one coming in. After a swipe the new one
/// comes in from the side the finger pulled it from, and the old one
/// leaves from where the finger let it go.
class _Card extends StatelessWidget {
  const _Card({
    required this.edge,
    required this.frame,
    required this.isDark,
  });

  final double edge;
  final HeroFrame frame;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final scene = frame.scene!;
    final previous = frame.previous;
    final enter = frame.cardEnter;
    final size = Size.square(edge);
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(extrasPreviewRadius(edge)),
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
                child: PaywallPreview(
                  previous.preview,
                  sizeClass: PaywallPreviewClass.large,
                  size: size,
                  playFrom: frame.previousPlayFrom,
                ),
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
                child: PaywallPreview(
                  scene.preview,
                  sizeClass: PaywallPreviewClass.large,
                  size: size,
                  playFrom: frame.playFrom,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

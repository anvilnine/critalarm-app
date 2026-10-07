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
    required this.loop,
    required this.frame,
    required this.seconds,
    required this.bleedTop,
    super.key,
  });

  final Size size;
  final HeroLoop loop;
  final HeroFrame frame;

  /// The clock, for the drift of the shapes and the cue of a preview on
  /// its way out. Zero when nothing may move.
  final double seconds;
  final double bleedTop;

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
                  disc: colors.canvasAlt,
                  soft: colors.canvasGhost,
                  strong: colors.canvasGhostStrong,
                  light: colors.surface.withValues(alpha: isDark ? 0.05 : 0.4),
                ),
              ),
            ),
            if (arrangement.kind == HeroStageKind.pair && scene != null)
              Positioned.fromRect(
                rect: arrangement.card,
                child: Opacity(
                  opacity: cardIn,
                  child: Transform.translate(
                    offset: Offset(28 * (1 - cardArrive), 0),
                    child: Transform.scale(
                      scale: 0.82 + 0.18 * cardArrive,
                      child: _Card(
                        edge: arrangement.card.width,
                        loop: loop,
                        frame: frame,
                        seconds: seconds,
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

/// The preview of the benefit playing, lifted off the stage. The one on
/// its way out fades under the one coming in.
class _Card extends StatelessWidget {
  const _Card({
    required this.edge,
    required this.loop,
    required this.frame,
    required this.seconds,
    required this.isDark,
  });

  final double edge;
  final HeroLoop loop;
  final HeroFrame frame;
  final double seconds;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final scene = frame.scene!;
    final previous = frame.previous;
    final enter = frame.cardEnter;
    final size = Size.square(edge);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(extrasPreviewRadius(edge)),
        boxShadow: AppShadows.shadowLg(isDark: isDark),
      ),
      child: Stack(
        children: [
          if (previous != null && enter < 1)
            Opacity(
              opacity: 1 - enter,
              child: PaywallPreview(
                previous.preview,
                key: ValueKey(previous.index),
                sizeClass: PaywallPreviewClass.large,
                size: size,
                playFrom: loop.previousPlayFrom(seconds, frame),
              ),
            ),
          Opacity(
            opacity: enter,
            child: Transform.scale(
              scale: 0.94 + 0.06 * AppCurves.easeBack.transform(enter),
              child: PaywallPreview(
                scene.preview,
                key: ValueKey(scene.index),
                sizeClass: PaywallPreviewClass.large,
                size: size,
                playFrom: frame.playFrom,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

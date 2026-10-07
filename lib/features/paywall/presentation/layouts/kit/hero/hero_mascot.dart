import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_faces.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_props.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:flutter/material.dart';

/// Crit as an actor: a face at a size, with a hop, a bob, a blink, a pop
/// in, and what it wears.
///
/// Use it wherever a layout wants the mascot reacting: the stage draws one,
/// and it works alone in any box [size] points square. It holds no time.
/// Every value comes from the caller, so the resting frame is just the
/// defaults: glad, level, upright, nothing worn.
///
/// Inside a loop, use [HeroMascot.frame]. Alone on a clock at `t` seconds:
///
/// ```dart
/// HeroMascot(
///   size: 96,
///   face: HeroFace.keen,
///   bob: t,
///   blink: heroBlinkAt(t),
///   entrance: phase(t, 0, heroEntranceSeconds),
/// )
/// ```
class HeroMascot extends StatelessWidget {
  const HeroMascot({
    required this.size,
    this.face = HeroFace.glad,
    this.fromFace,
    this.faceBlend = 1,
    this.blink = 0,
    this.hop = 0,
    this.bob = 0,
    this.entrance = 1,
    this.props = const {},
    super.key,
  });

  /// The mascot as [frame] has it.
  HeroMascot.frame(HeroFrame frame, {required this.size, super.key})
    : face = frame.face,
      fromFace = frame.fromFace,
      faceBlend = frame.faceBlend,
      blink = frame.blink,
      hop = frame.hop,
      bob = frame.bob,
      entrance = frame.entrance,
      props = frame.props;

  /// The edge of the square the face is drawn in.
  final double size;

  /// The face it makes, [faceBlend] of the way there from [fromFace].
  final HeroFace face;
  final HeroFace? fromFace;
  final double faceBlend;

  /// How far the eyes are shut, 0 to 1. See [heroBlinkAt].
  final double blink;

  /// How high it is in a hop, 0 to 1. One is 8 percent of [size].
  final double hop;

  /// The seconds the idle bob reads, 3 points up and down every 3.2
  /// seconds. Zero holds it level.
  final double bob;

  /// How far through its entrance, 0 to 1: it pops up from a little below,
  /// past its size and back. Zero draws nothing.
  final double entrance;

  /// How far on each worn prop is, 0 to 1. Empty wears nothing.
  final Map<HeroProp, double> props;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // The mascot pops up from a little below, past its size and back.
    final arrive = AppCurves.easeBack.transform(phase(entrance, 0.08, 0.6));
    final sway = bob == 0 ? 0.0 : -3 * math.sin(2 * math.pi * bob / 3.2);
    final lift = sway - hop * size * 0.08;

    return Transform.translate(
      offset: Offset(0, 26 * (1 - arrive) + lift),
      child: Transform.scale(
        scale: arrive,
        alignment: Alignment.bottomCenter,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            FaceWidget(
              state: FaceState.happy,
              shape: heroShapeFor(
                face: face,
                fromFace: fromFace,
                faceBlend: faceBlend,
                blink: blink,
              ),
              size: size,
            ),
            if (props.isNotEmpty)
              Positioned.fill(
                child: CustomPaint(
                  painter: HeroPropsPainter(
                    props: props,
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
    );
  }
}

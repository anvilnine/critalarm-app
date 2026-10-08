import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_faces.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_motion.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_props.dart';
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
    this.entranceStyle = HeroEntranceStyle.pop,
    this.idle = HeroIdleStyle.bob,
    this.turnSeconds = 0,
    this.footDrop,
    super.key,
  });

  /// The mascot as [frame] has it, moving as [motion] says.
  HeroMascot.frame(
    HeroFrame frame, {
    required this.size,
    HeroMotion motion = const HeroMotion(),
    this.footDrop,
    super.key,
  }) : entranceStyle = motion.entrance,
       idle = motion.idle,
       turnSeconds = frame.sceneSeconds,
       face = frame.face,
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

  /// How far through its entrance, 0 to 1. Zero draws nothing.
  final double entrance;

  /// How it comes on. The approved one pops up from a little below, past
  /// its size and back.
  final HeroEntranceStyle entranceStyle;

  /// How far its top is above the foot of the stage it stands on, for an
  /// entrance that starts under that foot. Null with no stage.
  final double? footDrop;

  /// What it does while it waits. Every style reads [bob] as its clock.
  final HeroIdleStyle idle;

  /// How long the turn on the stage has played, for an idle that marks a
  /// new benefit.
  final double turnSeconds;

  /// How far on each worn prop is, 0 to 1. Empty wears nothing.
  final Map<HeroProp, double> props;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final arrive = heroEntrancePose(
      entranceStyle,
      entrance,
      size: size,
      footDrop: footDrop,
    );
    final wait = heroIdlePose(
      idle,
      seconds: bob,
      size: size,
      turnSeconds: turnSeconds,
    );
    final lift = wait.dy - hop * size * 0.08;

    Widget mascot = Transform.translate(
      offset: Offset(arrive.dx + wait.dx, arrive.dy + lift),
      child: Transform.scale(
        scale: arrive.scale,
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
    // A lean lives inside the idle and is back at zero when it ends.
    if (wait.angle != 0) {
      mascot = Transform.rotate(
        angle: wait.angle,
        alignment: Alignment.bottomCenter,
        child: mascot,
      );
    }
    if (arrive.opacity < 1) {
      mascot = Opacity(opacity: arrive.opacity, child: mascot);
    }
    return mascot;
  }
}

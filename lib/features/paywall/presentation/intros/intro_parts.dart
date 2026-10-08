import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_intro.dart';
import 'package:flutter/material.dart';

// The parts every intro draws its mascot and its one line with, so each
// intro's own file is only its joke.

/// One face on the way to another, as an intro's timeline says it.
typedef IntroFaceBlend = ({FaceState from, FaceState to, double blend});

/// The face [face] says, held upright and in place, with the eyes [blink]
/// shut. A lean in an intro is the motion's,
/// never the face's own.
FaceShape introFaceShape(IntroFaceBlend face, {double blink = 0}) {
  final shape = FaceShape.lerp(
    faceFor(face.from),
    faceFor(face.to),
    Curves.easeInOutCubic.transform(face.blend.clamp(0, 1).toDouble()),
  );
  final upright = FaceShape(
    leftEye: shape.leftEye,
    rightEye: shape.rightEye,
    mouth: shape.mouth,
    leftBrow: shape.leftBrow,
    rightBrow: shape.rightBrow,
    head: shape.head,
    props: shape.props,
  );
  if (blink <= 0) return upright;
  return FaceShape.lerp(
    upright,
    upright.blinking,
    blink.clamp(0, 1).toDouble(),
  );
}

/// Where an intro stands its mascot and its line on a screen of [size]
/// with the status bar [top] points tall.
({Rect face, Rect word, double wordSize}) introStageFor(Size size, double top) {
  final edge = (size.width * 0.52).clamp(0, size.height * 0.26).toDouble();
  final centre = Offset(size.width / 2, top + (size.height - top) * 0.34);
  final wordSize = (size.width * 0.21).clamp(0, 84).toDouble();
  return (
    face: Rect.fromCenter(center: centre, width: edge, height: edge),
    word: Rect.fromLTWH(
      Spacing.s5,
      centre.dy + edge / 2 + Spacing.s6,
      size.width - 2 * Spacing.s5,
      wordSize * 1.1,
    ),
    wordSize: wordSize,
  );
}

/// The intro's mascot. A direct child of the intro's `Stack`.
///
/// It stands in [box]. As [leave] goes from 0 to 1 it travels to where the
/// layout's own mascot stands and shrinks to nothing there, so it is gone
/// by the hand over and the layout's comes up in its place.
class IntroCrit extends StatelessWidget {
  const IntroCrit({
    required this.box,
    required this.shape,
    required this.scope,
    this.leave = 0,
    this.scale = 1,
    this.angle = 0,
    this.offset = Offset.zero,
    super.key,
  });

  final Rect box;
  final FaceShape shape;
  final PaywallIntroScope scope;

  /// How far out it is, 0 to 1. See `paywallIntroLeaveBox`.
  final double leave;

  /// The joke's own moves, about the middle of [box]. Each ends at rest:
  /// one, zero and nothing.
  final double scale;
  final double angle;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    final at = paywallIntroLeaveBox(
      from: box,
      landing: scope.landing,
      leave: leave,
    );
    return Positioned(
      left: at.left,
      top: at.top,
      child: Transform.scale(
        scale: at.width / box.width,
        alignment: Alignment.topLeft,
        child: Transform.translate(
          offset: offset,
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(
              scale: scale,
              child: FaceWidget(
                state: FaceState.happy,
                shape: shape,
                size: box.width,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one line an intro says, in [box], on one line however long it is.
/// A direct child of the intro's `Stack`.
class IntroWord extends StatelessWidget {
  const IntroWord({
    required this.text,
    required this.box,
    required this.style,
    this.opacity = 1,
    this.scale = 1,
    super.key,
  });

  final String text;
  final Rect box;
  final TextStyle style;
  final double opacity;
  final double scale;

  @override
  Widget build(BuildContext context) => Positioned.fromRect(
    rect: box,
    child: Opacity(
      opacity: opacity.clamp(0, 1).toDouble(),
      child: Transform.scale(
        scale: scale,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
            style: style,
          ),
        ),
      ),
    ),
  );
}

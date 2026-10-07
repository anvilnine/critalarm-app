import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/hero/hero_loop.dart';
import 'package:flutter/widgets.dart';

// The shapes behind the Hero layout's faces. All but one are the face
// rig's own. The watching face is built here from the rig's parts, because
// the mascot has to look at the card, which sits down and to its right.

EyeShape _watchingEye(Offset at) => EyeShape(
  centre: at,
  ballRadius: 20,
  pupilRadius: 9.5,
  pupilOffset: const Offset(7, 5),
  lidPoints: restingLid(at),
);

/// Eyes on the card, with a small smile.
final FaceShape heroWatchingFace = FaceShape(
  leftEye: _watchingEye(const Offset(74, 92)),
  rightEye: _watchingEye(const Offset(126, 92)),
  mouth: MouthShape(
    curveMouth(
      const Offset(80, 132),
      const Offset(100, 146),
      const Offset(120, 132),
    ),
  ),
);

/// The shape of [face].
FaceShape heroFaceShape(HeroFace face) => switch (face) {
  HeroFace.arriving => faceFor(FaceState.surprised),
  HeroFace.glad => faceFor(FaceState.happy),
  HeroFace.watching => heroWatchingFace,
  HeroFace.doubtful => faceFor(FaceState.skeptical),
  HeroFace.keen => faceFor(FaceState.interested),
  HeroFace.thinking => faceFor(FaceState.thinking),
  HeroFace.startled => faceFor(FaceState.wakesUp),
  HeroFace.winning => faceFor(FaceState.success),
  HeroFace.proud => faceFor(FaceState.proud),
  HeroFace.winking => faceFor(FaceState.cheeky),
  HeroFace.cool => faceFor(FaceState.confident),
  HeroFace.relieved => faceFor(FaceState.breatheOut),
  HeroFace.listening => faceFor(FaceState.content),
  HeroFace.loving => faceFor(FaceState.love),
};

/// The shape on the mascot at [frame]: one face on its way to the next,
/// with the eyes shut as far as the blink says.
FaceShape heroShapeAt(HeroFrame frame) {
  final blend = Curves.easeInOutCubic.transform(frame.faceBlend);
  final to = heroFaceShape(frame.face);
  final shape = blend >= 1
      ? to
      : FaceShape.lerp(heroFaceShape(frame.fromFace), to, blend);
  // The stage holds the mascot upright: a face's own lean is left out.
  final upright = FaceShape(
    leftEye: shape.leftEye,
    rightEye: shape.rightEye,
    mouth: shape.mouth,
    leftBrow: shape.leftBrow,
    rightBrow: shape.rightBrow,
    head: shape.head,
    props: shape.props,
  );
  if (frame.blink <= 0) return upright;
  return FaceShape.lerp(upright, upright.blinking, frame.blink);
}

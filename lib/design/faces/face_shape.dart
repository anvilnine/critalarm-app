import 'dart:math' as math;
import 'dart:ui' show Color, Offset;

import 'package:critalarm/design/faces/face_rig.dart';
import 'package:critalarm/design/faces/face_state.dart';

export 'package:critalarm/design/faces/face_rig.dart';

/// The numbers that make up each face.
///
/// The parts themselves, and how they blend, live in `face_rig.dart`. This
/// file is only the poses: where the eyes sit, how the mouth curves, which
/// brows show. Every face in the app comes from here, so two of them can
/// always be mixed.

/// The face [state] rests at.
FaceShape faceFor(FaceState state) => switch (state) {
  FaceState.calm => calmFace,
  FaceState.watching => watchingFace,
  FaceState.working => workingFace,
  FaceState.success => successFace,
  FaceState.skeptical => skepticalFace,
  FaceState.worried => worriedFace,
  FaceState.alarmed => alarmedFace,
  FaceState.acked => ackedFace,
  FaceState.shocked => shockedFace,
  FaceState.laughing => laughingFace,
  FaceState.surprised => surprisedFace,
  FaceState.dizzy => dizzyFace,
  FaceState.determined => determinedFace,
  FaceState.confused => confusedFace,
  FaceState.sad => sadFace,
  FaceState.blink => blinkFace,
  FaceState.happy => happyFace,
  FaceState.content => contentFace,
  FaceState.curious => curiousFace,
  FaceState.lookLeft => lookLeftFace,
  FaceState.lookRight => lookRightFace,
  FaceState.thinking => thinkingFace,
  FaceState.interested => interestedFace,
  FaceState.concerned => concernedFace,
  FaceState.realization => realizationFace,
  FaceState.yawn => yawnFace,
  FaceState.sleepy => sleepyFace,
  FaceState.dozing => dozingFace,
  FaceState.wakesUp => wakesUpFace,
  FaceState.shakeHead => shakeHeadFace,
  FaceState.breatheIn => breatheInFace,
  FaceState.breatheOut => breatheOutFace,
  FaceState.proud => proudFace,
  FaceState.cheeky => cheekyFace,
  FaceState.confident => confidentFace,
  FaceState.love => loveFace,
};

/// The coral an open mouth is painted with unless it names another colour.
const Color mouthCoral = Color(0xFFFA7970);

/// Builds a mouth out of a lower lip and an upper lip, both traced left to
/// right.
///
/// This is the shape of every mouth in the app, and it is what lets a smile
/// turn into a yawn. The points run all the way around: the left corner,
/// along the lower lip, the right corner, then back along the upper lip. A
/// closed mouth gives the same curve for both lips, so the two sit on each
/// other and the mouth reads as shut. Opening it is then the upper lip
/// lifting off the lower one, which is what a mouth actually does.
///
/// Blending two mouths built any other way slides the left of one into the
/// middle of the other, and the mouth folds instead of opening.
List<Offset> lipsMouth(
  Offset Function(double t) lower,
  Offset Function(double t) upper,
) => [
  lower(0),
  for (var i = 1; i <= 5; i++) lower(i / 6),
  lower(1),
  for (var i = 5; i >= 1; i--) upper(i / 6),
  upper(0),
];

/// A closed mouth that follows one curve. Both lips sit on it.
List<Offset> sampleMouth(Offset Function(double t) at) => lipsMouth(at, at);

/// A closed mouth along a straight line from [a] to [b].
List<Offset> lineMouth(Offset a, Offset b) =>
    sampleMouth((t) => Offset.lerp(a, b, t)!);

/// A closed mouth that bends from [a] through [control] to [b].
List<Offset> curveMouth(Offset a, Offset control, Offset b) =>
    sampleMouth((t) => quadAt(a, control, b, t));

/// An open mouth [rx] by [ry] around [centre]. The lower lip is the bottom of
/// the oval and the upper lip is the top, so it opens and shuts properly.
List<Offset> ovalMouth(Offset centre, double rx, double ry) => lipsMouth(
  (t) => _onOval(centre, rx, ry, math.pi - math.pi * t),
  (t) => _onOval(centre, rx, ry, math.pi + math.pi * t),
);

/// An open wedge: a flat upper lip across the top and a lower lip that drops
/// to [tip]. The open smile a delighted face wears.
List<Offset> wedgeMouth(Offset left, Offset tip, Offset right) => lipsMouth(
  (t) => t <= 0.5
      ? Offset.lerp(left, tip, t * 2)!
      : Offset.lerp(tip, right, (t - 0.5) * 2)!,
  (t) => Offset.lerp(left, right, t)!,
);

Offset _onOval(Offset centre, double rx, double ry, double angle) =>
    centre + Offset(rx * math.cos(angle), ry * math.sin(angle));

/// A point [t] of the way along the curve from [p0] through [p1] to [p2].
Offset quadAt(Offset p0, Offset p1, Offset p2, double t) =>
    p0 * ((1 - t) * (1 - t)) + p1 * (2 * (1 - t) * t) + p2 * (t * t);

/// A shut lid that arches gently over an eye centred on [centre]: the resting
/// closed eye, and what a blink lands on.
List<Offset> restingLid(Offset centre) => [
  centre + const Offset(-13, 0),
  centre + const Offset(0, -4),
  centre + const Offset(13, 0),
];

/// A shut lid that droops, for a sleepy or contented face.
List<Offset> droopingLid(Offset centre) => [
  centre + const Offset(-13, -3),
  centre + const Offset(0, 4),
  centre + const Offset(13, -3),
];

// ---------------------------------------------------------------------------
// The faces.
// ---------------------------------------------------------------------------

/// All clear. Dark dot eyes with a small shine, and an easy smile.
final FaceShape calmFace = FaceShape(
  leftEye: EyeShape(
    centre: const Offset(70, 90),
    shineRadius: 3.5,
    shineOffset: const Offset(-3.5, -4),
    lidPoints: restingLid(const Offset(70, 90)),
  ),
  rightEye: EyeShape(
    centre: const Offset(130, 90),
    shineRadius: 3.5,
    shineOffset: const Offset(-3.5, -4),
    lidPoints: restingLid(const Offset(130, 90)),
  ),
  mouth: MouthShape(
    curveMouth(
      const Offset(70, 128),
      const Offset(100, 148),
      const Offset(130, 128),
    ),
  ),
);

/// Waiting on something. White eyes held level under one raised brow, and a
/// mouth kept flat. The pupils sit in the middle so the live drift reads as
/// looking around rather than rolling its eyes.
final FaceShape watchingFace = FaceShape(
  leftEye: EyeShape(
    centre: const Offset(74, 94),
    ballRadius: 19,
    pupilRadius: 9.5,
    lidPoints: restingLid(const Offset(74, 94)),
  ),
  rightEye: EyeShape(
    centre: const Offset(128, 94),
    ballRadius: 19,
    pupilRadius: 9.5,
    lidPoints: restingLid(const Offset(128, 94)),
  ),
  leftBrow: const BrowShape([
    Offset(56, 68),
    Offset(70.5, 62),
    Offset(86, 64),
  ]),
  mouth: MouthShape(lineMouth(const Offset(84, 134), const Offset(118, 134))),
);

/// Refreshing. Eyes squeezed into `> <` and a mouth wavering through it.
final FaceShape workingFace = FaceShape(
  leftEye: const EyeShape(
    centre: Offset(68, 90),
    lid: 1,
    lidPoints: [Offset(58, 80), Offset(78, 90), Offset(58, 100)],
  ),
  rightEye: const EyeShape(
    centre: Offset(132, 90),
    lid: 1,
    lidPoints: [Offset(142, 80), Offset(122, 90), Offset(142, 100)],
  ),
  // 1.5 waves, 6 units tall, around y 134.
  mouth: MouthShape(
    sampleMouth(
      (t) => Offset(70 + 60 * t, 134 + 6 * math.sin(3 * math.pi * t)),
    ),
  ),
);

/// A refresh landed. Dot eyes, a small `v` of a smile, lines popping above.
final FaceShape successFace = FaceShape(
  leftEye: EyeShape(
    centre: const Offset(70, 88),
    lidPoints: restingLid(const Offset(70, 88)),
  ),
  rightEye: EyeShape(
    centre: const Offset(130, 88),
    lidPoints: restingLid(const Offset(130, 88)),
  ),
  mouth: MouthShape(
    sampleMouth(
      (t) => t <= 0.5
          ? Offset.lerp(const Offset(88, 128), const Offset(100, 140), t * 2)!
          : Offset.lerp(
              const Offset(100, 140),
              const Offset(112, 128),
              (t - 0.5) * 2,
            )!,
    ),
  ),
  props: const [PropShape(PropKind.popLines, at: Offset(100, 100))],
);

/// Unconvinced. One brow down, one cocked, and a smirk that slants.
final FaceShape skepticalFace = FaceShape(
  leftEye: EyeShape(
    centre: const Offset(68, 94),
    lidPoints: restingLid(const Offset(68, 94)),
  ),
  rightEye: EyeShape(
    centre: const Offset(126, 92),
    lidPoints: restingLid(const Offset(126, 92)),
  ),
  leftBrow: const BrowShape([Offset(46, 70), Offset(66, 74), Offset(86, 74)]),
  rightBrow: const BrowShape([
    Offset(110, 66),
    Offset(127.5, 52),
    Offset(148, 58),
  ]),
  mouth: MouthShape(lineMouth(const Offset(72, 146), const Offset(126, 138))),
);

/// Something looks wrong. Brows pinched up, dot eyes, a wavering mouth.
final FaceShape worriedFace = FaceShape(
  leftEye: EyeShape(
    centre: const Offset(70, 92),
    lidPoints: restingLid(const Offset(70, 92)),
  ),
  rightEye: EyeShape(
    centre: const Offset(130, 92),
    lidPoints: restingLid(const Offset(130, 92)),
  ),
  leftBrow: const BrowShape([Offset(54, 70), Offset(69, 64), Offset(84, 58)]),
  rightBrow: const BrowShape([
    Offset(116, 58),
    Offset(131, 64),
    Offset(146, 70),
  ]),
  mouth: MouthShape(
    sampleMouth(
      (t) => t <= 0.5
          ? quadAt(
              const Offset(72, 138),
              const Offset(86, 124),
              const Offset(100, 138),
              t * 2,
            )
          : quadAt(
              const Offset(100, 138),
              const Offset(114, 152),
              const Offset(128, 138),
              (t - 0.5) * 2,
            ),
    ),
  ),
);

/// The alarm is ringing. A heavier outline, brows slammed down, ringed eyes
/// and a mouth open mid shout.
final FaceShape alarmedFace = FaceShape(
  leftEye: EyeShape(
    centre: const Offset(70, 94),
    ballRadius: 17,
    ballWidth: 11,
    ballIsHead: true,
    pupilRadius: 6,
    lidPoints: restingLid(const Offset(70, 94)),
    lidWidth: 11,
  ),
  rightEye: EyeShape(
    centre: const Offset(130, 94),
    ballRadius: 17,
    ballWidth: 11,
    ballIsHead: true,
    pupilRadius: 6,
    lidPoints: restingLid(const Offset(130, 94)),
    lidWidth: 11,
  ),
  leftBrow: const BrowShape([
    Offset(50, 58),
    Offset(67, 63),
    Offset(84, 68),
  ], width: 11),
  rightBrow: const BrowShape([
    Offset(116, 68),
    Offset(133, 63),
    Offset(150, 58),
  ], width: 11),
  mouth: MouthShape(
    ovalMouth(const Offset(100, 142), 17, 22),
    width: 11,
    fill: 1,
    fillsWithInk: true,
  ),
  head: const HeadShape(strokeWidth: 12),
);

/// Someone answered. Both eyes shut into happy arches over a soft smile.
final FaceShape ackedFace = FaceShape(
  leftEye: const EyeShape(
    centre: Offset(70, 90),
    lid: 1,
    lidPoints: [Offset(56, 94), Offset(70, 86), Offset(84, 94)],
  ),
  rightEye: const EyeShape(
    centre: Offset(130, 90),
    lid: 1,
    lidPoints: [Offset(116, 94), Offset(130, 86), Offset(144, 94)],
  ),
  mouth: MouthShape(
    curveMouth(
      const Offset(76, 128),
      const Offset(100, 146),
      const Offset(124, 128),
    ),
  ),
);

/// Caught off guard and not happy about it. Huge white eyes, brows driven
/// down, and a scream.
final FaceShape shockedFace = FaceShape(
  leftEye: EyeShape(
    centre: const Offset(68, 102),
    ballRadius: 21,
    pupilRadius: 10.5,
    shineRadius: 3.5,
    shineOffset: const Offset(-4, -4),
    lidPoints: restingLid(const Offset(68, 102)),
    lidWidth: 11,
  ),
  rightEye: EyeShape(
    centre: const Offset(132, 102),
    ballRadius: 21,
    pupilRadius: 10.5,
    shineRadius: 3.5,
    shineOffset: const Offset(-4, -4),
    lidPoints: restingLid(const Offset(132, 102)),
    lidWidth: 11,
  ),
  leftBrow: const BrowShape([
    Offset(46, 62),
    Offset(67, 71),
    Offset(88, 80),
  ], width: 11),
  rightBrow: const BrowShape([
    Offset(112, 80),
    Offset(133, 71),
    Offset(154, 62),
  ], width: 11),
  mouth: MouthShape(
    ovalMouth(const Offset(100, 149), 24, 21),
    width: 11,
    fill: 1,
  ),
  head: const HeadShape(strokeWidth: 12),
);

/// Delighted. Eyes squeezed shut and a laugh that takes up half the face.
final FaceShape laughingFace = FaceShape(
  leftEye: const EyeShape(
    centre: Offset(65, 90),
    lid: 1,
    lidPoints: [Offset(48, 74), Offset(82, 90), Offset(48, 106)],
    lidWidth: 11,
  ),
  rightEye: const EyeShape(
    centre: Offset(135, 90),
    lid: 1,
    lidPoints: [Offset(152, 74), Offset(118, 90), Offset(152, 106)],
    lidWidth: 11,
  ),
  mouth: MouthShape(
    ovalMouth(const Offset(100, 145.5), 48, 22.5),
    width: 11,
    fill: 1,
  ),
);

/// Did not see that coming. Brows up, big glossy eyes, a round open mouth.
final FaceShape surprisedFace = FaceShape(
  leftEye: EyeShape(
    centre: const Offset(68, 92),
    pupilRadius: 21,
    shineRadius: 7.5,
    shineOffset: const Offset(7, -8),
    lidPoints: restingLid(const Offset(68, 92)),
  ),
  rightEye: EyeShape(
    centre: const Offset(132, 92),
    pupilRadius: 21,
    shineRadius: 7.5,
    shineOffset: const Offset(7, -8),
    lidPoints: restingLid(const Offset(132, 92)),
  ),
  leftBrow: const BrowShape([Offset(44, 58), Offset(63, 43.5), Offset(84, 48)]),
  rightBrow: const BrowShape([
    Offset(116, 48),
    Offset(137, 43.5),
    Offset(156, 58),
  ]),
  mouth: MouthShape(
    ovalMouth(const Offset(100, 144), 14, 14),
    fill: 1,
    fillsWithInk: true,
  ),
);

/// Lost the thread. Swirls where the eyes should be and a mouth that wobbles.
final FaceShape dizzyFace = FaceShape(
  leftEye: EyeShape(
    centre: const Offset(72, 94),
    pupilRadius: 19,
    spiral: 1,
    lidPoints: restingLid(const Offset(72, 94)),
  ),
  rightEye: EyeShape(
    centre: const Offset(128, 94),
    pupilRadius: 19,
    spiral: 1,
    lidPoints: restingLid(const Offset(128, 94)),
  ),
  leftBrow: const BrowShape([Offset(50, 66), Offset(68, 52), Offset(82, 58)]),
  rightBrow: const BrowShape([
    Offset(118, 58),
    Offset(132, 52),
    Offset(150, 66),
  ]),
  // Three humps, 7 units deep, running from x 68 to x 132 around y 146.
  mouth: MouthShape(
    sampleMouth(
      (t) => Offset(68 + 64 * t, 146 + 7 * math.sin(3.2 * math.pi * t)),
    ),
    width: 9,
  ),
);

/// Ready for it. Brows in a hard V, bright eyes, and a mouth mid shout.
final FaceShape determinedFace = FaceShape(
  leftEye: EyeShape(
    centre: const Offset(70, 92),
    ballRadius: 20,
    pupilRadius: 14,
    pupilOffset: const Offset(0, 2),
    shineRadius: 5.5,
    shineOffset: const Offset(4, -8),
    lidPoints: restingLid(const Offset(70, 92)),
    lidWidth: 11,
  ),
  rightEye: EyeShape(
    centre: const Offset(130, 92),
    ballRadius: 20,
    pupilRadius: 14,
    pupilOffset: const Offset(0, 2),
    shineRadius: 5.5,
    shineOffset: const Offset(4, -8),
    lidPoints: restingLid(const Offset(130, 92)),
    lidWidth: 11,
  ),
  leftBrow: const BrowShape([
    Offset(54, 46),
    Offset(71, 58),
    Offset(88, 70),
  ], width: 11),
  rightBrow: const BrowShape([
    Offset(112, 70),
    Offset(129, 58),
    Offset(146, 46),
  ], width: 11),
  mouth: MouthShape(
    ovalMouth(const Offset(100, 145), 17, 13),
    width: 11,
    fill: 1,
  ),
);

/// Not following. One brow up, one flat, eyes at different heights, and a
/// mouth held on a slant.
final FaceShape confusedFace = FaceShape(
  leftEye: EyeShape(
    centre: const Offset(74, 98),
    lidPoints: restingLid(const Offset(74, 98)),
  ),
  rightEye: EyeShape(
    centre: const Offset(126, 92),
    lidPoints: restingLid(const Offset(126, 92)),
  ),
  leftBrow: const BrowShape([Offset(44, 76), Offset(62.5, 63), Offset(82, 68)]),
  rightBrow: const BrowShape([
    Offset(122, 68),
    Offset(135.5, 70),
    Offset(148, 76),
  ]),
  mouth: MouthShape(lineMouth(const Offset(78, 142), const Offset(126, 134))),
);

/// Down about it. Brows drooping at the outside corners and a frown.
final FaceShape sadFace = FaceShape(
  leftEye: EyeShape(
    centre: const Offset(70, 98),
    lidPoints: restingLid(const Offset(70, 98)),
  ),
  rightEye: EyeShape(
    centre: const Offset(130, 98),
    lidPoints: restingLid(const Offset(130, 98)),
  ),
  leftBrow: const BrowShape([Offset(44, 86), Offset(61.5, 70), Offset(82, 66)]),
  rightBrow: const BrowShape([
    Offset(118, 66),
    Offset(138.5, 70),
    Offset(156, 86),
  ]),
  mouth: MouthShape(
    curveMouth(
      const Offset(66, 150),
      const Offset(100, 126),
      const Offset(134, 150),
    ),
  ),
);

// ---------------------------------------------------------------------------
// The faces from the expression sheets. Shared numbers first, so the whole
// set sits on the same grid and nothing drifts by a pixel or two.
// ---------------------------------------------------------------------------

/// Where a wide open eye sits on the left.
const Offset _openLeft = Offset(74, 92);

/// And on the right.
const Offset _openRight = Offset(126, 92);

/// How big a wide open eye is.
const double _ball = 20;

/// The pupil inside one.
const double _pupil = 9.5;

/// A wide open eye at [at], looking [look] away from the middle.
EyeShape _open(Offset at, {Offset look = Offset.zero, double ball = _ball}) =>
    EyeShape(
      centre: at,
      ballRadius: ball,
      pupilRadius: _pupil,
      pupilOffset: look,
      lidPoints: restingLid(at),
    );

/// A shut eye that arches up, the way a face closes its eyes to smile.
EyeShape _smiling(Offset at, {double depth = 7}) => EyeShape(
  centre: at,
  lid: 1,
  lidPoints: [
    at + const Offset(-14, 4),
    at + Offset(0, -depth),
    at + const Offset(14, 4),
  ],
);

/// A shut eye that sags, the way a tired face closes its eyes.
EyeShape _sagging(Offset at, {double depth = 6}) => EyeShape(
  centre: at,
  lid: 1,
  lidPoints: [
    at + const Offset(-14, -3),
    at + Offset(0, depth),
    at + const Offset(14, -3),
  ],
);

/// A brow lifted above an eye at [x], [height] units off its resting line.
BrowShape _raised(double x, {double height = 10, double lean = 0}) =>
    BrowShape([
      Offset(x - 16, 70 - height + lean),
      Offset(x, 64 - height),
      Offset(x + 16, 70 - height - lean),
    ]);

/// A brow pushed down over an eye at [x].
BrowShape _lowered(double x, {double lean = 0}) => BrowShape([
  Offset(x - 16, 72 + lean),
  Offset(x, 74),
  Offset(x + 16, 72 - lean),
]);

/// A round open mouth [rx] by [ry] centred on [at], filled dark.
MouthShape _darkO(Offset at, double rx, double ry) =>
    MouthShape(ovalMouth(at, rx, ry), fill: 1, fillsWithInk: true);

/// The same, filled with the tongue colour.
MouthShape _openO(Offset at, double rx, double ry) =>
    MouthShape(ovalMouth(at, rx, ry), fill: 1);

/// A closed smile [width] wide, [depth] deep, centred on [at].
MouthShape _smile(Offset at, {double width = 30, double depth = 10}) =>
    MouthShape(
      curveMouth(
        at + Offset(-width, 0),
        at + Offset(0, depth * 2),
        at + Offset(width, 0),
      ),
    );

// ---------------------------------------------------------------------------

/// Mid blink. The calm face with its eyes shut and nothing else moved.
final FaceShape blinkFace = calmFace.blinking;

/// Delighted. Eyes shut into two happy arches over a dark open smile.
final FaceShape happyFace = FaceShape(
  leftEye: _smiling(const Offset(70, 92), depth: 9),
  rightEye: _smiling(const Offset(130, 92), depth: 9),
  mouth: MouthShape(
    wedgeMouth(
      const Offset(83, 127),
      const Offset(100, 151),
      const Offset(117, 127),
    ),
    fill: 1,
    fillsWithInk: true,
  ),
);

/// Relaxed. Eyes rested shut, with a small easy smile under them.
final FaceShape contentFace = FaceShape(
  leftEye: _smiling(const Offset(70, 94), depth: 6),
  rightEye: _smiling(const Offset(130, 94), depth: 6),
  mouth: _smile(const Offset(100, 130), width: 22, depth: 7),
);

/// Interested in something off to one side. Both brows up, eyes gone with
/// them, and a small smile that says it likes what it found.
final FaceShape curiousFace = FaceShape(
  leftEye: _open(_openLeft, look: const Offset(5, -6)),
  rightEye: _open(_openRight, look: const Offset(5, -6)),
  leftBrow: _raised(70, height: 8),
  rightBrow: _raised(130, height: 8),
  mouth: _smile(const Offset(100, 132), width: 20, depth: 7),
);

/// Something caught its eye on the left.
final FaceShape lookLeftFace = FaceShape(
  leftEye: _open(_openLeft, look: const Offset(-8, 0)),
  rightEye: _open(_openRight, look: const Offset(-8, 0)),
  mouth: MouthShape(lineMouth(const Offset(82, 136), const Offset(118, 136))),
);

/// And the same, on the right.
final FaceShape lookRightFace = FaceShape(
  leftEye: _open(_openLeft, look: const Offset(8, 0)),
  rightEye: _open(_openRight, look: const Offset(8, 0)),
  mouth: MouthShape(lineMouth(const Offset(82, 136), const Offset(118, 136))),
);

/// Working something out. One brow down, one cocked, eyes up and away, and
/// a mouth gone flat while it thinks.
final FaceShape thinkingFace = FaceShape(
  leftEye: _open(const Offset(72, 94), look: const Offset(6, -7)),
  rightEye: _open(const Offset(126, 92), look: const Offset(6, -7)),
  leftBrow: _lowered(68, lean: -2),
  rightBrow: _raised(130, height: 14, lean: 3),
  mouth: MouthShape(lineMouth(const Offset(78, 142), const Offset(112, 138))),
);

/// Leaning in. Wide eyes, both brows up, mouth open on a small "ooh".
final FaceShape interestedFace = FaceShape(
  leftEye: _open(_openLeft, ball: 21),
  rightEye: _open(_openRight, ball: 21),
  leftBrow: _raised(70, height: 12),
  rightBrow: _raised(130, height: 12),
  mouth: _darkO(const Offset(100, 142), 11, 11),
);

/// Not sure about this. Brows tipped in, eyes dropped, mouth turned down.
final FaceShape concernedFace = FaceShape(
  leftEye: _open(const Offset(74, 94), look: const Offset(0, 4), ball: 18),
  rightEye: _open(const Offset(126, 94), look: const Offset(0, 4), ball: 18),
  leftBrow: const BrowShape([
    Offset(54, 68),
    Offset(70, 63),
    Offset(88, 66),
  ]),
  rightBrow: const BrowShape([
    Offset(112, 66),
    Offset(130, 63),
    Offset(146, 68),
  ]),
  mouth: MouthShape(
    curveMouth(
      const Offset(80, 146),
      const Offset(100, 132),
      const Offset(120, 146),
    ),
  ),
);

/// It just clicked. Eyes wide, brows up, a small round mouth and lines
/// popping off the top of the head.
final FaceShape realizationFace = FaceShape(
  leftEye: _open(_openLeft),
  rightEye: _open(_openRight),
  leftBrow: _raised(70, height: 13),
  rightBrow: _raised(130, height: 13),
  mouth: _darkO(const Offset(100, 143), 9, 10),
  props: const [PropShape(PropKind.popLines, at: Offset(100, 100))],
);

/// Mid yawn. Eyes squeezed shut and the mouth stretched as wide as it goes.
final FaceShape yawnFace = FaceShape(
  leftEye: _sagging(const Offset(70, 88), depth: 8),
  rightEye: _sagging(const Offset(130, 88), depth: 8),
  mouth: _openO(const Offset(100, 145), 21, 25),
  head: const HeadShape(squashX: 0.97, squashY: 1.04),
);

/// Getting sleepy. Lids sagging, mouth small and pursed.
final FaceShape sleepyFace = FaceShape(
  leftEye: _sagging(const Offset(70, 94)),
  rightEye: _sagging(const Offset(130, 94)),
  mouth: _openO(const Offset(100, 138), 7, 8),
);

/// Gone. Eyes shut, a small round mouth, and Zzz drifting off the corner.
final FaceShape dozingFace = FaceShape(
  leftEye: _sagging(const Offset(70, 96)),
  rightEye: _sagging(const Offset(130, 96)),
  mouth: _openO(const Offset(104, 140), 7, 8),
  props: const [PropShape(PropKind.zzz, at: Offset(150, 34))],
  tilt: 0.06,
);

/// Caught out. Eyes snapped open, brows up, mouth caught on an "ah".
final FaceShape wakesUpFace = FaceShape(
  leftEye: _open(_openLeft, ball: 21),
  rightEye: _open(_openRight, ball: 21),
  leftBrow: _raised(70, height: 14),
  rightBrow: _raised(130, height: 14),
  mouth: _openO(const Offset(100, 144), 9, 10),
  props: const [PropShape(PropKind.popLines, at: Offset(100, 100))],
);

/// Shaking it off. Eyes screwed shut, mouth wavering, head thrown over with
/// a line either side to say it is moving.
final FaceShape shakeHeadFace = FaceShape(
  leftEye: const EyeShape(
    centre: Offset(68, 90),
    lid: 1,
    lidPoints: [Offset(56, 80), Offset(76, 90), Offset(56, 100)],
  ),
  rightEye: const EyeShape(
    centre: Offset(132, 90),
    lid: 1,
    lidPoints: [Offset(144, 80), Offset(124, 90), Offset(144, 100)],
  ),
  mouth: MouthShape(
    sampleMouth(
      (t) => Offset(74 + 52 * t, 138 + 5 * math.sin(3 * math.pi * t)),
    ),
  ),
  props: const [PropShape(PropKind.motionArcs, at: Offset(100, 100))],
  tilt: 0.09,
);

/// Drawing a breath in. Eyes closed, mouth open on the inhale, and the head
/// filled out a little.
final FaceShape breatheInFace = FaceShape(
  leftEye: _sagging(const Offset(70, 94)),
  rightEye: _sagging(const Offset(130, 94)),
  mouth: _openO(const Offset(100, 140), 8, 9),
  head: const HeadShape(squashX: 1.04, squashY: 1.04),
);

/// Letting it out. The head settles back and a puff leaves the mouth.
final FaceShape breatheOutFace = FaceShape(
  leftEye: _sagging(const Offset(72, 94)),
  rightEye: _sagging(const Offset(132, 94)),
  mouth: _openO(const Offset(114, 142), 8, 8),
  props: const [PropShape(PropKind.puff, at: Offset(178, 148), scale: 1.4)],
  head: const HeadShape(squashX: 0.96, squashY: 0.96),
  tilt: 0.05,
);

/// Pleased with itself. Brows up, eyes up and away, small private smile.
final FaceShape proudFace = FaceShape(
  leftEye: _open(const Offset(74, 94), look: const Offset(0, -6), ball: 18),
  rightEye: _open(const Offset(126, 94), look: const Offset(0, -6), ball: 18),
  leftBrow: _raised(70, height: 9),
  rightBrow: _raised(130, height: 9),
  mouth: _smile(const Offset(100, 132), width: 18, depth: 6),
);

/// Winking. One eye shut, the other wide, and a smirk pulled to one side.
final FaceShape cheekyFace = FaceShape(
  leftEye: _open(const Offset(74, 92), ball: 19),
  rightEye: const EyeShape(
    centre: Offset(128, 92),
    lid: 1,
    lidPoints: [Offset(140, 82), Offset(120, 92), Offset(140, 102)],
  ),
  mouth: MouthShape(
    curveMouth(
      const Offset(76, 136),
      const Offset(100, 152),
      const Offset(122, 130),
    ),
  ),
);

/// Sure of itself. Brows level and low, eyes to one side, half a smile.
final FaceShape confidentFace = FaceShape(
  leftEye: _open(const Offset(74, 94), look: const Offset(6, -2), ball: 17),
  rightEye: _open(const Offset(126, 94), look: const Offset(6, -2), ball: 17),
  leftBrow: const BrowShape([
    Offset(54, 70),
    Offset(72, 72),
    Offset(90, 70),
  ]),
  rightBrow: const BrowShape([
    Offset(110, 70),
    Offset(128, 72),
    Offset(146, 70),
  ]),
  mouth: MouthShape(
    curveMouth(
      const Offset(76, 138),
      const Offset(100, 150),
      const Offset(124, 132),
    ),
  ),
);

/// Likes this. The calm face with a heart floating off the top corner.
final FaceShape loveFace = FaceShape(
  leftEye: EyeShape(
    centre: const Offset(70, 90),
    shineRadius: 3.5,
    shineOffset: const Offset(-3.5, -4),
    lidPoints: restingLid(const Offset(70, 90)),
  ),
  rightEye: EyeShape(
    centre: const Offset(130, 90),
    shineRadius: 3.5,
    shineOffset: const Offset(-3.5, -4),
    lidPoints: restingLid(const Offset(130, 90)),
  ),
  mouth: _smile(const Offset(100, 130), width: 26, depth: 9),
  props: const [PropShape(PropKind.heart, at: Offset(166, 26), scale: 1.7)],
);

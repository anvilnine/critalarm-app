import 'dart:math' as math;

import 'package:critalarm/design/tokens/curves.dart';
import 'package:flutter/animation.dart';

// The first welcome page: "Welcome to Crit Alarm" drops in, the red block
// grows behind "Alarm", its letters shake, and the face leans in and shouts.
//
// Everything here is a pure function of the clock. The widget only paints the
// frame. Lengths are in "design units": points at the 84 point type size the
// picture is drawn for. The widget scales them to the size it uses.

/// How long one pass of the story takes, in seconds. The drop-in plays once,
/// then the block, the shake, the face and the rings repeat every pass.
const double welcomeWordLoopSeconds = 7;

/// How long one line takes to drop into place.
const double welcomeWordDropSeconds = 0.7;

/// How much later each line starts dropping than the one above it.
const double welcomeWordLineStaggerSeconds = 0.12;

/// How far above its place a line starts, in design units.
const double welcomeWordDropFrom = 60;

/// How much later each letter of the last word starts shaking.
const double welcomeWordLetterStaggerSeconds = 0.04;

/// How many letters the frame holds for the last word.
const int welcomeWordLetterCount = 5;

/// How many lines the title has.
const int welcomeWordLineCount = 3;

/// How many rings pulse out from behind the face.
const int welcomeWordRingCount = 3;

/// How long one ring takes to grow and fade.
const double welcomeWordRingSeconds = 1.4;

/// How much later each ring starts than the one before it.
const double welcomeWordRingStaggerSeconds = 0.45;

/// The loop fractions of the block: it starts growing at the first, is full
/// at the second, starts to shrink at the third and is gone at the fourth.
const double welcomeWordBlockGrowsFrom = 0.38;
const double welcomeWordBlockFullAt = 0.46;
const double welcomeWordBlockShrinksFrom = 0.86;
const double welcomeWordBlockGoneAt = 0.94;

/// The loop fraction the letters start to shake at.
const double welcomeWordShakeFrom = 0.48;

/// The loop fraction the letters are still again by, before the stagger.
const double welcomeWordShakeTo = 0.80;

/// When the block has landed, on the story's clock. The one haptic plays here.
const double welcomeWordBlockLandsAt =
    welcomeWordBlockFullAt * welcomeWordLoopSeconds;

/// The most a letter lifts while it shakes, and how far it dips, in design
/// units. The turn is in radians.
const double welcomeWordShakeLift = 5;
const double welcomeWordShakeDip = 3;
const double welcomeWordShakeTurn = 5 * math.pi / 180;

/// Where the face is, as a sideways shift in design units. The out position
/// leaves a strip of it at the right edge of the screen and the in position
/// brings all of it in.
const double welcomeWordFaceOut = 70;
const double welcomeWordFaceIn = -30;

/// The turn of the face when it is out and when it is in, in radians.
const double welcomeWordFaceOutTurn = 8 * math.pi / 180;
const double welcomeWordFaceInTurn = -6 * math.pi / 180;

/// The type size of the picture at its full width, in points.
const double welcomeWordMaxFontSize = 84;

/// The type size for a picture [width] points wide: a fixed share of the
/// width, so "Welcome" fits on a 320 point wide phone, and 84 at most.
double welcomeWordFontSize(double width) =>
    math.min(welcomeWordMaxFontSize, width * 0.215);

/// One line of the title.
class WelcomeWordLine {
  const WelcomeWordLine({required this.offset, required this.opacity});

  /// How far below its place the line is, in design units. Negative while
  /// it is still above.
  final double offset;
  final double opacity;
}

/// One letter of the last word.
class WelcomeWordLetter {
  const WelcomeWordLetter({required this.offset, required this.turn});

  /// How far below its place the letter is, in design units. Up is negative.
  final double offset;

  /// Clockwise is positive, in radians.
  final double turn;
}

/// One ring behind the face.
class WelcomeWordRing {
  const WelcomeWordRing({required this.scale, required this.opacity});

  /// 1 is the size of the ring at rest.
  final double scale;
  final double opacity;
}

/// The face.
class WelcomeWordFace {
  const WelcomeWordFace({
    required this.shift,
    required this.turn,
    required this.shout,
  });

  /// Sideways shift in design units, [welcomeWordFaceOut] to
  /// [welcomeWordFaceIn].
  final double shift;

  /// Clockwise is positive, in radians.
  final double turn;

  /// 0 is the calm face and 1 is the shouting one.
  final double shout;
}

/// Everything on the page at one moment.
class WelcomeWordFrame {
  const WelcomeWordFrame({
    required this.lines,
    required this.blockScale,
    required this.letters,
    required this.rings,
    required this.face,
  });

  /// The three lines of the title, top to bottom.
  final List<WelcomeWordLine> lines;

  /// How much of the red block behind the last word is drawn, left to right:
  /// 0 to 1.
  final double blockScale;

  /// The letters of the last word, left to right.
  final List<WelcomeWordLetter> letters;

  /// The rings, oldest first.
  final List<WelcomeWordRing> rings;
  final WelcomeWordFace face;
}

/// A value that moves through [stops], one after another. Each stop is a
/// loop fraction and the value there. Between two stops the value follows
/// [curve].
double _through(
  double fraction,
  List<(double, double)> stops, {
  Curve curve = Curves.linear,
}) {
  if (fraction <= stops.first.$1) return stops.first.$2;
  for (var i = 1; i < stops.length; i++) {
    final (to, toValue) = stops[i];
    if (fraction <= to) {
      final (from, fromValue) = stops[i - 1];
      final progress = (fraction - from) / (to - from);
      return fromValue + (toValue - fromValue) * curve.transform(progress);
    }
  }
  return stops.last.$2;
}

/// How far the block is up, 0 to 1, at loop fraction [p].
double _blockAt(double p) => _through(
  p,
  const [
    (0, 0),
    (welcomeWordBlockGrowsFrom, 0),
    (welcomeWordBlockFullAt, 1),
    (welcomeWordBlockShrinksFrom, 1),
    (welcomeWordBlockGoneAt, 0),
    (1, 0),
  ],
  curve: AppCurves.passGrow,
);

/// How hot the page is, 0 to 1: the shout face and the rings are here while
/// the block is up.
double _heatAt(double p) => _through(p, const [
  (0, 0),
  (0.44, 0),
  (0.47, 1),
  (0.86, 1),
  (0.92, 0),
  (1, 0),
]);

/// The beats of a shake: the loop fraction and whether the letter is lifted
/// (true) or dipped (false) there. The letter is still before the first beat
/// and after the last, and eases from and to rest over the 2 percent around
/// them. It lifts first and dips last, so the turns cancel out.
const List<(double, bool)> _beats = [
  (0.50, true),
  (0.54, false),
  (0.58, true),
  (0.62, false),
  (0.66, true),
  (0.70, false),
  (0.74, true),
  (0.78, false),
];

/// The pose of the letter that starts [delay] loop fractions late, at loop
/// fraction [p]: how far it is below its place in design units, and its turn
/// in radians.
WelcomeWordLetter _letterAt(double p, double delay) {
  final offsets = <(double, double)>[
    (welcomeWordShakeFrom + delay, 0),
    for (final (at, isLifted) in _beats)
      (at + delay, isLifted ? -welcomeWordShakeLift : welcomeWordShakeDip),
    (welcomeWordShakeTo + delay, 0),
  ];
  final turns = <(double, double)>[
    (welcomeWordShakeFrom + delay, 0),
    for (final (at, isLifted) in _beats)
      (at + delay, isLifted ? -welcomeWordShakeTurn : welcomeWordShakeTurn),
    (welcomeWordShakeTo + delay, 0),
  ];
  return WelcomeWordLetter(
    offset: _through(p, offsets),
    turn: _through(p, turns),
  );
}

/// How far ring [index] has grown at loop time [seconds], 0 to 1.
double _ringProgress(double seconds, int index) {
  final local =
      (seconds - index * welcomeWordRingStaggerSeconds) %
      welcomeWordRingSeconds;
  // Dart's % on a negative number is positive, which is the wanted wrap.
  return local / welcomeWordRingSeconds;
}

/// The settled picture.
const WelcomeWordFrame _settled = WelcomeWordFrame(
  lines: [
    WelcomeWordLine(offset: 0, opacity: 1),
    WelcomeWordLine(offset: 0, opacity: 1),
    WelcomeWordLine(offset: 0, opacity: 1),
  ],
  blockScale: 1,
  letters: [
    WelcomeWordLetter(offset: 0, turn: 0),
    WelcomeWordLetter(offset: 0, turn: 0),
    WelcomeWordLetter(offset: 0, turn: 0),
    WelcomeWordLetter(offset: 0, turn: 0),
    WelcomeWordLetter(offset: 0, turn: 0),
  ],
  rings: [
    WelcomeWordRing(scale: 0.9, opacity: 0),
    WelcomeWordRing(scale: 0.9, opacity: 0),
    WelcomeWordRing(scale: 0.9, opacity: 0),
  ],
  face: WelcomeWordFace(
    shift: welcomeWordFaceIn,
    turn: welcomeWordFaceInTurn,
    shout: 1,
  ),
);

/// Where everything is [seconds] into the story.
///
/// With [reducedMotion] it is the settled picture at every time: the lines
/// in place, the block full, the letters still, the shouting face leaned in
/// and no rings.
WelcomeWordFrame welcomeWordFrameAt(
  double seconds, {
  required bool reducedMotion,
}) {
  if (reducedMotion) return _settled;
  final now = math.max<double>(0, seconds);
  final loopTime = now % welcomeWordLoopSeconds;
  final p = loopTime / welcomeWordLoopSeconds;

  final lines = [
    for (var i = 0; i < welcomeWordLineCount; i++)
      () {
        final progress =
            ((now - i * welcomeWordLineStaggerSeconds) / welcomeWordDropSeconds)
                .clamp(0.0, 1.0);
        final moved = AppCurves.easeBack.transform(progress);
        return WelcomeWordLine(
          offset: -welcomeWordDropFrom * (1 - moved),
          opacity: moved.clamp(0.0, 1.0),
        );
      }(),
  ];

  final heat = _heatAt(p);
  final rings = [
    for (var i = 0; i < welcomeWordRingCount; i++)
      () {
        final eased = Curves.easeOut.transform(_ringProgress(loopTime, i));
        return WelcomeWordRing(
          scale: 0.9 + (2.2 - 0.9) * eased,
          opacity: 0.5 * (1 - eased) * heat,
        );
      }(),
  ];

  return WelcomeWordFrame(
    lines: lines,
    blockScale: _blockAt(p),
    letters: [
      for (var i = 0; i < welcomeWordLetterCount; i++)
        _letterAt(
          p,
          i * welcomeWordLetterStaggerSeconds / welcomeWordLoopSeconds,
        ),
    ],
    rings: rings,
    face: WelcomeWordFace(
      shift: _through(
        p,
        const [
          (0, welcomeWordFaceOut),
          (0.40, welcomeWordFaceOut),
          (0.48, welcomeWordFaceIn),
          (0.86, welcomeWordFaceIn),
          (0.94, welcomeWordFaceOut),
          (1, welcomeWordFaceOut),
        ],
        curve: AppCurves.easeBack,
      ),
      turn: _through(
        p,
        const [
          (0, welcomeWordFaceOutTurn),
          (0.40, welcomeWordFaceOutTurn),
          (0.48, welcomeWordFaceInTurn),
          (0.86, welcomeWordFaceInTurn),
          (0.94, welcomeWordFaceOutTurn),
          (1, welcomeWordFaceOutTurn),
        ],
        curve: AppCurves.easeBack,
      ),
      shout: heat,
    ),
  );
}

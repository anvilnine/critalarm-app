import 'dart:math' as math;

import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

// The ways a stage can move, as names a layout picks and numbers the parts
// draw. Each variant is a pure function of the clock, or of a share of an
// entrance. Every one ends flat and upright, so its resting frame is
// complete. The first value of each enum is the approved Hero motion.

/// What drifts behind the mascot.
enum HeroAtmosphereStyle {
  /// A few soft shapes drifting at the edges. The approved air.
  drift,

  /// Rays from behind the mascot, turning slowly.
  rays,

  /// Bubbles rising up the sides.
  bubbles,

  /// Confetti that falls once and settles along the foot of the stage.
  confetti,

  /// Rings pulsing slowly out from the disc.
  rings,
}

/// How the mascot comes on.
enum HeroEntranceStyle {
  /// Up from a little below, past its size and back. The approved pop.
  pop,

  /// Dropped from above, with a bounce.
  drop,

  /// In from the side it stands on.
  slide,

  /// Up from under the foot of the stage: a look first, then all the way.
  peek,
}

/// What the mascot does while a turn plays.
enum HeroIdleStyle {
  /// A slow bob. The approved idle.
  bob,

  /// The bob, and every few seconds a lean toward the preview and back.
  lean,

  /// The bob, and a small hop as each new benefit takes the stage.
  benefitHop,
}

/// How a preview takes the place of the one before it.
enum HeroCardArrival {
  /// The new one fades in over the old with a small slide. The approved
  /// change.
  fade,

  /// The card turns over: the old one edge on, then the new one flat.
  flip,

  /// The old one slides out one side as the new one slides in the other.
  slideThrough,
}

/// The motion of one stage: one pick from each list. The default is the
/// approved Hero, so a layout names only what it changes.
///
/// ```dart
/// HeroComposition(
///   scope: scope,
///   motion: const HeroMotion(
///     atmosphere: HeroAtmosphereStyle.rays,
///     entrance: HeroEntranceStyle.drop,
///   ),
/// )
/// ```
@immutable
class HeroMotion {
  const HeroMotion({
    this.atmosphere = HeroAtmosphereStyle.drift,
    this.entrance = HeroEntranceStyle.pop,
    this.idle = HeroIdleStyle.bob,
    this.arrival = HeroCardArrival.fade,
  });

  final HeroAtmosphereStyle atmosphere;
  final HeroEntranceStyle entrance;
  final HeroIdleStyle idle;
  final HeroCardArrival arrival;

  @override
  bool operator ==(Object other) =>
      other is HeroMotion &&
      other.atmosphere == atmosphere &&
      other.entrance == entrance &&
      other.idle == idle &&
      other.arrival == arrival;

  @override
  int get hashCode => Object.hash(atmosphere, entrance, idle, arrival);
}

/// How much of the mascot shows over the foot of the stage when it looks,
/// in [HeroEntranceStyle.peek]: down to just under the eyes.
const double heroPeekShare = 0.52;

/// Where the mascot is on its way in: how far off its place in points, how
/// large, how solid. `clipsAtFoot` asks the stage to hide what is below
/// its foot.
typedef HeroEntrancePose = ({
  double dx,
  double dy,
  double scale,
  double opacity,
  bool clipsAtFoot,
});

/// The mascot's entrance in [style] when the stage's entrance is [entrance]
/// of the way through, 0 to 1, for a mascot [size] points square.
///
/// At zero nothing of the mascot shows. At one it is in its place at full
/// size, whatever the style.
///
/// [footDrop] is how far the mascot's top is above the foot of its stage,
/// for [HeroEntranceStyle.peek], which starts from under that foot. Null
/// takes the mascot's own height, for one drawn with no stage.
HeroEntrancePose heroEntrancePose(
  HeroEntranceStyle style,
  double entrance, {
  required double size,
  double? footDrop,
}) {
  switch (style) {
    case HeroEntranceStyle.pop:
      final arrive = AppCurves.easeBack.transform(phase(entrance, 0.08, 0.6));
      return (
        dx: 0,
        dy: 26 * (1 - arrive),
        scale: arrive,
        opacity: 1,
        clipsAtFoot: false,
      );
    case HeroEntranceStyle.drop:
      final fall = Curves.bounceOut.transform(phase(entrance, 0.08, 0.7));
      return (
        dx: 0,
        dy: -(size * 0.9 + 40) * (1 - fall),
        scale: 1,
        opacity: phase(entrance, 0.08, 0.16),
        clipsAtFoot: false,
      );
    case HeroEntranceStyle.slide:
      final arrive = AppCurves.easeBack.transform(phase(entrance, 0.08, 0.6));
      return (
        dx: -(size * 0.9 + 40) * (1 - arrive),
        dy: 0,
        scale: 1,
        opacity: phase(entrance, 0.08, 0.2),
        clipsAtFoot: false,
      );
    case HeroEntranceStyle.peek:
      // A look over the edge, a beat, then the rest of the way.
      final look = AppCurves.easeOut.transform(phase(entrance, 0.06, 0.3));
      final rise = AppCurves.easeBack.transform(phase(entrance, 0.46, 0.76));
      final under = footDrop ?? size;
      return (
        dx: 0,
        dy: (under - size * heroPeekShare * look) * (1 - rise),
        scale: 1,
        opacity: entrance > 0.06 ? 1 : 0,
        clipsAtFoot: entrance < 1,
      );
  }
}

/// How far the idle moves the mascot off its place: points sideways and
/// up or down, and a lean in radians.
typedef HeroIdlePose = ({double dx, double dy, double angle});

/// How long one bob takes, and how often the lean of [HeroIdleStyle.lean]
/// comes round.
const double heroBobSeconds = 3.2;
const double heroLeanEvery = 4.8;

/// The widest the mascot leans toward the preview, in radians: four
/// degrees.
const double heroLeanReach = 4 * math.pi / 180;

/// The idle in [style] at [seconds] of the loop, for a mascot [size]
/// points square. [turnSeconds] is how long the turn on the stage has
/// played, for the hop of [HeroIdleStyle.benefitHop].
///
/// With [seconds] at zero, which is every resting frame, the mascot is
/// level and upright in every style.
HeroIdlePose heroIdlePose(
  HeroIdleStyle style, {
  required double seconds,
  required double size,
  double turnSeconds = 0,
}) {
  final bob = seconds == 0
      ? 0.0
      : -3 * math.sin(2 * math.pi * seconds / heroBobSeconds);
  switch (style) {
    case HeroIdleStyle.bob:
      return (dx: 0, dy: bob, angle: 0);
    case HeroIdleStyle.lean:
      if (seconds == 0) return (dx: 0, dy: 0, angle: 0);
      final swell = math.sin(
        math.pi * phase(loopT(seconds, heroLeanEvery), 1.4, 3.2),
      );
      final lean = swell * swell;
      return (
        dx: size * 0.05 * lean,
        dy: bob * 0.6,
        angle: heroLeanReach * lean,
      );
    case HeroIdleStyle.benefitHop:
      if (seconds == 0) return (dx: 0, dy: 0, angle: 0);
      final p = phase(turnSeconds, 0.04, 0.4);
      return (dx: 0, dy: bob - size * 0.07 * 4 * p * (1 - p), angle: 0);
  }
}

/// How far a preview travels sideways as a swipe brings it in or sends it
/// out, in points.
const double heroCardSlide = 30;

/// One card on its way in or out: how far off its place in points, how
/// solid, how large, and how far turned about its upright axis in radians.
typedef HeroCardPose = ({double dx, double opacity, double scale, double turn});

/// The preview coming in and the one going out in [style], when the new
/// one is [enter] of the way in, 0 to 1.
///
/// [direction] is which way the hand sent it (1 from the right, -1 from the
/// left, 0 in place), [pull] where the finger let go of the old one, and
/// [width] the card's width. At one the new card is in place, flat, solid
/// and at full size, and the old one is gone.
({HeroCardPose incoming, HeroCardPose outgoing}) heroCardArrivalPose(
  HeroCardArrival style,
  double enter, {
  required double width,
  int direction = 0,
  double pull = 0,
}) {
  switch (style) {
    case HeroCardArrival.fade:
      final side = direction * heroCardSlide;
      return (
        incoming: (
          dx: side * (1 - AppCurves.easeSpring.transform(enter)),
          opacity: enter,
          scale: 0.94 + 0.06 * AppCurves.easeBack.transform(enter),
          turn: 0,
        ),
        outgoing: (
          dx: pull - side * AppCurves.easeOut.transform(enter),
          opacity: 1 - enter,
          scale: 1,
          turn: 0,
        ),
      );
    case HeroCardArrival.flip:
      // Which way it turns follows the hand. Half way both are edge on.
      final way = direction < 0 ? -1.0 : 1.0;
      final away = Curves.easeIn.transform(phase(enter, 0, 0.5));
      final home = AppCurves.easeOut.transform(phase(enter, 0.5, 1));
      return (
        incoming: (
          dx: 0,
          opacity: enter >= 0.5 ? 1 : 0,
          scale: 1,
          turn: way * (math.pi / 2) * (home - 1),
        ),
        outgoing: (
          dx: pull * (1 - away),
          opacity: enter < 0.5 ? 1 : 0,
          scale: 1,
          turn: way * (math.pi / 2) * away,
        ),
      );
    case HeroCardArrival.slideThrough:
      final way = direction < 0 ? -1.0 : 1.0;
      final travel = width + 24;
      final along = Curves.easeInOutCubic.transform(enter);
      return (
        incoming: (
          dx: way * travel * (1 - along),
          opacity: phase(enter, 0, 0.45),
          scale: 1,
          turn: 0,
        ),
        outgoing: (
          dx: pull * (1 - along) - way * travel * along,
          opacity: 1 - phase(enter, 0.4, 0.9),
          scale: 1,
          turn: 0,
        ),
      );
  }
}

/// How many rays [HeroAtmosphereStyle.rays] draws, and how long one full
/// turn takes.
const int heroRayCount = 10;
const double heroRayTurnSeconds = 60;

/// How far the rays have turned at [seconds], in radians. Zero at rest,
/// where one ray points straight up.
double heroRayTurn(double seconds) =>
    2 * math.pi * loopT(seconds, heroRayTurnSeconds) / heroRayTurnSeconds;

/// One small thing in the air: where it is as a share of the stage's width
/// and height, its size in points, how solid it is, and how far turned.
typedef HeroMote = ({Offset at, double size, double alpha, double angle});

/// The bubbles of [HeroAtmosphereStyle.bubbles]: where each starts across
/// the stage, how large it is, how many seconds it takes to rise the whole
/// height, and where in that rise it is at rest.
const _bubbles = <(double, double, double, double)>[
  (0.06, 9, 11, 0.15),
  (0.13, 5, 8, 0.62),
  (0.2, 12, 14, 0.4),
  (0.33, 4, 9, 0.85),
  (0.58, 6, 10, 0.72),
  (0.74, 4, 7, 0.3),
  (0.84, 10, 13, 0.55),
  (0.91, 6, 9, 0.05),
  (0.96, 13, 15, 0.8),
];

/// How many bubbles there are.
const int heroBubbleCount = 9;

/// Bubble [index] at [seconds]. It rises from under the foot of the stage
/// to over its top and comes round again, fading at both ends. At zero it
/// holds its resting place.
HeroMote heroBubbleAt(int index, double seconds) {
  final (x, size, every, home) = _bubbles[index % _bubbles.length];
  final risen = loopT(home + seconds / every, 1);
  final sway = seconds == 0
      ? 0.0
      : 0.012 * math.sin(2 * math.pi * (seconds / 5 + home));
  return (
    at: Offset(x + sway, 1.08 - 1.16 * risen),
    size: size,
    alpha: math.sin(math.pi * risen),
    angle: 0,
  );
}

/// How many pieces of confetti there are, and the second the last one has
/// landed.
const int heroConfettiCount = 16;
const double heroConfettiSettled = 0.1 + 15 * 0.07 + 1.15;

/// Piece [index] of the confetti at [seconds]. Each falls once from over
/// the top of the stage, turning, and lands flat along the foot of the
/// stage, where it stays. At zero, and from [heroConfettiSettled] on, every
/// piece has landed.
HeroMote heroConfettiAt(int index, double seconds) {
  // A spread that looks thrown, from the index alone.
  final spread = loopT(index * 0.618, 1);
  final x = 0.04 + 0.92 * spread;
  final home = Offset(x, 0.9 + 0.08 * loopT(index * 0.37, 1));
  final size = 5.0 + 4 * loopT(index * 0.29, 1);
  if (seconds == 0) return (at: home, size: size, alpha: 1, angle: 0);

  final start = 0.1 + index * 0.07;
  final p = phase(seconds, start, start + 1.15);
  if (p <= 0) return (at: Offset(x, -0.1), size: size, alpha: 0, angle: 0);
  final fall = Curves.easeIn.transform(p);
  final sway = 0.04 * math.sin(math.pi * 3 * p + index) * (1 - p);
  return (
    at: Offset(home.dx + sway, -0.1 + (home.dy + 0.1) * fall),
    size: size,
    alpha: 1,
    angle: (1 - p) * (2 * math.pi + index),
  );
}

/// How many rings [HeroAtmosphereStyle.rings] draws, and how long one
/// takes to travel out.
const int heroRingCount = 3;
const double heroRingSeconds = 5.4;

/// Ring [index] at [seconds]: how far out it is, 0 to 1, and how solid.
/// The rings follow each other out and fade as they go. At zero each
/// holds its resting place, evenly spaced.
({double out, double alpha}) heroRingAt(int index, double seconds) {
  final out = loopT(seconds / heroRingSeconds + index / heroRingCount, 1);
  return (out: out, alpha: math.sin(math.pi * out) * (1 - 0.5 * out));
}

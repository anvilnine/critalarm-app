import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';
import 'package:flutter/animation.dart';

// The confetti version, as numbers. The button bursts into confetti, the
// mascot crouches and jumps into a crown, the confetti falls and settles
// on the floor it stands on, and the lines check themselves off.
//
// The times follow the purchase cue, which starts at zero: a click, a
// short pick up, one big swell that starts at 0.4 and peaks at 0.6, and a
// long tail that is over by 2.2.

/// One piece of confetti at one moment.
typedef ConfettiPiece = ({
  Offset at,
  double angle,
  double alpha,
  int shape,
  int ink,
});

/// The show's timeline. Every value is a pure function of the seconds
/// since the purchase was confirmed.
abstract final class ConfettiTimeline {
  /// The button bursts, on the cue's click.
  static const double burst = 0;

  /// The mascot is on its way to the stage and crouches, on the pick up.
  static const double crouch = 0.14;

  /// It jumps, as the swell starts.
  static const double leap = 0.4;

  /// It is on the ground again.
  static const double land = 0.84;

  /// The top of the jump, on the swell's peak. The crown is on by now.
  static const double apex = (leap + land) / 2;

  /// The paywall under the show is covered.
  static const double cover = 0.38;

  /// The headline pops in as the mascot comes down.
  static const double headline = 0.7;

  /// The host's button is on.
  static const double goOn = 1.1;

  /// The first line is checked. Each line after it follows on the tail.
  static const double firstCheck = 1.06;

  /// The last piece of confetti lies still.
  static const double settled = 2.2;

  /// The resting frame.
  static const double end = 2.4;

  /// How many pieces fly.
  static const int pieces = 42;

  /// The seconds between two checks with [lines] lines: at most a quarter
  /// second, and all of them inside the cue's tail.
  static double checkEvery(int lines) =>
      lines <= 1 ? 0 : math.min(0.24, 0.88 / (lines - 1));

  /// The second line [index] of [lines] is checked.
  static double checkAt(int index, int lines) =>
      firstCheck + index * checkEvery(lines);

  /// How far the cover has grown out of the button at [t], 0 to 1.
  static double covered(double t) =>
      Curves.easeOutCubic.transform(phase(t, burst, cover));

  /// The size of the pressed button at [t] against its own: it swells for
  /// a moment and is gone into the point the confetti comes from.
  static double button(double t) {
    const swollen = 0.05;
    const gone = 0.2;
    if (t < swollen) return 1 + 0.08 * phase(t, burst, swollen);
    return 1.08 * (1 - Curves.easeIn.transform(phase(t, swollen, gone)));
  }

  /// The mascot stays where the layout had it until the cover has passed
  /// under it, so the layout's own is never seen beside it.
  static const double setOff = 0.16;

  /// How far the mascot is from where the layout had it to the stage at
  /// [t], 0 to 1. There before it jumps.
  static double travel(double t) =>
      Curves.easeInOutCubic.transform(phase(t, setOff, leap - 0.03));

  /// The mascot's height against its rest height at [t]: down in the
  /// crouch, long on the way up, down again as it lands, and one after.
  static double stretch(double t) {
    if (t < crouch) return 1;
    if (t < leap) {
      return 1 - 0.2 * Curves.easeOut.transform(phase(t, crouch, leap));
    }
    if (t < land) {
      final p = phase(t, leap, land);
      // Out of the crouch into a stretch, and its own height by the top.
      if (p < 0.2) return 0.8 + 0.34 * Curves.easeOut.transform(p / 0.2);
      return 1.14 - 0.14 * Curves.easeInOut.transform(phase(p, 0.2, 0.5));
    }
    final p = phase(t, land, land + 0.3);
    return 1 - 0.26 * math.sin(math.pi * p) * (1 - p);
  }

  /// How high the mascot is at [t], as a share of its own height: the
  /// jump, then a small bounce, then a nod for each line that is checked.
  static double lift(double t, {required int lines}) {
    if (t >= leap && t < land) return 0.62 * thanksArc(phase(t, leap, land));
    if (t >= land && t < land + 0.22) {
      return 0.07 * thanksArc(phase(t, land, land + 0.22));
    }
    for (var i = 0; i < lines; i++) {
      final at = checkAt(i, lines);
      if (t >= at && t < at + 0.2) {
        return 0.05 * thanksArc(phase(t, at, at + 0.2));
      }
    }
    return 0;
  }

  /// A lean inside the jump, in radians. Zero at both ends and at rest.
  static double lean(double t) =>
      0.07 * math.sin(2 * math.pi * phase(t, leap, land));

  /// How far on the crown is at [t], 0 to 1: it drops on as the mascot
  /// comes up to meet it, and stays.
  static double crown(double t) => phase(t, leap + 0.04, apex + 0.04);

  /// The face at [t]: wide eyed in the crouch, laughing in the air, eyes
  /// on the lines while they are checked, then glad, which is the idle of
  /// the resting frame.
  static ThanksFace face(double t) {
    if (t < leap) {
      return (
        from: HeroFace.glad,
        to: HeroFace.arriving,
        blend: phase(t, 0.02, 0.14),
      );
    }
    if (t < firstCheck - 0.1) {
      return (
        from: HeroFace.arriving,
        to: HeroFace.glad,
        blend: phase(t, leap, leap + 0.14),
      );
    }
    if (t < settled - 0.3) {
      return (
        from: HeroFace.glad,
        to: HeroFace.watching,
        blend: phase(t, firstCheck - 0.1, firstCheck + 0.06),
      );
    }
    if (t < end) {
      return (
        from: HeroFace.watching,
        to: HeroFace.glad,
        blend: phase(t, settled - 0.3, settled - 0.1),
      );
    }
    return thanksIdleFace(t - end);
  }

  /// How far in the disc behind the mascot, the headline and each line
  /// are at [t], 0 to 1.
  static double disc(double t) =>
      AppCurves.easeBack.transform(phase(t, leap, leap + 0.36));
  static double headlineIn(double t) => phase(t, headline, headline + 0.3);
  static double lineIn(double t, int index) =>
      phase(stagger(index, t, each: 0.05, start: headline + 0.12), 0, 0.24);

  /// How far line [index] of [lines] is checked at [t], 0 to 1.
  static double check(double t, int index, int lines) {
    final at = checkAt(index, lines);
    return phase(t, at, at + 0.22);
  }

  /// A number from 0 up to 1 that is always the same for one piece and one
  /// `salt`.
  static double _roll(int index, int salt) {
    final x = math.sin(index * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  /// Whether piece [index] ends lying on the floor. The others fade on
  /// the way down, so the floor is strewn, not buried.
  static bool settles(int index) => index % 5 < 2;

  /// How deep the strip of floor the pieces come to lie on is, in points.
  static const double floorDepth = 18;

  /// Piece [index] at [t], thrown from [origin] over a screen [size] with
  /// the floor at [floor] points down. Null while it is not thrown yet and
  /// once it has faded.
  ///
  /// A piece flies up and out to its own high point, then flutters down.
  /// One that settles lands on the floor and lies flat. At rest every
  /// piece left is flat on the floor.
  static ConfettiPiece? piece(
    int index,
    double t, {
    required Offset origin,
    required Size size,
    required double floor,
  }) {
    final since = t - burst - _roll(index, 1) * 0.07;
    if (since <= 0) return null;
    final top = math.max(0, floor - size.width * 0.9).toDouble();
    final high = Offset(
      size.width * (0.05 + 0.9 * _roll(index, 2)),
      top + (floor - top) * 0.62 * _roll(index, 3),
    );
    const turn = 0.46;
    final up = Curves.easeOutCubic.transform(phase(since, 0, turn + 0.1));
    final falling = math.max(0, since - turn).toDouble();
    final speed = 150 + 190 * _roll(index, 4);
    // Each lies at its own depth, so they read as on a floor, not a line.
    final room = floor - high.dy + floorDepth * _roll(index, 8);
    // Solved for the moment it reaches the floor.
    final landsAfter =
        (-speed + math.sqrt(speed * speed + 4 * 70 * room)) / (2 * 70);
    final fallen = math.min(falling, landsAfter);
    final drop = speed * fallen + 70 * fallen * fallen;
    final sway =
        math.sin(fallen * (3 + 2 * _roll(index, 5)) + _roll(index, 6) * 6.28) *
        12 *
        (1 - phase(falling, landsAfter - 0.2, landsAfter));
    final at = Offset.lerp(origin, high, up)! + Offset(sway, drop);
    final spin = (_roll(index, 7) * 2 - 1) * 9;
    final spun = spin * math.min(since, turn + landsAfter);
    // It lies flat: the nearest half turn.
    final flat = (spun / math.pi).roundToDouble() * math.pi;
    final lies = phase(falling, landsAfter - 0.16, landsAfter);
    final angle = spun + (flat - spun) * lies;
    final alpha = settles(index)
        ? 1.0
        : 1 - phase(falling, landsAfter * 0.45, landsAfter * 0.95);
    if (alpha <= 0) return null;
    return (
      at: at,
      angle: lies >= 1 ? 0 : angle,
      alpha: alpha,
      shape: index % 3,
      ink: index % 4,
    );
  }
}

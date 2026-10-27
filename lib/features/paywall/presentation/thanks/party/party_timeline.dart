import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';
import 'package:flutter/widgets.dart';

// The receipt party, as numbers. A slip prints up out of the pressed
// button with the free plan's limits as its lines, and the mascot catches
// it. The product's stamp lands on it and confetti bursts from the stamp.
// Then each line is struck through and changes to what the buyer has now.
// The mascot jumps with the slip and lands as the last confetti does.
//
// The times follow the purchase cue, which starts at zero: a click, a
// short pick up, one big swell that starts at 0.4 and peaks at 0.6, and a
// long tail that is over by 2.2. The stamp lands on the peak, felt and
// not heard, and the lines change down the tail, felt and not heard. The
// confetti lies still after the cue is over, so that moment has a sound.

/// The stamp on the slip at one moment.
typedef PartyStamp = ({double opacity, double scale, double angle});

/// The show's timeline. Every value is a pure function of the seconds
/// since the purchase was confirmed.
abstract final class PartyTimeline {
  /// The paywall under the show is covered.
  static const double cover = 0.34;

  /// The mascot stays where the layout had it until the cover has passed
  /// under it, so the layout's own is never seen beside it.
  static const double setOff = 0.14;

  /// The slip starts out of the button, on the cue's click.
  static const double feed = 0.04;

  /// The mascot has the slip, on the pick up.
  static const double caught = 0.44;

  /// The stamp starts down, and lands on the swell's peak. The confetti
  /// bursts from where it lands.
  static const double stampFalls = 0.46;
  static const double stampAt = 0.6;

  /// The first line changes. Each line after it follows on the tail.
  static const double firstLine = 0.86;

  /// How long one line takes: the old limit is struck through and the new
  /// value comes in beside it.
  static const double lineSeconds = 0.3;

  /// The host's button is on.
  static const double goOn = 1.1;

  /// The mascot jumps with the slip, and lands as the last piece of
  /// confetti comes to lie, which is after the purchase cue is over.
  static const double raise = 1.98;
  static const double settled = 2.34;

  /// The resting frame.
  static const double end = 3;

  /// Room kept clear under the headline for the confetti to lie in.
  static const double foot = ThanksConfetti.floorDepth + 14;

  /// How far under the headline's box the confetti's floor is.
  static const double floorDrop = 6;

  /// The seconds between two lines with [lines] lines: all of them done
  /// before the mascot jumps.
  static double lineEvery(int lines) =>
      lines <= 1 ? 0 : math.min(0.26, 0.8 / (lines - 1));

  /// The second line [index] of [lines] starts to change.
  static double lineAt(int index, int lines) =>
      firstLine + index * lineEvery(lines);

  /// How far the cover has grown out of the button at [t], 0 to 1.
  static double covered(double t) =>
      Curves.easeOutCubic.transform(phase(t, 0, cover));

  /// How far the mascot is from where the layout had it to the stage at
  /// [t], 0 to 1. There before the slip is.
  static double travel(double t) =>
      Curves.easeInOutCubic.transform(phase(t, setOff, 0.4));

  /// How far the slip is from the button to the mascot at [t], 0 to 1.
  static double fed(double t) =>
      Curves.easeOutCubic.transform(phase(t, feed, caught));

  /// The size of the pressed button at [t] against its own: it swells for
  /// a moment, holds while the slip comes out of it, and is gone.
  static double button(double t) {
    const swollen = 0.05;
    if (t < swollen) return 1 + 0.06 * phase(t, 0, swollen);
    return 1.06 * (1 - Curves.easeIn.transform(phase(t, 0.28, 0.42)));
  }

  /// The stamp at [t]: it comes down large and turned, and lands square
  /// at its own size, where it stays.
  static PartyStamp stamp(double t) {
    final fall = Curves.easeIn.transform(phase(t, stampFalls, stampAt));
    // A small give as the rubber meets the paper.
    final p = phase(t, stampAt, stampAt + 0.22);
    final give = 0.08 * math.sin(math.pi * p) * (1 - p);
    return (
      opacity: phase(t, stampFalls, stampFalls + 0.06),
      scale: 1 + 1.4 * (1 - fall) - give,
      angle: -0.3 * (1 - fall),
    );
  }

  /// How far the slip is pushed down by the stamp at [t], 0 to 1. Zero
  /// before it lands and soon after.
  static double pressed(double t) {
    final p = phase(t, stampAt, stampAt + 0.3);
    return math.sin(math.pi * p) * (1 - p);
  }

  /// The seconds since the confetti burst at [t]. Zero and under before.
  static double burst(double t) => t - stampAt;

  /// How far line [index] of [lines] has changed at [t], 0 to 1.
  static double lifted(double t, int index, int lines) {
    final at = lineAt(index, lines);
    return phase(t, at, at + lineSeconds);
  }

  /// How far the line through the old limit of line [index] is drawn at
  /// [t], 0 to 1. It is the first thing a line does.
  static double struck(double t, int index, int lines) =>
      phase(lifted(t, index, lines), 0, 0.34);

  /// How far in the new value of line [index] is at [t], 0 to 1. It comes
  /// in once the old one is struck.
  static double valueIn(double t, int index, int lines) =>
      Curves.easeOut.transform(phase(lifted(t, index, lines), 0.24, 0.6));

  /// The number line [index] shows at [t], rolling from [from] to [to].
  static int count(
    double t,
    int index,
    int lines, {
    required int from,
    required int to,
  }) {
    final run = Curves.easeOutCubic.transform(
      phase(lifted(t, index, lines), 0.24, 0.94),
    );
    return from + ((to - from) * run).round();
  }

  /// How high the mascot is at [t], as a share of its own height: a nod
  /// for each line, then the jump with the slip held up. The slip goes
  /// with it.
  static double lift(double t, {required int lines}) {
    if (t >= raise) return 0.34 * thanksArc(phase(t, raise, settled));
    for (var i = 0; i < lines; i++) {
      final at = lineAt(i, lines);
      if (t >= at && t < at + 0.18) {
        return 0.04 * thanksArc(phase(t, at, at + 0.18));
      }
    }
    return 0;
  }

  /// The mascot's height against its rest height at [t]: it gives under
  /// the stamp, crouches before the jump and gives again as it lands.
  static double stretch(double t) {
    if (t < stampAt) return 1;
    if (t < raise - 0.12) {
      final p = phase(t, stampAt, stampAt + 0.22);
      return 1 - 0.16 * math.sin(math.pi * p) * (1 - p);
    }
    if (t < raise) return 1 - 0.14 * phase(t, raise - 0.12, raise);
    if (t < settled) {
      return 0.86 +
          0.14 * Curves.easeOut.transform(phase(t, raise, raise + 0.1));
    }
    final p = phase(t, settled, settled + 0.24);
    return 1 - 0.2 * math.sin(math.pi * p) * (1 - p);
  }

  /// The face at [t]: wide eyed as the slip comes, keen under the stamp,
  /// laughing as the confetti bursts, eyes on the lines while they change,
  /// laughing again in the jump, then glad, which is the idle of the
  /// resting frame.
  static ThanksFace face(double t) {
    if (t < stampFalls) {
      return (
        from: HeroFace.glad,
        to: HeroFace.arriving,
        blend: phase(t, 0.1, 0.26),
      );
    }
    if (t < stampAt) {
      return (
        from: HeroFace.arriving,
        to: HeroFace.keen,
        blend: phase(t, stampFalls, stampFalls + 0.1),
      );
    }
    if (t < firstLine - 0.06) {
      return (
        from: HeroFace.keen,
        to: HeroFace.winning,
        blend: phase(t, stampAt + 0.02, stampAt + 0.14),
      );
    }
    if (t < raise - 0.12) {
      return (
        from: HeroFace.winning,
        to: HeroFace.watching,
        blend: phase(t, firstLine - 0.06, firstLine + 0.1),
      );
    }
    if (t < end - 0.24) {
      return (
        from: HeroFace.watching,
        to: HeroFace.winning,
        blend: phase(t, raise - 0.12, raise),
      );
    }
    if (t < end) {
      return (
        from: HeroFace.winning,
        to: HeroFace.glad,
        blend: phase(t, end - 0.24, end - 0.04),
      );
    }
    return thanksIdleFace(t - end);
  }

  /// How far in the disc behind the mascot and the headline are at [t], 0
  /// to 1. The headline lands with the stamp.
  static double disc(double t) =>
      AppCurves.easeBack.transform(phase(t, caught - 0.1, caught + 0.26));
  static double headlineIn(double t) =>
      phase(t, stampAt + 0.06, stampAt + 0.34);
}

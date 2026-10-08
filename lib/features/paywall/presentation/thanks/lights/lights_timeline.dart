import 'dart:math' as math;

import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

// The lights version, as numbers. The screen goes dark from the button
// out and a lamp comes down on its wire. The mascot jumps for the pull
// cord and tugs it on the purchase cue's peak: the lamp comes on over it.
// The lines come in under it as a sign with its bulbs off. Once the cue is
// over the mascot tugs the cord again, which is heard, and the bulbs come
// on one after another down the sign.
//
// The times follow the purchase cue, which starts at zero: a click, a
// short pick up, one big swell that starts at 0.4 and peaks at 0.6, and a
// long tail that is over by 2.2.

/// Where the lights version hangs its lamp, stands its mascot and writes
/// its words on one phone. The lamp's wire comes from the top edge, so the
/// air over the mascot is the lamp's, and the block is placed so the air
/// under the lines is small and meant.
@immutable
class LightsStage {
  const LightsStage({required this.stage, required this.shade});

  factory LightsStage.of({
    required Size size,
    required EdgeInsets padding,
    required int lines,
    double textScale = 1,
  }) {
    final room = Rect.fromLTRB(
      0,
      padding.top,
      size.width,
      size.height - padding.bottom - paywallThanksButtonRoom,
    );
    final isCompact = size.height <= 667;
    final headlineSize = isCompact ? 30.0 : 38.0;
    final lineSize = isCompact ? 16.0 : 19.0;
    final rowGap = isCompact ? 8.0 : 14.0;
    final row =
        math.max(ThanksStage.markSize, lineSize * 1.3 * textScale) + rowGap;
    final wordsHeight =
        headlineSize * 1.15 * textScale + ThanksStage.headlineGap + lines * row;
    final edge = ((room.height * 0.9 - wordsHeight) / (tall + gap)).clamp(
      size.width * 0.2,
      size.width * 0.5,
    );
    final block = edge * (tall + gap) + wordsHeight;
    final top = room.top + math.max(0, room.height - block) * 0.5;
    final crit = Rect.fromLTWH(
      (size.width - edge) / 2,
      top + edge * (tall - 1),
      edge,
      edge,
    );
    return LightsStage(
      stage: ThanksStage(
        crit: crit,
        words: Rect.fromLTRB(
          thanksSideInset,
          crit.bottom + edge * gap,
          size.width - thanksSideInset,
          room.bottom,
        ),
        headlineSize: headlineSize,
        lineSize: lineSize,
        rowGap: rowGap,
      ),
      shade: Rect.fromCenter(
        center: Offset(size.width / 2, top + edge * shadeTall / 2),
        width: edge * 0.92,
        height: edge * shadeTall,
      ),
    );
  }

  /// The lamp's shade, the air under it and the mascot, in units of the
  /// mascot's edge.
  static const double tall = shadeTall + 0.46 + 1;
  static const double shadeTall = 0.3;

  /// The air between the floor and the headline, in units.
  static const double gap = 0.3;

  /// The mascot's box and the words, for the shared parts.
  final ThanksStage stage;

  /// The lamp's shade where it hangs.
  final Rect shade;

  double get edge => stage.crit.width;
  double get floor => stage.crit.bottom;

  /// The pull cord's knob at rest: over the mascot's shoulder, where a
  /// jump reaches it.
  Offset get knob =>
      Offset(stage.crit.center.dx + edge * 0.34, stage.crit.top - edge * 0.1);
}

/// The show's timeline. Every value is a pure function of the seconds
/// since the purchase was confirmed.
abstract final class LightsTimeline {
  /// The paywall under the show is covered, in the dark.
  static const double cover = 0.34;

  /// The lamp comes down on its wire.
  static const double lampFrom = 0.08;
  static const double lampDown = 0.38;

  /// The mascot stays where the layout had it until the cover has passed
  /// under it.
  static const double setOff = 0.14;

  /// It jumps for the cord, as the swell starts.
  static const double leap = 0.4;

  /// It tugs the cord at the top of the jump, on the swell's peak, and the
  /// lamp comes on.
  static const double pull = 0.6;

  /// It is on the floor again.
  static const double land = 0.8;

  /// The headline, and the first line of the sign, its bulb off.
  static const double headline = 0.9;
  static const double firstLine = 1;

  /// The host's button is on.
  static const double button = 1.1;

  /// The second jump, and the second tug at its top, once the purchase
  /// cue is over. It is heard.
  static const double leapAgain = 2.07;
  static const double pullAgain = 2.25;
  static const double landAgain = 2.43;

  /// The first bulb of the sign comes on, when the tug's sound is over.
  static const double firstBulb = 2.7;

  /// The resting frame.
  static const double end = 3.9;

  /// The seconds between two bulbs with [lines] lines.
  static double bulbEvery(int lines) =>
      lines <= 1 ? 0 : math.min(0.18, 0.72 / (lines - 1));

  /// The second bulb [index] of [lines] comes on.
  static double bulbAt(int index, int lines) =>
      firstBulb + index * bulbEvery(lines);

  /// How far the cover has grown out of the button at [t], 0 to 1.
  static double covered(double t) =>
      Curves.easeOutCubic.transform(phase(t, 0, cover));

  /// How far down the lamp is at [t], 0 to 1. It comes a little past its
  /// place and back.
  static double lamp(double t) =>
      Curves.easeOutBack.transform(phase(t, lampFrom, lampDown));

  /// How bright the lamp is at [t], 0 to 1: off, then on with one flicker
  /// as it catches, then on.
  static double lit(double t) {
    final p = t - pull;
    if (p < 0) return 0;
    if (p < 0.05) return p / 0.05;
    if (p < 0.09) return 1 - 0.45 * (p - 0.05) / 0.04;
    if (p < 0.16) return 0.55 + 0.45 * (p - 0.09) / 0.07;
    return 1;
  }

  /// How much brighter than on the lamp is at [t], 0 to 1: it swells once
  /// with the second tug and comes back.
  static double flare(double t) =>
      thanksArc(phase(t, pullAgain, pullAgain + 0.5));

  /// How dark the room is at [t], 0 to 1: it dims as the cover grows and
  /// clears as the lamp comes on.
  static double dark(double t) => covered(t) * (1 - lit(t));

  /// How far the cord is drawn down at [t], 0 to 1: down with each tug,
  /// then it springs back and hangs still.
  static double tug(double t) {
    for (final at in const [pull, pullAgain]) {
      if (t < at - 0.06 || t >= at + 0.36) continue;
      if (t < at) return Curves.easeOut.transform(phase(t, at - 0.06, at));
      final p = phase(t, at, at + 0.36);
      return (1 - p) * (1 - p) * math.cos(3 * math.pi * p);
    }
    return 0;
  }

  /// How far the mascot is from where the layout had it to the stage at
  /// [t], 0 to 1. There before it jumps.
  static double travel(double t) =>
      Curves.easeInOutCubic.transform(phase(t, setOff, leap - 0.03));

  /// How high the mascot is at [t], as a share of its own height: the two
  /// jumps for the cord, then a nod for each bulb.
  static double lift(double t, {required int lines}) {
    if (t >= leap && t < land) return 0.3 * thanksArc(phase(t, leap, land));
    if (t >= leapAgain && t < landAgain) {
      return 0.3 * thanksArc(phase(t, leapAgain, landAgain));
    }
    for (var i = 0; i < lines; i++) {
      final at = bulbAt(i, lines);
      if (t >= at && t < at + 0.14) {
        return 0.05 * thanksArc(phase(t, at, at + 0.14));
      }
    }
    return 0;
  }

  /// The mascot's height against its rest height at [t]: down before each
  /// jump and as it lands, one everywhere else.
  static double stretch(double t) {
    for (final (up, down) in const [(leap, land), (leapAgain, landAgain)]) {
      if (t < up - 0.12 || t >= down + 0.28) continue;
      if (t < up) {
        return 1 - 0.16 * Curves.easeOut.transform(phase(t, up - 0.12, up));
      }
      if (t < down) {
        return 0.84 + 0.16 * Curves.easeOut.transform(phase(t, up, up + 0.1));
      }
      final p = phase(t, down, down + 0.28);
      return 1 - 0.2 * math.sin(math.pi * p) * (1 - p);
    }
    return 1;
  }

  /// The face at [t]: puzzled in the dark, keen on the cord, winning as
  /// the lamp comes on, eyes on the sign, keen and winning again for the
  /// second tug, eyes on the bulbs, then glad, which is the idle of the
  /// resting frame.
  static ThanksFace face(double t) {
    if (t < 0.28) {
      return (
        from: HeroFace.glad,
        to: HeroFace.thinking,
        blend: phase(t, 0.06, 0.18),
      );
    }
    if (t < pull) {
      return (
        from: HeroFace.thinking,
        to: HeroFace.keen,
        blend: phase(t, 0.28, 0.38),
      );
    }
    if (t < firstLine + 0.1) {
      return (
        from: HeroFace.keen,
        to: HeroFace.winning,
        blend: phase(t, pull, pull + 0.1),
      );
    }
    if (t < leapAgain - 0.3) {
      return (
        from: HeroFace.winning,
        to: HeroFace.watching,
        blend: phase(t, firstLine + 0.1, firstLine + 0.3),
      );
    }
    if (t < pullAgain) {
      return (
        from: HeroFace.watching,
        to: HeroFace.keen,
        blend: phase(t, leapAgain - 0.3, leapAgain - 0.14),
      );
    }
    if (t < firstBulb) {
      return (
        from: HeroFace.keen,
        to: HeroFace.winning,
        blend: phase(t, pullAgain, pullAgain + 0.1),
      );
    }
    if (t < end - 0.4) {
      return (
        from: HeroFace.winning,
        to: HeroFace.watching,
        blend: phase(t, firstBulb, firstBulb + 0.16),
      );
    }
    if (t < end) {
      return (
        from: HeroFace.watching,
        to: HeroFace.glad,
        blend: phase(t, end - 0.4, end - 0.1),
      );
    }
    return thanksIdleFace(t - end);
  }

  /// How far in the headline and each line are at [t], 0 to 1.
  static double headlineIn(double t) => phase(t, headline, headline + 0.3);
  static double lineIn(double t, int index) =>
      phase(stagger(index, t, each: 0.07, start: firstLine), 0, 0.24);

  /// How far on bulb [index] of [lines] is at [t], 0 to 1.
  static double bulb(double t, int index, int lines) {
    final at = bulbAt(index, lines);
    return phase(t, at, at + 0.16);
  }
}

import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';
import 'package:flutter/animation.dart';

// The unlock version, as numbers. The screen goes dark from the button
// out. Every line comes in behind a closed padlock, the mascot watches,
// and the padlocks open one after another down the screen. When the last
// one is open the mascot jumps for it and the headline says so.
//
// The times follow the purchase cue, which starts at zero: a click, a
// short pick up, one big swell that starts at 0.4 and peaks at 0.6, and a
// long tail. The first lock opens as the swell starts.

/// The show's timeline. Every value is a pure function of the seconds
/// since the purchase was confirmed.
abstract final class UnlockTimeline {
  /// The paywall under the show is covered.
  static const double cover = 0.34;

  /// The lines rise in, each behind its closed padlock, on the pick up.
  static const double lines = 0.1;

  /// The first padlock opens, as the swell starts.
  static const double firstOpen = 0.4;

  /// How long one padlock takes to open, its shake included.
  static const double openSeconds = 0.22;

  /// The host's button is on.
  static const double button = 1.1;

  /// The resting frame.
  static const double end = 2.1;

  /// The seconds between two padlocks with [count] lines.
  static double openEvery(int count) =>
      count <= 1 ? 0 : math.min(0.18, 0.72 / (count - 1));

  /// The second padlock [index] of [count] opens.
  static double openAt(int index, int count) =>
      firstOpen + index * openEvery(count);

  /// The second the mascot jumps: a beat after the last padlock.
  static double glad(int count) => openAt(math.max(0, count - 1), count) + 0.26;

  /// The second it is back on the floor.
  static double landed(int count) => glad(count) + 0.4;

  /// How far the cover has grown out of the button at [t], 0 to 1.
  static double covered(double t) =>
      Curves.easeOutCubic.transform(phase(t, 0, cover));

  /// How far the mascot is from where the layout had it to the stage at
  /// [t], 0 to 1. There before the first padlock opens.
  static double travel(double t) =>
      Curves.easeInOutCubic.transform(phase(t, setOff, firstOpen - 0.02));

  /// The mascot stays where the layout had it until the cover has passed
  /// under it, so the layout's own is never seen beside it.
  static const double setOff = 0.14;

  /// How far in line [index] is at [t], 0 to 1.
  static double lineIn(double t, int index) =>
      phase(stagger(index, t, each: 0.02, start: lines), 0, 0.2);

  /// How far open padlock [index] of [count] is at [t], 0 to 1.
  static double open(double t, int index, int count) {
    final at = openAt(index, count);
    return phase(t, at, at + openSeconds);
  }

  /// How far padlock [index] leans as it gives, in radians: a short shake
  /// in the first half of its opening, zero before and after.
  static double shake(double t, int index, int count) {
    final p = open(t, index, count);
    if (p <= 0 || p >= 0.5) return 0;
    return 0.2 * math.sin(4 * math.pi * p) * (1 - 2 * p);
  }

  /// How high the mascot is at [t], as a share of its own height: a small
  /// hop for each padlock, then the jump.
  static double lift(double t, {required int count}) {
    final jump = glad(count);
    if (t >= jump) return 0.46 * thanksArc(phase(t, jump, landed(count)));
    for (var i = 0; i < count; i++) {
      final at = openAt(i, count);
      if (t >= at && t < at + 0.16) {
        return 0.06 * thanksArc(phase(t, at, at + 0.16));
      }
    }
    return 0;
  }

  /// The mascot's height against its rest height at [t]: down before the
  /// jump and as it lands, one everywhere else.
  static double stretch(double t, {required int count}) {
    final jump = glad(count);
    final down = landed(count);
    if (t < jump - 0.12) return 1;
    if (t < jump) return 1 - 0.14 * phase(t, jump - 0.12, jump);
    if (t < down) {
      return 0.86 + 0.14 * Curves.easeOut.transform(phase(t, jump, jump + 0.1));
    }
    final p = phase(t, down, down + 0.28);
    return 1 - 0.22 * math.sin(math.pi * p) * (1 - p);
  }

  /// The face at [t]: eyes on the lines, keener with each padlock, winning
  /// in the jump, then the idle of the resting frame.
  static ThanksFace face(double t, {required int count}) {
    final jump = glad(count);
    if (t < firstOpen) {
      return (
        from: HeroFace.glad,
        to: HeroFace.watching,
        blend: phase(t, 0.12, 0.3),
      );
    }
    if (t < jump) {
      return (
        from: HeroFace.watching,
        to: HeroFace.keen,
        blend: phase(t, firstOpen, jump - 0.1),
      );
    }
    if (t < end - 0.4) {
      return (
        from: HeroFace.keen,
        to: HeroFace.winning,
        blend: phase(t, jump, jump + 0.12),
      );
    }
    if (t < end) {
      return (
        from: HeroFace.winning,
        to: HeroFace.proud,
        blend: phase(t, end - 0.4, end - 0.1),
      );
    }
    return thanksIdleFace(t - end, rest: HeroFace.proud, now: HeroFace.glad);
  }

  /// How far in the headline is at [t], 0 to 1: it lands with the jump.
  static double headlineIn(double t, {required int count}) =>
      phase(t, glad(count) + 0.08, glad(count) + 0.36);

  /// How far the disc behind the mascot has grown at [t], 0 to 1, and how
  /// far the one ring that leaves it has gone, 0 to 1. At one the ring is
  /// gone.
  static double disc(double t, {required int count}) =>
      AppCurves.easeBack.transform(phase(t, glad(count), glad(count) + 0.34));
  static double ring(double t, {required int count}) =>
      phase(t, glad(count) + 0.1, glad(count) + 0.7);
}

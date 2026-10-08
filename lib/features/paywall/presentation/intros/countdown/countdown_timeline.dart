import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/intros/intro_parts.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';

// The countdown, as numbers. A film leader counts three, two, and the
// mascot will not wait for one: it drops in on the number and flattens it.

/// The joke's timeline. Every value is a pure function of the seconds
/// since the screen appeared.
abstract final class CountdownTimeline {
  /// The seconds each number gets.
  static const double count = 0.45;

  /// The two and the one come up.
  static const double two = count;
  static const double one = 2 * count;

  /// The mascot lands on the one.
  static const double squash = 1.06;

  /// The screen starts to sweep away. A tap during the joke jumps here.
  static const double reveal = 1.5;

  /// The layout's own entrance starts. The mascot is gone by now.
  static const double handover = 1.84;

  /// Nothing of the joke is drawn from here on.
  static const double end = 1.92;

  /// The number on screen at [t]: 3, 2, then 1. Zero once it is flattened
  /// and gone.
  static int number(double t) {
    if (t >= squash + 0.08) return 0;
    if (t >= one) return 1;
    return t >= two ? 2 : 3;
  }

  /// How far round the ring the hand is for the number on screen at [t],
  /// 0 to 1. It stops where the mascot lands.
  static double sweep(double t) {
    if (t >= squash) return (squash - one) / count;
    return (t - (t / count).floorToDouble() * count) / count;
  }

  /// How far through coming up the number on screen is at [t], 0 to 1.
  static double numberIn(double t) {
    final since = t >= one ? t - one : (t >= two ? t - two : t);
    return phase(since, 0, 0.14);
  }

  /// How flat the one is at [t], 0 to 1. At one it is a line.
  static double flat(double t) => phase(t, squash - 0.04, squash + 0.05);

  /// How far the mascot has dropped at [t], 0 to 1: it speeds up, as a
  /// thing dropped does. Zero is above the screen and one is on the number.
  static double fall(double t) {
    final p = phase(t, one + 0.04, squash);
    return p * p;
  }

  /// How far through its landing the mascot is at [t], 0 to 1 and back:
  /// one squat as it hits.
  static double squat(double t) =>
      math.sin(math.pi * phase(t, squash, squash + 0.24));

  /// How far out the ring has burst at [t], 0 to 1. At one it is gone.
  static double burst(double t) => phase(t, squash, squash + 0.3);

  /// The face at [t]: set on it as it drops, cheeky once it has landed,
  /// glad on the way out.
  static IntroFaceBlend face(double t) {
    if (t < reveal) {
      return (
        from: FaceState.determined,
        to: FaceState.cheeky,
        blend: phase(t, squash + 0.08, squash + 0.22),
      );
    }
    return (
      from: FaceState.cheeky,
      to: FaceState.happy,
      blend: phase(t, reveal, reveal + 0.18),
    );
  }

  /// How far in the line is at [t], 0 to 1.
  static double line(double t) => phase(t, squash + 0.1, squash + 0.26);

  /// How much of the line is left at [t], 1 to 0. It is gone before the
  /// hand over.
  static double words(double t) => 1 - phase(t, reveal, reveal + 0.16);

  /// How much of the screen the hand has swept away at [t], 0 to 1: once
  /// round from the top, about the mascot.
  static double wipe(double t) => phase(t, reveal, end);

  /// How far out the mascot is at [t], 0 to 1. One by the hand over.
  static double leave(double t) => phase(t, handover - 0.26, handover);

  /// True once nothing of the joke is drawn.
  static bool isOver(double t) => t >= end;
}

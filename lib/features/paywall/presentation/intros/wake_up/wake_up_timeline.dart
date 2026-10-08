import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/intros/intro_parts.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';

// The rude awakening, as numbers. It is night and the mascot is asleep. A
// small message drops on its head, it wakes with a start, and the night
// rolls up off the layout like a blind. Nothing rings.

/// The joke's timeline. Every value is a pure function of the seconds
/// since the screen appeared.
abstract final class WakeUpTimeline {
  /// The message comes into view above the mascot.
  static const double drop = 0.38;

  /// It lands on the mascot's head.
  static const double bonk = 0.8;

  /// The mascot says it is up.
  static const double up = 0.95;

  /// The night starts to roll up. A tap during the joke jumps here.
  static const double reveal = 1.36;

  /// The layout's own entrance starts. The mascot is gone by now.
  static const double handover = 1.7;

  /// Nothing of the joke is drawn from here on.
  static const double end = 1.78;

  /// The widest the mascot rocks when it is hit, in radians: four degrees.
  static const double rockReach = 4 * math.pi / 180;

  /// How deep in a breath the sleeping mascot is at [t], -1 to 1. Level
  /// from the hit on.
  static double breath(double t) =>
      t >= bonk ? 0 : math.sin(2 * math.pi * t / bonk);

  /// How far the message has fallen at [t], 0 to 1: it speeds up, as a
  /// thing dropped does. One is on the mascot's head.
  static double fall(double t) {
    final p = phase(t, drop, bonk);
    return p * p;
  }

  /// How far the message has bounced away at [t], 0 to 1. At one it is
  /// gone.
  static double bounce(double t) => phase(t, bonk, bonk + 0.32);

  /// How high the mascot is in its start at [t], 0 to 1 and back.
  static double jolt(double t) =>
      math.sin(math.pi * phase(t, bonk, bonk + 0.3));

  /// How far the mascot rocks at [t], in radians. It dies away and ends
  /// at zero.
  static double rock(double t) {
    if (t <= bonk || t >= bonk + 0.36) return 0;
    final fade = 1 - phase(t, bonk, bonk + 0.36);
    return rockReach * fade * math.sin(2 * math.pi * 9 * (t - bonk));
  }

  /// The face at [t]: dozing, shocked awake, wide eyed, glad on the way
  /// out.
  static IntroFaceBlend face(double t) {
    if (t < up) {
      return (
        from: FaceState.dozing,
        to: FaceState.shocked,
        blend: phase(t, bonk, bonk + 0.06),
      );
    }
    if (t < reveal) {
      return (
        from: FaceState.shocked,
        to: FaceState.wakesUp,
        blend: phase(t, up, up + 0.14),
      );
    }
    return (
      from: FaceState.wakesUp,
      to: FaceState.happy,
      blend: phase(t, reveal, reveal + 0.18),
    );
  }

  /// How far in the line is at [t], 0 to 1.
  static double line(double t) => phase(t, up, up + 0.16);

  /// How much of the line is left at [t], 1 to 0. It is gone before the
  /// hand over.
  static double words(double t) => 1 - phase(t, reveal, reveal + 0.16);

  /// How much of the night has rolled up at [t], 0 to 1, from the bottom
  /// of the screen to the top. It is all but gone by the hand over: the
  /// layout's mascot comes up in the open.
  static double wipe(double t) => phase(t, reveal, end);

  /// How far out the mascot is at [t], 0 to 1. One by the hand over.
  static double leave(double t) => phase(t, handover - 0.26, handover);

  /// True once nothing of the joke is drawn.
  static bool isOver(double t) => t >= end;
}

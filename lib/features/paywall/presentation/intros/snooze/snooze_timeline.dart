import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/intros/intro_parts.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:flutter/animation.dart';

// The snooze snack, as numbers. A finger goes for a Snooze button three
// times. The button dodges twice, and the third time the mascot eats it.
// Everything is worked out from the intro's clock.

/// The joke's timeline. Every value is a pure function of the seconds
/// since the screen appeared.
abstract final class SnoozeTimeline {
  /// The finger gets to the button and the button hops away to the left.
  static const double dodgeLeft = 0.42;

  /// The finger gets there again and the button hops away to the right.
  static const double dodgeRight = 0.84;

  /// The third go: the button jumps for the mascot's open mouth.
  static const double jump = 1.2;

  /// The button is swallowed and the mouth shuts.
  static const double gulp = 1.42;

  /// The screen starts to drop away. A tap during the joke jumps here.
  static const double reveal = 1.62;

  /// The layout's own entrance starts. The mascot is gone by now.
  static const double handover = 1.96;

  /// Nothing of the joke is drawn from here on.
  static const double end = 2.04;

  /// Where the button is from side to side at [t]: 0 is under the mascot,
  /// -1 one hop to the left, 1 one hop to the right.
  static double buttonSide(double t) {
    final left = AppCurves.easeBack.transform(
      phase(t, dodgeLeft, dodgeLeft + 0.18),
    );
    final right = AppCurves.easeBack.transform(
      phase(t, dodgeRight, dodgeRight + 0.2),
    );
    final home = Curves.easeIn.transform(phase(t, jump, gulp));
    return (-left + 2 * right) * (1 - home);
  }

  /// How high the button is in a hop at [t], 0 to 1. It is back down
  /// before the next one.
  static double buttonHop(double t) =>
      math.sin(math.pi * phase(t, dodgeLeft, dodgeLeft + 0.18)) +
      math.sin(math.pi * phase(t, dodgeRight, dodgeRight + 0.2));

  /// How far the button is on its way into the mouth at [t], 0 to 1. At
  /// one it is gone.
  static double swallowed(double t) => phase(t, jump, gulp);

  /// Where the finger is at [t], in the button's own measures: `side` as
  /// [buttonSide], and `below` in button heights under the button's row.
  /// It always arrives where the button just was.
  static ({double side, double below}) finger(double t) {
    final first = Curves.easeOut.transform(phase(t, 0, dodgeLeft));
    final second = Curves.easeInOut.transform(
      phase(t, dodgeLeft + 0.12, dodgeRight),
    );
    final third = Curves.easeInOut.transform(
      phase(t, dodgeRight + 0.12, jump),
    );
    final side = 1.6 * (1 - first) - second + 2 * third;
    return (side: side, below: 2.4 * (1 - first));
  }

  /// How much of the finger shows at [t], 1 to 0. It gives up once the
  /// button is eaten.
  static double fingerPresence(double t) => 1 - phase(t, gulp, gulp + 0.18);

  /// The face at [t]: drowsy, then watching the finger, doubtful, mouth
  /// wide for the button, cheeky once it is gone, glad on the way out.
  static IntroFaceBlend face(double t) {
    if (t < dodgeRight) {
      return (
        from: FaceState.sleepy,
        to: FaceState.curious,
        blend: phase(t, dodgeLeft, dodgeLeft + 0.14),
      );
    }
    if (t < jump) {
      return (
        from: FaceState.curious,
        to: FaceState.skeptical,
        blend: phase(t, dodgeRight, dodgeRight + 0.14),
      );
    }
    if (t < gulp) {
      return (
        from: FaceState.skeptical,
        to: FaceState.yawn,
        blend: phase(t, jump, jump + 0.1),
      );
    }
    if (t < reveal) {
      return (
        from: FaceState.yawn,
        to: FaceState.cheeky,
        blend: phase(t, gulp, gulp + 0.12),
      );
    }
    return (
      from: FaceState.cheeky,
      to: FaceState.happy,
      blend: phase(t, reveal, reveal + 0.18),
    );
  }

  /// How far through the gulp the mascot is at [t], 0 to 1 and back: one
  /// small swell as the button goes down.
  static double swell(double t) =>
      math.sin(math.pi * phase(t, gulp, gulp + 0.18));

  /// How far in the line is at [t], 0 to 1.
  static double line(double t) => phase(t, gulp + 0.04, gulp + 0.2);

  /// How much of the line is left at [t], 1 to 0. It is gone before the
  /// hand over.
  static double words(double t) => 1 - phase(t, reveal, reveal + 0.16);

  /// How far the screen has dropped away at [t], 0 to 1. It falls off the
  /// bottom, faster as it goes, and is all but gone by the hand over: the
  /// layout's mascot comes up in the open.
  static double wipe(double t) {
    final p = phase(t, reveal, end);
    return p * p;
  }

  /// How far out the mascot is at [t], 0 to 1. One by the hand over.
  static double leave(double t) => phase(t, handover - 0.26, handover);

  /// True once nothing of the joke is drawn.
  static bool isOver(double t) => t >= end;
}

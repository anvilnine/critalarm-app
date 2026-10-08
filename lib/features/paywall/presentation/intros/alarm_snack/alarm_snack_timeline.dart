import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/intros/intro_parts.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:flutter/animation.dart';

// The alarm snack, as numbers. The screen looks like an alarm with a Snooze
// button under it. A finger goes for the button, the button hops away
// twice, and on the third go the mascot eats it: the ringing stops dead.
// Then the red gives way to whichever layout was chosen. Everything is
// worked out from the intro's clock.

/// The joke's timeline. Every value is a pure function of the seconds
/// since the screen appeared.
abstract final class AlarmSnackTimeline {
  /// How long one ring of the picture lasts. The screen rings three times,
  /// and the button hops as each new ring starts.
  static const double ringPeriod = 0.43;

  /// The finger gets to the button and the button hops away to the left.
  static const double dodgeLeft = 0.43;

  /// The finger gets there again and the button hops away to the right.
  static const double dodgeRight = 0.86;

  /// The third go: the button jumps for the mascot's open mouth.
  static const double jump = 1.09;

  /// The button is swallowed, the mouth shuts and the ringing stops dead.
  static const double gulp = 1.29;

  /// The red starts to give way. A tap during the joke jumps here.
  static const double reveal = 1.62;

  /// The layout's own entrance starts, under the last of the red.
  static const double handover = 1.9;

  /// Nothing of the joke is drawn from here on.
  static const double end = 2.12;

  /// The widest the mascot leans in a ring, in radians: five degrees.
  static const double shakeReach = 5 * math.pi / 180;

  /// How hard it rings at [t], 0 to 1: one swell for each ring, and
  /// nothing from the [gulp] on.
  static double ringing(double t) {
    if (t <= 0 || t >= gulp) return 0;
    final local = loopT(t, ringPeriod) / ringPeriod;
    final swell = math.sin(math.pi * local);
    return swell * swell;
  }

  /// How far the mascot leans at [t], in radians. It is zero from the
  /// [gulp] on.
  static double shake(double t) =>
      shakeReach * ringing(t) * math.sin(2 * math.pi * 11 * t);

  /// How far out pulse ring [index] (0 or 1) is at [t], 0 to 1, or null
  /// when it is not drawn. None is drawn from the [gulp] on: the rings
  /// stop with the ringing.
  static double? pulse(int index, double t) {
    const period = 0.6;
    if (t >= gulp) return null;
    final local = t - index * period / 2;
    if (local < 0) return null;
    return loopT(local, period) / period;
  }

  /// Where the button is from side to side at [t]: 0 is under the word,
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

  /// How large the button is drawn at [t], 1 to 0. It stays a button for
  /// most of the way and shrinks as it gets to the mouth.
  static double buttonScale(double t) =>
      1 - math.pow(swallowed(t), 3).toDouble();

  /// Where the finger is at [t], in the button's own measures: `side` as
  /// [buttonSide], and `below` in button heights under the button's row.
  /// It always arrives where the button just was.
  static ({double side, double below}) finger(double t) {
    final first = Curves.easeOut.transform(phase(t, 0, dodgeLeft));
    final second = Curves.easeInOut.transform(
      phase(t, dodgeLeft + 0.12, dodgeRight),
    );
    final third = Curves.easeInOut.transform(
      phase(t, dodgeRight + 0.1, jump),
    );
    final side = 1.6 * (1 - first) - second + 2 * third;
    return (side: side, below: 1.6 * (1 - first));
  }

  /// How much of the finger shows at [t], 1 to 0. It gives up once the
  /// button is eaten.
  static double fingerPresence(double t) => 1 - phase(t, gulp, gulp + 0.18);

  /// The face at [t]: ringing, an eye on the button as it hops a second
  /// time, mouth wide for it, cheeky once it is gone, glad on the way out.
  static IntroFaceBlend face(double t) {
    if (t < jump) {
      return (
        from: FaceState.alarmed,
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
      blend: phase(t, reveal, reveal + 0.2),
    );
  }

  /// How far through the gulp the mascot is at [t], 0 to 1 and back: one
  /// small swell as the button goes down.
  static double swell(double t) =>
      math.sin(math.pi * phase(t, gulp, gulp + 0.18));

  /// Whether the big word still reads as an alarm at [t]. After it the
  /// line stands in its place.
  static bool saysAlarm(double t) => t < gulp;

  /// How far in the line is at [t], 0 to 1.
  static double line(double t) => phase(t, gulp + 0.05, gulp + 0.21);

  /// How much of the line is left at [t], 1 to 0. It is gone by the hand
  /// over, so no word of the joke lies over the layout as it comes in.
  static double words(double t) => 1 - phase(t, reveal + 0.1, handover);

  /// How much of the screen the red has given back to the layout under it
  /// at [t], 0 to 1. It opens from where the mascot stands.
  static double wipe(double t) => phase(t, reveal, reveal + 0.4);

  /// How far out the mascot is at [t], 0 to 1. It travels to where the
  /// layout's own mascot stands and is gone by the hand over, so two faces
  /// are never on screen together.
  static double leave(double t) => phase(t, reveal, handover);

  /// True once nothing of the joke is drawn.
  static bool isOver(double t) => t >= end;
}

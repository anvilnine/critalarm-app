import 'dart:math' as math;

import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';

// The false alarm intro, as numbers. The alarm red floods out from where
// the mascot stands, the mascot pops up and the big word lands. The screen
// rings for about a second, the mascot blinks, admits it, and the red gives
// way to whichever layout was chosen. Everything is worked out from the intro's
// clock, so any second of it can be drawn and tested alone.

/// The faces the large mascot makes during the joke.
enum FalseAlarmFace { alarmed, sheepish, glad }

/// The joke's timeline. Every value is a pure function of the seconds
/// since the screen appeared.
abstract final class FalseAlarmTimeline {
  /// The entrance is over and the ringing starts: the red covers the
  /// screen, the mascot stands at its full size and the word is up.
  static const double ringStart = 0.45;

  /// How long it rings: two bursts.
  static const double ringSeconds = 0.9;

  /// The ringing stops: the shake is back at zero and no new ring starts.
  static const double ringEnd = ringStart + ringSeconds;

  /// The admission lands and the mascot looks sheepish.
  static const double admit = ringEnd + 0.1;

  /// The red starts to give way. A tap during the joke jumps here.
  static const double reveal = admit + 0.35;

  /// The layout's own entrance starts, under the last of the red.
  static const double handover = reveal + 0.25;

  /// Nothing of the joke is drawn from here on.
  static const double end = handover + 0.25;

  /// The widest the mascot leans in a ring, in radians: five degrees.
  static const double shakeReach = 5 * math.pi / 180;

  /// How much of the screen the red has taken at [t], 0 to 1. It floods
  /// out in a circle from where the mascot stands, and has all of it well
  /// before the ringing starts.
  static double flood(double t) => phase(t, 0, 0.38);

  /// How far the mascot has come up at [t], 0 to 1. It starts a moment
  /// after the red, so it pops up on red and never on the bare screen.
  static double arrive(double t) => phase(t, 0.08, 0.42);

  /// How far in the big word is at [t], 0 to 1. It lands last, as the
  /// ringing starts.
  static double wordIn(double t) => phase(t, 0.26, ringStart);

  /// How hard it rings at [t], 0 to 1: two bursts, as a phone rings twice.
  /// Nothing before [ringStart] and nothing from [ringEnd] on.
  static double ringing(double t) {
    if (t <= ringStart || t >= ringEnd) return 0;
    const burst = ringSeconds / 2;
    final local = loopT(t - ringStart, burst) / burst;
    final swell = math.sin(math.pi * local);
    return swell * swell;
  }

  /// How far the mascot leans at [t], in radians. It starts at zero, ends
  /// at zero and stays there.
  static double shake(double t) =>
      shakeReach * ringing(t) * math.sin(2 * math.pi * 11 * (t - ringStart));

  /// How far out pulse ring [index] (0 or 1) is at [t], 0 to 1, or null
  /// when it is not drawn. None is drawn before [ringStart]. A ring that
  /// started before [ringEnd] finishes.
  static double? ring(int index, double t) {
    const period = 0.6;
    final local = t - ringStart - index * period / 2;
    if (local < 0) return null;
    final started = (local / period).floorToDouble() * period;
    if (started + index * period / 2 >= ringSeconds - 1e-9) return null;
    return (local - started) / period;
  }

  /// How far shut the eyes are at [t], 0 to 1: one blink as the ringing
  /// stops, the beat before the admission.
  static double blink(double t) {
    final p = phase(t, ringEnd - 0.04, admit + 0.06);
    return p >= 1 ? 0 : math.sin(math.pi * p);
  }

  /// The face at [t]: where it is going, where from, and how far along.
  static ({FalseAlarmFace from, FalseAlarmFace to, double blend}) face(
    double t,
  ) {
    if (t < reveal) {
      return (
        from: FalseAlarmFace.alarmed,
        to: FalseAlarmFace.sheepish,
        blend: phase(t, ringEnd, admit),
      );
    }
    return (
      from: FalseAlarmFace.sheepish,
      to: FalseAlarmFace.glad,
      blend: phase(t, reveal, reveal + 0.2),
    );
  }

  /// Whether the big word still reads as an alarm at [t]. After it the
  /// admission stands in its place.
  static bool saysAlarm(double t) => t < admit;

  /// How far in the admission is at [t], 0 to 1.
  static double admission(double t) => phase(t, admit, admit + 0.18);

  /// How much of the screen the red has given back to the layout under it
  /// at [t], 0 to 1. It opens from where the mascot stands.
  static double wipe(double t) => phase(t, reveal, reveal + 0.4);

  /// How much of the admission is left at [t], 1 to 0. It is gone by the
  /// hand over, so no word of the joke lies over the layout as it comes in.
  static double words(double t) => 1 - phase(t, reveal + 0.1, handover);

  /// How far out the large mascot is at [t], 0 to 1. It travels to where
  /// the layout's own mascot stands and is gone by the hand over, so two
  /// faces are never on screen together.
  static double leave(double t) => phase(t, reveal, handover);

  /// True once nothing of the joke is drawn.
  static bool isOver(double t) => t >= end;

  /// The second a tap at [t] moves the clock to: the reveal while the joke
  /// plays, and no change after it.
  static double skip(double t) => t < reveal ? reveal : t;
}

import 'dart:math' as math;
import 'dart:ui';

import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_arrangement.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_turns.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';

// The joke the False alarm paywall opens with, as numbers. The screen looks
// like an alarm for about a second, the mascot blinks, admits it, and the
// red gives way to the offer. Everything is worked out from the clock, so
// the frame after the joke is simply a later second.

/// The faces the large mascot makes during the joke.
enum FalseAlarmFace { alarmed, sheepish, glad }

/// The joke's timeline. Every value is a pure function of the seconds
/// since the screen appeared.
abstract final class FalseAlarmTimeline {
  /// The ringing stops: the shake is back at zero and no new ring starts.
  static const double ringEnd = 0.9;

  /// The admission lands and the mascot looks sheepish.
  static const double admit = 1;

  /// The red starts to give way. A tap during the joke jumps here.
  static const double reveal = 1.25;

  /// The offer's own entrance starts: the loop's prelude.
  static const double prelude = 1.5;

  /// The buy block comes in, once the red has left the foot of the screen.
  static const double buyBlockAt = 1.6;

  /// Nothing of the joke is drawn from here on.
  static const double end = 1.75;

  /// The second a still screen rests on: the offer, after its entrance.
  static const double restAt = prelude + heroEntranceSeconds;

  /// The widest the mascot leans in a ring, in radians: five degrees.
  static const double shakeReach = 5 * math.pi / 180;

  /// How hard it rings at [t], 0 to 1: two bursts, as a phone rings twice,
  /// and nothing from [ringEnd] on.
  static double ringing(double t) {
    if (t <= 0 || t >= ringEnd) return 0;
    const burst = ringEnd / 2;
    final local = loopT(t, burst) / burst;
    final swell = math.sin(math.pi * local);
    return swell * swell;
  }

  /// How far the mascot leans at [t], in radians. It ends at zero and
  /// stays there.
  static double shake(double t) =>
      shakeReach * ringing(t) * math.sin(2 * math.pi * 11 * t);

  /// How far out pulse ring [index] (0 or 1) is at [t], 0 to 1, or null
  /// when it is not drawn. A ring that started before [ringEnd] finishes.
  static double? ring(int index, double t) {
    const period = 0.6;
    final local = t - index * period / 2;
    if (local < 0) return null;
    final started = (local / period).floorToDouble() * period;
    if (started + index * period / 2 >= ringEnd - 1e-9) return null;
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

  /// How much of the screen the stage tone has taken back from the red at
  /// [t], 0 to 1.
  static double wipe(double t) => phase(t, reveal, reveal + 0.4);

  /// How much of the large mascot and its line is left at [t], 1 to 0. It
  /// goes as the offer's own mascot comes up.
  static double presence(double t) => 1 - phase(t, prelude - 0.05, end);

  /// True once nothing of the joke is drawn.
  static bool isOver(double t) => t >= end;

  /// Whether the buy block is on screen at [t].
  static bool showsBuyBlock(double t) => t >= buyBlockAt;

  /// The second a tap at [t] moves the clock to: the reveal while the joke
  /// plays, and no change after it.
  static double skip(double t) => t < reveal ? reveal : t;
}

/// Where the "just kidding" tag may stand on the stage: the air to the
/// right of the mascot and above the card, clear of the close cross in the
/// top right corner. Null when there is no such room, and the tag is left
/// out.
///
/// [stage] is the stage's size and [arrangement] what stands on it.
/// [crossSize] is the square the cross takes from the top right corner.
Rect? falseAlarmTagRoom({
  required Size stage,
  required HeroArrangement arrangement,
  double crossSize = 48,
  double minWidth = 110,
  double minHeight = 40,
}) {
  if (arrangement.kind != HeroStageKind.pair) return null;
  final mascot = arrangement.mascot;
  final card = arrangement.card;
  final left = mascot.right + 8;
  final bottom = card.top - 8;
  final right = stage.width - heroSideRoom;
  if (right - left < minWidth) return null;

  // Under the cross when that leaves a tag's height, beside it otherwise.
  final under = Rect.fromLTRB(
    left,
    math.max(mascot.top, crossSize),
    right,
    bottom,
  );
  if (under.height >= minHeight + 12) return under;
  final beside = Rect.fromLTRB(
    left,
    math.max(mascot.top, 4),
    math.min(right, stage.width - crossSize),
    bottom,
  );
  if (beside.width < minWidth || beside.height < minHeight) return null;
  return beside;
}

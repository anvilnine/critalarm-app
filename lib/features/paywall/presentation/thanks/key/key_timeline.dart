import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

// The key version, as numbers. The pressed button becomes a key and flies
// up to the mascot, which catches it and pushes it into one big lock. The
// key turns a quarter on the purchase cue's peak and the shackle springs.
// Once the cue is over the mascot gives the key its second quarter, which
// is heard, the lock falls open, and what was bought comes out of it, one
// token a line.
//
// The times follow the purchase cue, which starts at zero: a click, a
// short pick up, one big swell that starts at 0.4 and peaks at 0.6, and a
// long tail that is over by 2.2.

/// Where the key version puts its lock, its mascot and its words on one
/// phone. The lock and the mascot stand on one floor, the mascot in front
/// and a little over the lock's side, and the block sits a little under the
/// middle of the room above the button, so the mascot has air to jump in
/// and the lines end near the button.
@immutable
class KeyStage {
  const KeyStage({required this.stage, required this.body});

  factory KeyStage.of({
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
    // The lock's body is one unit wide. With its shackle up it stands
    // 1.4 units, and the gap under the floor is a third of one.
    final unit = ((room.height * 0.9 - wordsHeight) / (tall + gap)).clamp(
      size.width * 0.2,
      size.width * 0.44,
    );
    final block = unit * (tall + gap) + wordsHeight;
    final floor =
        room.top + math.max(0, room.height - block) * 0.56 + unit * tall;
    final edge = unit * critEdge;
    final width = unit * (1 - overlap) + edge;
    final left = (size.width - width) / 2;
    final crit = Rect.fromLTWH(
      left + unit * (1 - overlap),
      floor - edge,
      edge,
      edge,
    );
    return KeyStage(
      stage: ThanksStage(
        crit: crit,
        words: Rect.fromLTRB(
          thanksSideInset,
          floor + unit * gap,
          size.width - thanksSideInset,
          room.bottom,
        ),
        headlineSize: headlineSize,
        lineSize: lineSize,
        rowGap: rowGap,
      ),
      body: Rect.fromLTWH(left, floor - unit * bodyTall, unit, unit * bodyTall),
    );
  }

  /// How tall the open lock stands, in units of its body's width.
  static const double tall = 1.4;

  /// The body's own height, in units.
  static const double bodyTall = 0.8;

  /// The air between the floor and the headline, in units.
  static const double gap = 0.34;

  /// The mascot's edge, in units, and how much of the lock's width it
  /// stands in front of.
  static const double critEdge = 1.14;
  static const double overlap = 0.2;

  /// How far the body hangs over the floor until the lock falls open, in
  /// units.
  static const double hang = 0.1;

  /// The mascot's box and the words, for the shared parts.
  final ThanksStage stage;

  /// The lock's body where it rests, on the floor.
  final Rect body;

  double get unit => body.width;
  double get floor => body.bottom;

  /// The middle of the keyhole with the body [dropped] of the way down to
  /// the floor, 0 to 1.
  Offset keyhole(double dropped) => Offset(
    body.left + unit * 0.42,
    body.top + unit * 0.44 - unit * hang * (1 - dropped),
  );

  /// Where the mascot holds the key once it has caught it: at its side,
  /// toward the lock.
  Offset get hand => Offset(
    stage.crit.left - unit * 0.02,
    stage.crit.center.dy - unit * 0.34,
  );

  /// The middle of the mark that leads line [index], given how wide the
  /// widest line is written, so a token can fly to it.
  Offset mark(int index, {required double widest, double textScale = 1}) {
    final row =
        math.max(ThanksStage.markSize, stage.lineSize * 1.3 * textScale) +
        stage.rowGap;
    final block = math.min(
      stage.words.width,
      ThanksStage.markSize + Spacing.s3 + widest,
    );
    return Offset(
      stage.words.left +
          (stage.words.width - block) / 2 +
          ThanksStage.markSize / 2,
      stage.words.top +
          stage.headlineSize * 1.15 * textScale +
          ThanksStage.headlineGap +
          index * row +
          (row - stage.rowGap) / 2,
    );
  }
}

/// The show's timeline. Every value is a pure function of the seconds
/// since the purchase was confirmed.
abstract final class KeyTimeline {
  /// The paywall under the show is covered.
  static const double cover = 0.36;

  /// The pressed button has become the key, on the cue's click.
  static const double forged = 0.12;

  /// The mascot stays where the layout had it until the cover has passed
  /// under it.
  static const double setOff = 0.14;

  /// The key reaches the mascot, which hops for it.
  static const double caught = 0.36;

  /// The mascot pushes the key at the lock, as the swell starts.
  static const double push = 0.4;

  /// The key is in the keyhole.
  static const double seated = 0.52;

  /// The first quarter turn, on the swell's peak.
  static const double turn = 0.6;

  /// The shackle springs up.
  static const double spring = 0.72;

  /// The mascot jumps for it, and is back on the floor.
  static const double glad = 0.8;
  static const double landed = 1.2;

  /// The headline, and the first line, which comes in as a promise.
  static const double headline = 0.86;
  static const double firstLine = 0.98;

  /// The host's button is on.
  static const double button = 1.1;

  /// The second quarter turn, once the purchase cue is over. It is heard.
  static const double secondTurn = 2.25;

  /// The lock falls open: its body drops to the floor. It is heard.
  static const double fall = 2.52;

  /// The first token leaves the lock.
  static const double firstToken = 2.62;

  /// How long one token is in the air.
  static const double flight = 0.28;

  /// The resting frame.
  static const double end = 3.6;

  /// The seconds between two tokens with [lines] lines.
  static double tokenEvery(int lines) =>
      lines <= 1 ? 0 : math.min(0.13, 0.5 / (lines - 1));

  /// The second token [index] of [lines] leaves the lock, and lands.
  static double tokenAt(int index, int lines) =>
      firstToken + index * tokenEvery(lines);
  static double tokenLands(int index, int lines) =>
      tokenAt(index, lines) + flight;

  /// How far the cover has grown out of the button at [t], 0 to 1.
  static double covered(double t) =>
      Curves.easeOutCubic.transform(phase(t, 0, cover));

  /// The size of the pressed button at [t] against its own: it draws in to
  /// the point the key comes from.
  static double pressed(double t) =>
      1 - Curves.easeIn.transform(phase(t, 0, forged));

  /// The size of the key at [t] against its own: it grows out of the
  /// button as that goes.
  static double forge(double t) =>
      AppCurves.easeBack.transform(phase(t, 0.03, forged + 0.06));

  /// How far the key is from the button to the mascot's hand at [t], 0 to
  /// 1, and how far it has spun on the way, in radians. It lands level.
  static double thrown(double t) =>
      Curves.easeInOut.transform(phase(t, 0.06, caught));
  static double spin(double t) => 2 * math.pi * (1 - thrown(t));

  /// How far the key is from the hand into the keyhole at [t], 0 to 1.
  static double seat(double t) =>
      Curves.easeIn.transform(phase(t, push, seated));

  /// How many quarter turns the key has made at [t]: none, one on the
  /// peak, and two at rest, which is upright again.
  static double turned(double t) =>
      AppCurves.easeBack.transform(phase(t, turn - 0.07, turn + 0.07)) +
      AppCurves.easeBack.transform(phase(t, secondTurn, secondTurn + 0.16));

  /// How far the shackle has sprung at [t], 0 to 1.
  static double sprung(double t) =>
      AppCurves.easeBack.transform(phase(t, spring, spring + 0.16));

  /// How far the body has dropped to the floor at [t], 0 to 1, with the
  /// bounce it lands with.
  static double dropped(double t) =>
      Curves.bounceOut.transform(phase(t, fall, fall + 0.34));

  /// How far the lock leans as it is worked, in radians: a short shake at
  /// each turn and as the shackle springs. Zero at rest.
  static double shake(double t) {
    double at(double from, double size) {
      final p = phase(t, from, from + 0.3);
      if (p <= 0 || p >= 1) return 0;
      return size * math.sin(3 * math.pi * p) * (1 - p);
    }

    return at(turn - 0.04, 0.05) + at(spring, 0.07) + at(secondTurn, 0.05);
  }

  /// How far the mascot is from where the layout had it to the stage at
  /// [t], 0 to 1. There before the key is.
  static double travel(double t) =>
      Curves.easeInOutCubic.transform(phase(t, setOff, caught - 0.03));

  /// How far the mascot leans in at the lock at [t], 0 to 1: with each
  /// turn of the key, and back.
  static double reach(double t) {
    double at(double out, double there, double back) {
      if (t < out || t > back + 0.16) return 0;
      if (t < there) return Curves.easeOut.transform(phase(t, out, there));
      return 1 - Curves.easeInOut.transform(phase(t, back, back + 0.16));
    }

    return math.max(
      at(push, seated, turn + 0.06),
      at(secondTurn - 0.14, secondTurn, secondTurn + 0.1),
    );
  }

  /// How high the mascot is at [t], as a share of its own height: a hop
  /// for the catch, the jump when the shackle springs, a smaller one as
  /// the lock falls open, then a nod for each token.
  static double lift(double t, {required int lines}) {
    if (t >= caught - 0.1 && t < caught + 0.04) {
      return 0.1 * thanksArc(phase(t, caught - 0.1, caught + 0.04));
    }
    if (t >= glad && t < landed) {
      return 0.42 * thanksArc(phase(t, glad, landed));
    }
    if (t >= fall && t < fall + 0.1) {
      return 0.12 * thanksArc(phase(t, fall, fall + 0.1));
    }
    for (var i = 0; i < lines; i++) {
      final at = tokenLands(i, lines);
      if (t >= at && t < at + 0.12) {
        return 0.05 * thanksArc(phase(t, at, at + 0.12));
      }
    }
    return 0;
  }

  /// The mascot's height against its rest height at [t]: down before the
  /// jump and as it lands, one everywhere else.
  static double stretch(double t) {
    if (t < glad - 0.1) return 1;
    if (t < glad) return 1 - 0.14 * phase(t, glad - 0.1, glad);
    if (t < landed) {
      return 0.86 + 0.14 * Curves.easeOut.transform(phase(t, glad, glad + 0.1));
    }
    final p = phase(t, landed, landed + 0.28);
    return 1 - 0.2 * math.sin(math.pi * p) * (1 - p);
  }

  /// The face at [t]: eyes on the key, keen at the lock, winning when it
  /// gives, eyes on the lines, keen again for the second turn, winning as
  /// it all comes out, then proud, which is the idle of the resting frame.
  static ThanksFace face(double t) {
    if (t < push) {
      return (
        from: HeroFace.glad,
        to: HeroFace.arriving,
        blend: phase(t, 0.04, 0.16),
      );
    }
    if (t < spring) {
      return (
        from: HeroFace.arriving,
        to: HeroFace.keen,
        blend: phase(t, push, push + 0.1),
      );
    }
    if (t < landed + 0.1) {
      return (
        from: HeroFace.keen,
        to: HeroFace.winning,
        blend: phase(t, spring, spring + 0.1),
      );
    }
    if (t < secondTurn - 0.3) {
      return (
        from: HeroFace.winning,
        to: HeroFace.watching,
        blend: phase(t, landed + 0.1, landed + 0.3),
      );
    }
    if (t < fall) {
      return (
        from: HeroFace.watching,
        to: HeroFace.keen,
        blend: phase(t, secondTurn - 0.3, secondTurn - 0.14),
      );
    }
    if (t < end - 0.4) {
      return (
        from: HeroFace.keen,
        to: HeroFace.winning,
        blend: phase(t, fall, fall + 0.1),
      );
    }
    if (t < end) {
      return (
        from: HeroFace.winning,
        to: HeroFace.proud,
        blend: phase(t, end - 0.4, end - 0.1),
      );
    }
    return thanksIdleFace(t - end, rest: HeroFace.proud);
  }

  /// How far in the disc behind the two, the headline and each line are
  /// at [t], 0 to 1.
  static double disc(double t) =>
      AppCurves.easeBack.transform(phase(t, spring, spring + 0.34));
  static double headlineIn(double t) => phase(t, headline, headline + 0.3);
  static double lineIn(double t, int index) =>
      phase(stagger(index, t, each: 0.06, start: firstLine), 0, 0.24);

  /// How far token [index] of [lines] is from the lock to its line at
  /// [t], 0 to 1.
  static double token(double t, int index, int lines) =>
      phase(t, tokenAt(index, lines), tokenLands(index, lines));

  /// How far line [index] of [lines] is held at [t], 0 to 1: its token
  /// has landed in its mark.
  static double held(double t, int index, int lines) {
    final at = tokenLands(index, lines);
    return phase(t, at - 0.02, at + 0.18);
  }

  /// How far the one ring that leaves the lock as it falls open has gone
  /// at [t], 0 to 1. At one it is gone.
  static double ring(double t) => phase(t, fall + 0.04, fall + 0.64);
}

import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_thanks.dart';
import 'package:critalarm/features/paywall/presentation/thanks/thanks_parts.dart';
import 'package:flutter/widgets.dart';

// The stamp version, as numbers. A slip of paper shoots out of the pressed
// button and the mascot catches it. The benefits print on it one line at a
// time, a rubber stamp with the product's name lands on it, and the
// mascot holds it up.
//
// The times follow the purchase cue, which starts at zero: a click, a
// short pick up, one big swell that starts at 0.4 and peaks at 0.6, and a
// long tail that is over by 2.2. The slip is caught on the peak and the
// lines print down the tail, felt and not heard. The stamp waits for the
// cue to end, so its own thud is heard.

/// The stamp on the slip at one moment.
typedef StampMark = ({double opacity, double scale, double angle});

/// The show's timeline. Every value is a pure function of the seconds
/// since the purchase was confirmed.
abstract final class StampTimeline {
  /// The paywall under the show is covered.
  static const double cover = 0.34;

  /// The mascot stays where the layout had it until the cover has passed
  /// under it, so the layout's own is never seen beside it.
  static const double setOff = 0.14;

  /// The slip starts out of the button, on the cue's click.
  static const double feed = 0.04;

  /// The mascot has the slip, on the swell's peak.
  static const double caught = 0.6;

  /// The first line prints. Each line after it follows on the tail.
  static const double firstLine = 0.86;

  /// How long one line takes to print.
  static const double lineSeconds = 0.2;

  /// The host's button is on.
  static const double goOn = 1.1;

  /// The stamp starts down, and lands. It lands after the purchase cue is
  /// over, so it is heard.
  static const double stampFalls = 2.14;
  static const double stampAt = 2.3;

  /// The mascot jumps with the slip, and is down again.
  static const double raise = 2.54;
  static const double raised = 2.96;

  /// The resting frame.
  static const double end = 3.2;

  /// The angle the stamp rests at, in radians. It is the one thing that
  /// rests at an angle, as a stamp put down by hand does.
  static const double stampAngle = -0.12;

  /// The seconds between two lines with [lines] lines: all of them inside
  /// the cue's tail.
  static double lineEvery(int lines) =>
      lines <= 1 ? 0 : math.min(0.24, 1.0 / (lines - 1));

  /// The second line [index] of [lines] starts to print.
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
    return 1.06 * (1 - Curves.easeIn.transform(phase(t, 0.3, 0.46)));
  }

  /// How far line [index] of [lines] is printed at [t], 0 to 1.
  static double printed(double t, int index, int lines) {
    final at = lineAt(index, lines);
    return phase(t, at, at + lineSeconds);
  }

  /// The stamp at [t]: it comes down large and turned, and lands at its
  /// own size on [stampAngle], where it stays.
  static StampMark stamp(double t) {
    final fall = Curves.easeIn.transform(phase(t, stampFalls, stampAt));
    // A small give as the rubber meets the paper.
    final p = phase(t, stampAt, stampAt + 0.22);
    final give = 0.08 * math.sin(math.pi * p) * (1 - p);
    return (
      opacity: phase(t, stampFalls, stampFalls + 0.06),
      scale: 1 + 1.4 * (1 - fall) - give,
      angle: stampAngle - 0.22 * (1 - fall),
    );
  }

  /// How far the slip is pushed down by the stamp at [t], 0 to 1. Zero
  /// before it lands and soon after.
  static double pressed(double t) {
    final p = phase(t, stampAt, stampAt + 0.3);
    return math.sin(math.pi * p) * (1 - p);
  }

  /// How high the mascot is at [t], as a share of its own height: a hop
  /// as it catches the slip, a nod for each line, then the jump with the
  /// slip held up. The slip goes with it.
  static double lift(double t, {required int lines}) {
    if (t >= raise) return 0.34 * thanksArc(phase(t, raise, raised));
    if (t >= caught && t < caught + 0.24) {
      return 0.12 * thanksArc(phase(t, caught, caught + 0.24));
    }
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
    if (t < raised) {
      return 0.86 +
          0.14 * Curves.easeOut.transform(phase(t, raise, raise + 0.1));
    }
    final p = phase(t, raised, raised + 0.24);
    return 1 - 0.2 * math.sin(math.pi * p) * (1 - p);
  }

  /// The face at [t]: wide eyed as the slip comes, eyes on the lines as
  /// they print, wide eyed again under the stamp, winning in the jump,
  /// then proud, which is the idle of the resting frame.
  static ThanksFace face(double t) {
    if (t < caught) {
      return (
        from: HeroFace.glad,
        to: HeroFace.arriving,
        blend: phase(t, 0.1, 0.26),
      );
    }
    if (t < stampFalls) {
      return (
        from: HeroFace.arriving,
        to: HeroFace.watching,
        blend: phase(t, caught + 0.1, caught + 0.26),
      );
    }
    if (t < stampAt) {
      return (
        from: HeroFace.watching,
        to: HeroFace.keen,
        blend: phase(t, stampFalls, stampFalls + 0.1),
      );
    }
    if (t < end - 0.24) {
      return (
        from: HeroFace.keen,
        to: HeroFace.winning,
        blend: phase(t, stampAt + 0.04, stampAt + 0.16),
      );
    }
    if (t < end) {
      return (
        from: HeroFace.winning,
        to: HeroFace.proud,
        blend: phase(t, end - 0.24, end - 0.04),
      );
    }
    return thanksIdleFace(t - end, rest: HeroFace.proud);
  }

  /// How far in the disc behind the mascot and the headline are at [t], 0
  /// to 1. The headline lands with the stamp.
  static double disc(double t) =>
      AppCurves.easeBack.transform(phase(t, caught - 0.1, caught + 0.26));
  static double headlineIn(double t) =>
      phase(t, stampAt + 0.06, stampAt + 0.34);
}

/// Where the stamp version puts its parts on one phone: the mascot, the
/// slip it holds by the top edge, and the headline under the slip. The
/// three are centred as one block in the room above the button, and grow
/// with the room so a tall phone is used.
@immutable
class StampPlan {
  const StampPlan({
    required this.crit,
    required this.paper,
    required this.headline,
    required this.headlineSize,
    required this.unit,
    required this.lines,
  });

  factory StampPlan.of({
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
    final unit = (room.height / 687).clamp(0.78, 1.12);
    final headlineSize = size.height <= 667 ? 30.0 : 34.0;
    final headlineHeight = headlineSize * 1.15 * math.min(textScale, 1.3);
    final edge = math.min(size.width * 0.46, room.height * 0.26);
    final paperWidth = math.min(size.width - 2 * 32, 330 * unit);
    final paperHeight = paperHeightFor(lines, unit);
    final overlap = edge * holdShare;
    final gap = 20 * unit;
    final headroom = edge * 0.14;
    final block = edge - overlap + paperHeight + gap + headlineHeight;
    final spare = room.height - headroom - block;
    final top = room.top + headroom + math.max(0, spare) * 0.44;
    final crit = Rect.fromLTWH((size.width - edge) / 2, top, edge, edge);
    final paper = Rect.fromLTWH(
      (size.width - paperWidth) / 2,
      crit.bottom - overlap,
      paperWidth,
      paperHeight,
    );
    return StampPlan(
      crit: crit,
      paper: paper,
      headline: Rect.fromLTRB(
        thanksSideInset,
        paper.bottom + gap,
        size.width - thanksSideInset,
        room.bottom,
      ),
      headlineSize: headlineSize,
      unit: unit,
      lines: lines,
    );
  }

  /// How much of the mascot's height the slip's top edge covers: it is
  /// held in front.
  static const double holdShare = 0.16;

  /// The parts of the slip top down, in points at a unit of one.
  static const double lead = 18;
  static const double header = 22;
  static const double rule = 16;
  static const double row = 38;
  static const double stampRoom = 84;
  static const double tear = 12;
  static const double pad = 20;

  /// The height of a slip with [lines] lines at [unit].
  static double paperHeightFor(int lines, double unit) =>
      (lead + header + rule + row * lines + rule + stampRoom + tear) * unit;

  /// The mascot at rest.
  final Rect crit;

  /// The slip at rest.
  final Rect paper;

  /// The headline's box, under the slip.
  final Rect headline;
  final double headlineSize;

  /// What every measure of the slip is multiplied by on this phone.
  final double unit;
  final int lines;

  double get rowsTop => (lead + header + rule) * unit;
  double get rowHeight => row * unit;
  double get stampTop => rowsTop + rowHeight * lines + rule * unit;

  /// The slip's box [fed] of the way from a slot at [slotTop] to the
  /// mascot.
  Rect paperAt(double fed, double slotTop) {
    final top = slotTop + (paper.top - slotTop) * fed;
    return Rect.fromLTWH(paper.left, top, paper.width, paper.height);
  }
}

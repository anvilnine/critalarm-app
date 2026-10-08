import 'dart:math' as math;
import 'dart:ui';

import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_motion.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_turns.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_cue_rules.dart';

// The receipt as numbers: when each part of the print happens, and where
// the slot, the paper, the mascot and the card stand on the stage. No
// widget is in here, so every rule has a test.

/// What the mascot does while the slip prints, before the loop takes over.
class ReceiptActor {
  const ReceiptActor({
    required this.face,
    required this.fromFace,
    required this.faceBlend,
    required this.hop,
    required this.entrance,
  });

  final HeroFace face;
  final HeroFace fromFace;
  final double faceBlend;
  final double hop;
  final double entrance;
}

/// The stamp at one moment: how solid it is, how large, and its angle in
/// radians.
class ReceiptStamp {
  const ReceiptStamp({
    required this.opacity,
    required this.scale,
    required this.angle,
  });

  final double opacity;
  final double scale;
  final double angle;
}

/// The print, in seconds on the layout's clock. The slot is there from the
/// first frame, the mascot pops up beside it, the paper feeds out a line at
/// a time, the stamp lands, and the first preview slides out from behind
/// the paper to stand beside it. Then the loop starts.
abstract final class ReceiptTimeline {
  /// The paper starts to feed, and has all of its length.
  static const double feedStart = 0.3;
  static const double feedEnd = 1.35;

  /// The stamp comes down, and has landed.
  static const double stampAt = 1.45;
  static const double stampLanded = 1.67;

  /// The first preview slides out from behind the paper.
  static const double peekStart = 1.55;

  /// The loop's own entrance is held back this long, so its first turn
  /// starts as the print ends.
  static const double prelude = 1;

  /// The print is over: the frame that rests when nothing may move.
  static const double restAt = prelude + heroEntranceSeconds;

  /// The angle the stamp rests at, in radians. It is the one thing that
  /// rests at an angle.
  static const double stampAngle = -0.12;

  /// How far the paper swings at most while it feeds, in radians.
  static const double swayMax = 0.022;

  /// How far through the feed the clock is, 0 to 1.
  static double fed(double t) => phase(t, feedStart, feedEnd);

  /// How much of the paper is out at [t], in points, for a paper whose
  /// parts end at [stops] points down it (the last is its full length).
  ///
  /// The paper comes out a part at a time: each part gets an equal share
  /// of the feed, moves in the first two thirds of it and waits in the
  /// last, as a printer does between lines.
  static double feed(double t, List<double> stops) {
    if (stops.isEmpty) return 0;
    final at = fed(t) * stops.length;
    final step = math.min(at.floor(), stops.length - 1);
    final from = step == 0 ? 0.0 : stops[step - 1];
    final move = AppCurves.easeOut.transform(phase(at - step, 0, 0.66));
    return from + (stops[step] - from) * move;
  }

  /// How far the ink of part [step] of [steps] has come up, 0 to 1. A part
  /// is printed as it leaves the slot.
  static double ink(double t, int step, int steps) {
    if (steps <= 0) return 1;
    final at = fed(t) * steps;
    return phase(at - step, 0.2, 0.7);
  }

  /// The angle the paper hangs at, in radians. It swings a little while it
  /// feeds, less and less, and hangs square from [feedEnd] on.
  static double sway(double t) {
    final p = fed(t);
    if (p <= 0 || p >= 1) return 0;
    return swayMax * (1 - p) * math.sin(2 * math.pi * (t - feedStart) / 0.42);
  }

  /// The stamp at [t]. It comes down large and turned a little further
  /// than it rests, and presses into place.
  static ReceiptStamp stamp(double t) {
    final p = phase(t, stampAt, stampLanded);
    final land = AppCurves.easeBack.transform(p);
    return ReceiptStamp(
      opacity: phase(t, stampAt, stampAt + 0.07),
      scale: 1 + 0.7 * (1 - land),
      angle: stampAngle - 0.16 * (1 - AppCurves.easeOut.transform(p)),
    );
  }

  /// How far the first preview has come out from behind the paper, 0 to 1.
  static double peek(double t) =>
      AppCurves.easeBack.transform(phase(t, peekStart, restAt - 0.05));

  /// The second part [step] of a slip of [count] lines starts to print,
  /// which is as it leaves the slot. Part 0 is the header, parts 1 to
  /// [count] are the lines, and the total is the part after them.
  static double printsAt(int step, int count) =>
      feedStart + (step + 0.2) / (count + 3) * (feedEnd - feedStart);

  /// The second the total of a slip of [count] lines starts to print.
  static double totalAt(int count) => printsAt(count + 1, count);

  /// The second the first preview is heard coming out from behind the
  /// paper. It starts out at [peekStart], while the stamp is still
  /// sounding, so its own cue waits until the stamp's is over.
  static const double peekCueAt = stampAt + 0.35;

  /// How high the mascot's nod is at most, against the hop of a reaction.
  static const double nodHeight = 0.3;

  /// The small nod the mascot gives as each of the [count] lines comes
  /// out, 0 to [nodHeight]. It is level between lines, and for the header,
  /// the total and the foot.
  static double nod(double t, int count) {
    final at = fed(t) * (count + 3);
    final step = at.floor();
    if (step < 1 || step > count) return 0;
    return nodHeight * math.sin(math.pi * phase(at - step, 0.15, 0.75));
  }

  /// The mascot at [t] beside a slip of [count] lines, until the loop
  /// takes over at [restAt]: it lands wide-eyed, watches each line come
  /// out with a nod, is glad at the total, is startled into a hop by the
  /// stamp, and is glad again.
  ///
  /// After an intro ([followsIntro]) the mascot is already in its place:
  /// the intro ended on it, so it is not dropped in a second time.
  static ReceiptActor actor(
    double t, {
    required int count,
    bool followsIntro = false,
  }) {
    final entrance = followsIntro ? 1.0 : phase(t, 0, heroEntranceSeconds);
    if (t < 0.5) {
      return ReceiptActor(
        face: HeroFace.arriving,
        fromFace: HeroFace.arriving,
        faceBlend: 1,
        hop: 0,
        entrance: entrance,
      );
    }
    final total = totalAt(count);
    if (t < total) {
      return ReceiptActor(
        face: HeroFace.watching,
        fromFace: HeroFace.arriving,
        faceBlend: phase(t, 0.5, 0.5 + heroFaceBlend),
        hop: nod(t, count),
        entrance: entrance,
      );
    }
    if (t < stampAt) {
      return ReceiptActor(
        face: HeroFace.glad,
        fromFace: HeroFace.watching,
        faceBlend: phase(t, total, total + heroFaceBlend),
        hop: 0,
        entrance: 1,
      );
    }
    const gladAt = stampAt + 0.34;
    final up = phase(t, stampAt, stampAt + heroHopSeconds);
    final hop = 4 * up * (1 - up);
    if (t < gladAt) {
      return ReceiptActor(
        face: HeroFace.startled,
        fromFace: HeroFace.glad,
        faceBlend: phase(t, stampAt, stampAt + heroFaceBlend * 0.5),
        hop: hop,
        entrance: 1,
      );
    }
    return ReceiptActor(
      face: HeroFace.glad,
      fromFace: HeroFace.startled,
      faceBlend: phase(t, gladAt, restAt),
      hop: hop,
      entrance: 1,
    );
  }
}

/// What the print sounds like, by clock second, for a slip of [count]
/// lines: one small line cue as each line and then the total leaves the
/// slot, the stamp as it comes down, and a rise as the first preview comes
/// out. The frame plays no entrance cue under these: one long printing
/// sound would talk over them.
List<PaywallCueBeat> receiptCues(int count) => [
  for (var step = 1; step <= count + 1; step++)
    PaywallCueBeat(ReceiptTimeline.printsAt(step, count), PaywallCue.line),
  const PaywallCueBeat(ReceiptTimeline.stampAt, PaywallCue.stamp),
  const PaywallCueBeat(ReceiptTimeline.peekCueAt, PaywallCue.rise),
];

/// How the receipt's stage moves, where it is not the print itself. The
/// mascot is dropped beside the slot, as the paper drops out of it, and
/// keeps the plain bob. One preview slides out as the next slides in.
/// The air is the approved drift until the stamp lands, which throws the
/// confetti once.
const HeroMotion receiptMotion = HeroMotion(
  atmosphere: HeroAtmosphereStyle.confetti,
  entrance: HeroEntranceStyle.drop,
  arrival: HeroCardArrival.slideThrough,
);

/// Which way a new preview travels, for a change the hand sent in
/// [direction] (1 the next, -1 the previous, 0 the loop's own). The loop
/// brings each one out from behind the paper, as the print brought the
/// first, so it reads as -1.
int receiptCardWay(int direction) => direction == 0 ? -1 : direction;

/// The seconds the confetti reads at clock second [t]: null before the
/// stamp has landed, when there is none, and then the time since. It is
/// never zero while it falls, because zero is the frame where every piece
/// has landed. When nothing may move that landed frame is the one drawn.
double? receiptConfettiSeconds(double t, {required bool isStill}) {
  if (isStill) return 0;
  if (t < ReceiptTimeline.stampLanded) return null;
  return math.max(0.001, t - ReceiptTimeline.stampLanded);
}

/// Where everything stands on a stage, for one size and one number of
/// lines. All boxes are in the stage's own points.
class ReceiptPlan {
  const ReceiptPlan._({
    required this.stage,
    required this.slot,
    required this.paper,
    required this.row,
    required this.count,
    required this.mascot,
    required this.card,
  });

  /// Places the slot, the paper, the mascot and the card in [stage] for a
  /// slip of [count] lines.
  ///
  /// The paper hangs from the slot on the left, on the one left edge of
  /// the screen. Its lines take the height the stage can give, between
  /// [rowMin] and [rowMax] each. The mascot and the card stand in the
  /// column to its right, under the close cross, and both give way before
  /// the paper does. The card is whole beside the paper, never under it.
  /// The mascot is as large as the column lets it be and leans [lean]
  /// points over the paper's edge, in front of it.
  factory ReceiptPlan.of(Size stage, {required int count}) {
    final paperWidth = (stage.width * 0.56).clamp(196.0, 226.0);
    final free = stage.height - margin * 2 - slotLap - _fixed;
    final row = count == 0 ? rowMin : (free / count).clamp(rowMin, rowMax);
    final paperHeight = _fixed + row * count;
    final group = slotLap + paperHeight;
    final top = math.max(margin, (stage.height - group) / 2);

    final paper = Rect.fromLTWH(side, top + slotLap, paperWidth, paperHeight);
    final slot = Rect.fromLTWH(
      side - slotReach,
      top,
      paperWidth + slotReach * 2,
      slotHeight,
    );

    // The column beside the paper: the mascot over the card.
    final left = paper.right + cardGap;
    final right = stage.width - mascotRight;
    final width = right - left;
    final columnTop = math.max(top, crossRoom);
    final room = paper.bottom - columnTop;
    var cardEdge = math.min(cardMax, width);
    var mascot = math.min(right - paper.right + lean, mascotMax);
    if (mascot + columnGap + cardEdge > room) {
      mascot = math.max(mascotMin, room - columnGap - cardEdge);
    }
    if (mascot + columnGap + cardEdge > room) {
      cardEdge = math.max(cardMin, room - columnGap - mascot);
    }
    final block = mascot + columnGap + cardEdge;
    final blockTop = columnTop + math.max(0, (room - block) / 2);

    return ReceiptPlan._(
      stage: stage,
      slot: slot,
      paper: paper,
      row: row,
      count: count,
      // A mascot wider than the column keeps the right edge and leans
      // left, over the paper.
      mascot: Rect.fromLTWH(
        mascot > width ? right - mascot : left + (width - mascot) / 2,
        blockTop,
        mascot,
        mascot,
      ),
      card: Rect.fromLTWH(
        left + (width - cardEdge) / 2,
        blockTop + mascot + columnGap,
        cardEdge,
        cardEdge,
      ),
    );
  }

  /// The side inset, the same as the words' and the buy block's.
  static const double side = 20;

  /// Room kept above the slot and under the paper.
  static const double margin = 8;

  /// The slot: how tall, how far it reaches past the paper on each side,
  /// and how far down it the paper starts.
  static const double slotHeight = 18;
  static const double slotReach = 8;
  static const double slotLap = 11;

  /// One line of the slip, at its tightest and at its loosest.
  static const double rowMin = 26;
  static const double rowMax = 44;

  /// The parts of the paper that are not lines, top to bottom: the room
  /// under the slot, the header, a rule, (the lines), a rule, the total,
  /// the stamp's room, the torn edge.
  static const double lead = 10;
  static const double header = 24;
  static const double rule = 12;
  static const double total = 30;
  static const double stampRoom = 58;
  static const double tear = 9;
  static const double _fixed =
      lead + header + rule + rule + total + stampRoom + tear;

  /// The words on the paper start this far in from its edges.
  static const double pad = 14;

  /// A line's tick, and the gap between it and the words.
  static const double tick = 12;
  static const double tickGap = 7;

  /// The type of a line, at its largest and at its smallest, and how wide
  /// one letter of the mono face is against its size.
  static const double fontMax = 13;
  static const double fontMin = 9;
  static const double monoAdvance = 0.602;

  /// The column: the close cross's room above it, the gap between the
  /// mascot and the card, and how close the two may come to the edge.
  static const double crossRoom = 46;
  static const double columnGap = 12;
  static const double mascotRight = 14;
  static const double mascotMax = 168;
  static const double mascotMin = 72;

  /// How far the mascot may lean over the paper's edge. It is less than
  /// [pad], so it never covers a word.
  static const double lean = 10;

  /// The card is a preview at its middle size, this far clear of the
  /// paper.
  static const double cardMax = 120;
  static const double cardMin = 96;
  static const double cardGap = 4;

  /// The shortest stage a slip of [count] lines fits on.
  static double minHeight(int count) =>
      margin * 2 + slotLap + _fixed + rowMin * count;

  /// The tallest stage a slip of [count] lines has a use for.
  static double maxHeight(int count) =>
      margin * 2 + slotLap + _fixed + rowMax * count;

  final Size stage;
  final Rect slot;
  final Rect paper;

  /// The height of one line.
  final double row;
  final int count;
  final Rect mascot;
  final Rect card;

  /// How far the card moves left to be wholly behind the paper.
  double get cardTravel => card.right - paper.right;

  /// The size of the type every line is set in, for a slip whose longest
  /// line has [longest] letters: the largest at which that line fits the
  /// paper, so all the lines are one size. A tight slip caps it lower.
  double lineFont(int longest) {
    final cap = row < 30 ? fontMax - 1 : (row < 40 ? fontMax - 0.5 : fontMax);
    if (longest <= 0) return cap;
    final room = paper.width - pad * 2 - tick - tickGap;
    return (room / (longest * monoAdvance)).clamp(fontMin, cap);
  }

  /// How far down the paper the lines start.
  double get rowsTop => lead + header + rule;

  /// How far down the paper the total starts, and the stamp's room.
  double get totalTop => rowsTop + row * count + rule;
  double get stampTop => totalTop + total;

  /// Where each part of the print ends, in points down the paper: the
  /// header, each line, the total, the foot. Feed it to
  /// [ReceiptTimeline.feed].
  List<double> get stops => [
    rowsTop,
    for (var i = 1; i <= count; i++) rowsTop + row * i,
    stampTop,
    paper.height,
  ];

  /// Where the middle of each line is, in points down the stage.
  List<double> get rowCentres => [
    for (var i = 0; i < count; i++) paper.top + rowsTop + row * (i + 0.5),
  ];

  /// The line under a touch at [point] on the stage, or null when the
  /// touch is not on a line. Every line answers within 22 points of its
  /// middle, and the nearer line takes a touch between two.
  int? rowAt(Offset point) {
    if (point.dx < paper.left || point.dx > paper.right) return null;
    int? best;
    var nearest = double.infinity;
    for (final (i, centre) in rowCentres.indexed) {
      final away = (point.dy - centre).abs();
      if (away <= 22 && away < nearest) {
        nearest = away;
        best = i;
      }
    }
    return best;
  }

  /// The box the air behind the stage is centred on: the mascot and the
  /// card.
  Rect get column => mascot.expandToInclude(card);
}

import 'dart:math' as math;

import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_arrangement.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_motion.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_cue_rules.dart';
import 'package:flutter/widgets.dart';

// The bento board as numbers: which benefit sits in which tile, where the
// tiles are, how two of them trade places and how the board comes in. No
// widget is in here, so every rule has a test.

/// Which benefit sits in which tile. Slot 0 is the stage, the one large
/// tile. The slots after it are the small tiles, left to right.
///
/// A benefit takes the stage by trading places with the one on it: the
/// two swap slots and every other tile stays where it is. The board keeps
/// the last trade so it can be drawn half way.
@immutable
class BentoBoard {
  const BentoBoard._(this.order, this.tradedSlot, this.began);

  /// [count] benefits in the order the product lists them, the first on
  /// the stage.
  BentoBoard.of(int count)
    : order = List.unmodifiable([for (var i = 0; i < count; i++) i]),
      tradedSlot = null,
      began = 0;

  /// The benefit in each slot.
  final List<int> order;

  /// The small slot that last traded with the stage. Null before any
  /// trade.
  final int? tradedSlot;

  /// The loop second that trade began.
  final double began;

  /// The benefit on the stage.
  int get staged => order.isEmpty ? 0 : order.first;

  /// The benefit that last left the stage, now in [tradedSlot].
  int? get unstaged => switch (tradedSlot) {
    final slot? => order[slot],
    null => null,
  };

  /// The slot [benefit] sits in, or -1 for one the board does not have.
  int slotOf(int benefit) => order.indexOf(benefit);

  /// The board after [benefit] takes the stage at loop second [at]. The
  /// same board when it is already there.
  BentoBoard stage(int benefit, {required double at}) {
    final slot = order.indexOf(benefit);
    if (slot <= 0) return this;
    final next = [...order];
    next[slot] = order.first;
    next[0] = benefit;
    return BentoBoard._(List.unmodifiable(next), slot, at);
  }
}

/// How long two tiles take to trade places: long enough to see one go up
/// as the other comes down.
const double bentoTradeSeconds = 1;

/// How far along its way a trading tile is when the trade is [trade] of
/// the way through. It starts slowly, is half way at the half, and slows
/// into its place, so the two tiles are seen to pass each other.
double bentoTradePath(double trade) =>
    Curves.easeInOutCubic.transform(trade.clamp(0.0, 1.0));

/// How far through its last trade [board] is at loop second [seconds], 0
/// to 1. A board that never traded is at 1.
double bentoTradeAt(BentoBoard board, double seconds) =>
    board.tradedSlot == null
    ? 1
    : phase(seconds, board.began, board.began + bentoTradeSeconds);

/// How high a trading tile is lifted off the board, 0 to 1: up and back
/// down across the trade.
double bentoLiftAt(double trade) => 4 * trade * (1 - trade);

/// Between two tiles, and between the board's two rows.
const double bentoGutter = Spacing.s2;

/// The row the close cross sits in, above the board.
const double bentoCrossRow = 44;

/// The stage tile stops growing at this height. Past it more height is
/// only more air.
const double bentoStageMax = 420;

/// How much a small tile may grow on a tall phone.
const double bentoSmallGrow = 24;

/// Where everything is in the column: the stage tile, the small tiles
/// under it, and the room around the board. The tiles are in the board's
/// own points, from its top left.
@immutable
class BentoPlan {
  const BentoPlan({
    required this.top,
    required this.stage,
    required this.small,
    required this.gap,
    required this.under,
  });

  /// From the top of the room to the board.
  final double top;

  /// The stage tile.
  final Rect stage;

  /// The small tiles, left to right.
  final List<Rect> small;

  /// Between the board and the headline.
  final double gap;

  /// Under the headline, down to the buy block.
  final double under;

  /// Every tile by slot: the stage first.
  List<Rect> get slots => [stage, ...small];

  /// The board's height.
  double get height => small.isEmpty ? stage.bottom : small.first.bottom;
}

/// Shares a column [height] tall and [width] wide between the board and
/// [words] points of headline under it.
///
/// [small] is how many small tiles there are and [smallHeight] what one
/// needs for its mark and its label. The stage tile takes what is left, up
/// to [bentoStageMax]. Spare height past that goes to the small tiles
/// first, then to the air around the board: most of it above the board
/// and under the headline, so the headline stays close to the board it
/// names.
BentoPlan bentoPlanFor({
  required double width,
  required double height,
  required int small,
  required double smallHeight,
  required double words,
  required bool isCompact,
}) {
  final gap = isCompact ? 10.0 : 14.0;
  final bottom = isCompact ? Spacing.s3 : 20.0;
  final row = small > 0 ? bentoGutter + smallHeight : 0.0;
  final left = height - bentoCrossRow - row - gap - words - bottom;
  final stage = left.clamp(0.0, bentoStageMax).floorToDouble();
  var spare = math.max(0, left - bentoStageMax).toDouble();
  final grow = small > 0 ? math.min(spare, bentoSmallGrow) : 0.0;
  spare -= grow;

  final top = bentoCrossRow + spare * 0.35;
  final tileHeight = smallHeight + grow;
  final tileWidth = small > 0
      ? (width - bentoGutter * (small - 1)) / small
      : 0.0;
  return BentoPlan(
    top: top,
    stage: Rect.fromLTWH(0, 0, width, stage),
    small: [
      for (var i = 0; i < small; i++)
        Rect.fromLTWH(
          i * (tileWidth + bentoGutter),
          stage + bentoGutter,
          tileWidth,
          tileHeight,
        ),
    ],
    gap: gap + spare * 0.15,
    under: bottom + spare * 0.5,
  );
}

/// Where the tile of [benefit] is when [board]'s last trade is [trade] of
/// the way through.
///
/// The two tiles that traded are on their way between the stage and the
/// small slot. Every other tile is at home.
Rect bentoTileRect({
  required BentoBoard board,
  required BentoPlan plan,
  required int benefit,
  required double trade,
}) {
  final slots = plan.slots;
  final slot = board.slotOf(benefit);
  final home = slots[slot];
  final traded = board.tradedSlot;
  if (traded == null || trade >= 1) return home;
  final eased = bentoTradePath(trade);
  if (slot == 0) return Rect.lerp(slots[traded], home, eased)!;
  if (slot == traded) return Rect.lerp(slots[0], home, eased)!;
  return home;
}

/// How much of a stage tile a tile [rect] large is, 0 for a small tile
/// and 1 for the stage. A tile draws its mark or the stage by this.
double bentoStageShare(Rect rect, BentoPlan plan) {
  if (plan.small.isEmpty) return 1;
  final small = plan.small.first.height;
  final span = plan.stage.height - small;
  if (span <= 0) return 1;
  return ((rect.height - small) / span).clamp(0.0, 1.0);
}

/// How strongly a tile that is [share] of a stage draws the stage, 0 to
/// 1. What is left of it is how strongly it draws its mark and its label,
/// so a tile is never empty.
///
/// A tile growing into the stage travels as its mark and draws the stage
/// once it is most of the way there, so each tile is one clear thing
/// while the two pass. A tile [isLeaving] the stage lets go of it at once
/// and shrinks as its mark, so the mascot is never on two tiles at once.
double bentoStageOpacity(double share, {bool isLeaving = false}) =>
    isLeaving ? phase(share, 0.82, 0.98) : phase(share, 0.4, 0.7);

/// The second the stage tile starts to drop: the small tiles have all
/// started by then. The mascot's own entrance starts here too, so it is
/// the loop's `prelude`.
const double bentoStageLands = 0.36;

/// How long the stage tile takes to drop and settle.
const double bentoStageDropSeconds = 0.5;

/// When the first small tile starts to drop, how long after it each of
/// the others starts, and how long one takes.
const double bentoSmallFirst = 0.04;

/// The kit's own stagger, which [bentoSmallLandAt] takes by default.
const double bentoSmallEach = 0.08;
const double bentoSmallDropSeconds = 0.4;

/// How far the small tile at [index] has dropped at clock second [t], 0
/// to 1. They drop left to right, one after another.
double bentoSmallLandAt(double t, int index) => phase(
  stagger(index, t, start: bentoSmallFirst),
  0,
  bentoSmallDropSeconds,
);

/// The second the small tile at [index] first touches its place: the
/// first contact of its bounce.
double bentoSmallThudAt(int index) =>
    bentoSmallFirst + index * bentoSmallEach + bentoSmallDropSeconds / 2.75;

/// How far the stage tile has dropped at clock second [t], 0 to 1. It is
/// the last tile down and the heaviest.
double bentoStageLandAt(double t) =>
    phase(t, bentoStageLands, bentoStageLands + bentoStageDropSeconds);

/// How far above their places the tiles start, in points.
const double bentoSmallDropFrom = 26;
const double bentoStageDropFrom = 44;

/// A tile on its way down when it has [land] of its drop behind it: how
/// far above its place it is, in points, and how solid. It falls [from]
/// points, hits its place a little over a third of the way through,
/// bounces, and lies still and whole at one.
({double dy, double opacity}) bentoDropAt(double land, {required double from}) {
  final p = land.clamp(0.0, 1.0);
  return (
    dy: -from * (1 - Curves.bounceOut.transform(p)),
    opacity: phase(p, 0, 0.3),
  );
}

/// The second the stage tile first touches its place: the first contact
/// of its bounce. The landing's cue plays here.
const double bentoStageThudAt = bentoStageLands + bentoStageDropSeconds / 2.75;

/// How the stage tile moves: the mascot drops into the tile as the tile
/// drops onto the board, the approved shapes drift behind it, and it hops
/// as each new benefit takes the stage. A new preview arrives by the
/// trade, so the card keeps the approved change.
const HeroMotion bentoMotion = HeroMotion(
  entrance: HeroEntranceStyle.drop,
  idle: HeroIdleStyle.benefitHop,
);

/// How many seconds of the entrance are skipped when an intro has just
/// handed over: the intro ends on the mascot, so the small tiles are
/// already down and the stage tile is on its way.
const double bentoIntroHeadStart = 0.5;

/// The head start of a layout that does or does not follow an intro.
double bentoLeadFor({required bool followsIntro}) =>
    followsIntro ? bentoIntroHeadStart : 0;

/// What the entrance sounds like, by clock second, on a board with
/// [small] small tiles: a check as each small tile touches down, then the
/// stage tile's heavier landing.
///
/// A small tile that would touch down after the stage tile has no check,
/// so the landing is the last thing heard and nothing cuts it short.
/// [lead] is the head start after an intro (see [bentoLeadFor]), which
/// every moment is that much sooner by.
List<PaywallCueBeat> bentoCues({required int small, double lead = 0}) => [
  for (var i = 0; i < small; i++)
    if (bentoSmallThudAt(i) < bentoStageThudAt)
      PaywallCueBeat(bentoSmallThudAt(i) - lead, PaywallCue.check),
  PaywallCueBeat(bentoStageThudAt - lead, PaywallCue.drop),
];

/// Room kept clear inside the stage tile: above the mascot for what it
/// wears, and at the sides.
const double bentoStageTopRoom = 16;
const double bentoStageSideRoom = 14;

/// Places the mascot and the card inside a stage tile of [size].
///
/// With the height for it this is the approved pair. A tile too short
/// for that keeps both at a good size by sliding the mascot down beside
/// the card, the mascot's corner still over the card's. A tile too short
/// even for that is left to the approved rule, which drops the card and
/// then the mascot.
HeroArrangement bentoArrangementFor(Size size) {
  final width = size.width - bentoStageSideRoom * 2;
  final height = size.height - bentoStageTopRoom;
  final card = math.min(
    heroCardMax,
    math.min(
      width / (1 + heroMascotShare * (1 - heroOverlapX)),
      height * 0.72,
    ),
  );
  if (card < heroCardMin) return heroArrangementFor(size);

  final mascot = math.min(
    card * heroMascotShare,
    (width - card) / (1 - heroOverlapX),
  );
  final groupWidth = card + mascot * (1 - heroOverlapX);
  final groupHeight = math.min(height, card + mascot * (1 - heroOverlapY));
  final left = (size.width - groupWidth) / 2;
  final top = bentoStageTopRoom + (height - groupHeight) / 2;
  return HeroArrangement(
    kind: HeroStageKind.pair,
    mascot: Rect.fromLTWH(left, top, mascot, mascot),
    card: Rect.fromLTWH(
      left + groupWidth - card,
      top + groupHeight - card,
      card,
      card,
    ),
  );
}

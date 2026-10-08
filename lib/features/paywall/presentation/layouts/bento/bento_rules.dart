import 'dart:math' as math;

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_arrangement.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
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

/// How long two tiles take to trade places.
const double bentoTradeSeconds = 0.64;

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
const double bentoStageMax = 400;

/// How much a small tile may grow on a tall phone.
const double bentoSmallGrow = 16;

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
/// first, then to the air around the board.
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

  final top = bentoCrossRow + spare * 0.25;
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
    gap: gap + spare * 0.4,
    under: bottom + spare * 0.35,
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
  final eased = AppCurves.easeOut.transform(trade);
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
/// A tile growing into the stage draws it as soon as it is large enough
/// to read. A tile [isLeaving] the stage lets go of it at once and
/// shrinks as its mark, so the mascot is never on two tiles at once.
double bentoStageOpacity(double share, {bool isLeaving = false}) => isLeaving
    ? phase(share, 0.82, 0.98)
    : phase(share, 0.18, 0.42);

/// The second the stage tile starts to land: the small tiles have all
/// started by then. The mascot's own entrance starts here too, so it is
/// the loop's `prelude`.
const double bentoStageLands = 0.28;

/// How far the small tile at [index] has landed at clock second [t], 0 to
/// 1. They land left to right, a little apart.
double bentoSmallLandAt(double t, int index) =>
    phase(stagger(index, t, each: 0.06, start: 0.04), 0, 0.34);

/// How far the stage tile has landed at clock second [t], 0 to 1. It is
/// the last tile down and the only one that pops.
double bentoStageLandAt(double t) =>
    phase(t, bentoStageLands, bentoStageLands + 0.42);

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

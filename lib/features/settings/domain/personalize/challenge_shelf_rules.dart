import 'package:critalarm/core/access/feature_decision.dart';
import 'package:critalarm/core/access/lock_tap_rule.dart';
import 'package:critalarm/features/challenges/domain/challenge_kind.dart';
import 'package:flutter/foundation.dart';

// What the shelf on the Wake-up challenge page decides, with nothing drawn:
// the tiles, how many columns, what the pick control looks like and what each
// tap does. Pure, so it is unit tested and the screen only draws the answer.

/// The gap between tiles, and between rows of tiles.
const double kShelfGap = 12;

/// The room between the shelf and the edge of the page column.
const double kShelfSidePadding = 14;

/// The narrowest a tile may be. A column count that would make a tile
/// narrower than this gives way to one fewer.
const double kShelfMinTileWidth = 150;

/// The page column width from which the shelf wants three columns.
const double kShelfThreeColumnsFrom = 480;

/// The text scale from which the shelf is one column.
const double kShelfOneColumnFromScale = 2;

/// One tile of the shelf: a challenge, or the tile that turns challenges off.
@immutable
class ShelfTile {
  const ShelfTile(this.kind);

  /// "No challenge": the first tile.
  static const ShelfTile off = ShelfTile(null);

  /// The challenge, or null for [off].
  final ChallengeKind? kind;

  bool get isOff => kind == null;

  @override
  bool operator ==(Object other) => other is ShelfTile && other.kind == kind;

  @override
  int get hashCode => Object.hash(ShelfTile, kind);

  @override
  String toString() => 'ShelfTile(${kind?.id ?? 'off'})';
}

/// The tiles in order: "No challenge", then one per kind of [kinds], which
/// is the order of `challenges`.
List<ShelfTile> shelfTilesFor(List<ChallengeKind> kinds) => [
  ShelfTile.off,
  for (final kind in kinds) ShelfTile(kind),
];

/// The width of one tile when a page column [columnWidth] wide is cut into
/// [columns].
double shelfTileWidthFor({required double columnWidth, required int columns}) =>
    (columnWidth - 2 * kShelfSidePadding - kShelfGap * (columns - 1)) / columns;

/// How many columns the shelf has in a page column [columnWidth] wide at
/// [textScale].
///
/// One at text scale 2.0 and above. Otherwise three from
/// [kShelfThreeColumnsFrom] and two below it, and always one fewer than that
/// when the tiles would be narrower than [kShelfMinTileWidth].
int shelfColumnsFor({required double columnWidth, required double textScale}) {
  if (textScale >= kShelfOneColumnFromScale) return 1;
  var columns = columnWidth >= kShelfThreeColumnsFrom ? 3 : 2;
  while (columns > 1 &&
      shelfTileWidthFor(columnWidth: columnWidth, columns: columns) <
          kShelfMinTileWidth) {
    columns--;
  }
  return columns;
}

/// The challenge that has the tick: what a new topic starts with, or none.
///
/// A kind saved before the plan lapsed stays saved and is not ticked while
/// the feature is locked, so the shelf says Off, as the root card does. It
/// comes back with the plan.
ChallengeKind? shelfChosenFor({
  required ChallengeKind? saved,
  required FeatureDecision decision,
}) => decision is FeatureLocked ? null : saved;

/// The three taps on the shelf.
enum ShelfTap {
  /// The tile, its picture and its name: opens the try. For everyone.
  tile,

  /// The pick control: keeps the challenge for new topics.
  pick,

  /// The wide button, drawn only while locked.
  plan,
}

/// What a tap on the shelf does, from the lock rule.
///
/// - [ShelfTap.tile] is `open`: [OpenPage], whatever the plan.
/// - [ShelfTap.pick] is `keep`: [DoIt] saves the default, [OpenPaywall] sells
///   Pro, [WaitForPlan] waits for the plan to be read and asks again.
/// - [ShelfTap.plan] is `seePlan`: [OpenPaywall] while locked.
///
/// The "No challenge" tile never asks: turning challenges off needs no plan
/// (see [shelfOffTapAnswer]).
LockTapAnswer shelfTapFor({
  required ShelfTap tap,
  required FeatureDecision decision,
  required bool isPlanRead,
}) => lockTapFor(
  decision: decision,
  isPlanRead: isPlanRead,
  hasTry: false,
  tap: switch (tap) {
    ShelfTap.tile => LockTapKind.open,
    ShelfTap.pick => LockTapKind.keep,
    ShelfTap.plan => LockTapKind.seePlan,
  },
);

/// What a tap on the "No challenge" tile or its control does: [DoIt], always.
/// Taking a challenge away needs no plan and nothing is sold for it.
LockTapAnswer shelfOffTapAnswer() => const DoIt();

/// How the pick control of a tile is drawn.
enum ShelfPick {
  /// This is the challenge new topics start with: a filled ring with a check.
  chosen,

  /// A plain ring. A tap keeps this challenge for new topics.
  open,

  /// A ring with a lock glyph. A tap opens the paywall.
  locked,

  /// A plain ring that sells nothing and saves nothing yet: the plan has not
  /// been read, or the feature is not offered.
  unread,
}

/// How the pick control of [tile] is drawn.
///
/// [chosen] is `shelfChosenFor`. The plan is asked through [shelfTapFor], so
/// the ring and the tap agree. "No challenge" needs no plan, so its ring is
/// never locked.
ShelfPick shelfPickFor({
  required ShelfTile tile,
  required ChallengeKind? chosen,
  required FeatureDecision decision,
  required bool isPlanRead,
}) {
  if (tile.kind == chosen) return ShelfPick.chosen;
  if (tile.isOff) return ShelfPick.open;
  return switch (shelfTapFor(
    tap: ShelfTap.pick,
    decision: decision,
    isPlanRead: isPlanRead,
  )) {
    DoIt() => ShelfPick.open,
    OpenPaywall() => ShelfPick.locked,
    WaitForPlan() || Nothing() || OpenPage() || TryIt() => ShelfPick.unread,
  };
}

/// What sits under the tiles.
enum ShelfFooter {
  /// Nothing.
  none,

  /// The wide button that opens the paywall. Only while locked and the plan
  /// is read.
  planButton,

  /// The line that says a purchase is being confirmed. The feature is
  /// usable meanwhile.
  confirming,
}

/// What sits under the tiles. The button is drawn when the lock rule would
/// open a paywall for it, so it is never there for a plan that is held, one
/// not yet read or a purchase being confirmed.
ShelfFooter shelfFooterFor({
  required FeatureDecision decision,
  required bool isPlanRead,
}) {
  if (shelfTapFor(
        tap: ShelfTap.plan,
        decision: decision,
        isPlanRead: isPlanRead,
      )
      is OpenPaywall) {
    return ShelfFooter.planButton;
  }
  return isPlanRead && decision is FeatureConfirming
      ? ShelfFooter.confirming
      : ShelfFooter.none;
}

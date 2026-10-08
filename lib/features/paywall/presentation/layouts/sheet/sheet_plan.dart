import 'dart:math' as math;
import 'dart:ui';

import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_arrangement.dart';
import 'package:flutter/foundation.dart';

/// How much of the screen behind is drawn above the lit row.
enum SheetHeader {
  /// The back row and the title on a line of its own.
  full,

  /// The back row alone, carrying the title.
  inline,

  /// Nothing: the lit row sits under the status bar.
  none,
}

/// Where everything in the Sheet layout sits on one phone.
///
/// The screen behind is a picture with fixed sizes, so the lit row's place
/// is known before anything is laid out and the sheet can stop just under
/// it, with room for the mascot to look over its edge.
@immutable
class SheetPlan {
  const SheetPlan({
    required this.isCompact,
    required this.topInset,
    required this.header,
    required this.rowsAbove,
    this.isMeasured = true,
    this.standsInFront = true,
  });

  /// The most quiet rows drawn between the title and the lit row.
  static const int maxRowsAbove = 2;

  /// How much of the mascot shows over the sheet's edge when it stands
  /// behind the sheet: down to just under its eyes.
  static const double faceShownBehind = 0.56;

  final bool isCompact;

  /// The status bar's height.
  final double topInset;

  final SheetHeader header;

  /// Quiet rows between the title and the lit row.
  final int rowsAbove;

  /// False while the plan is only a guess: the buy block has no height yet
  /// and its height would change what is drawn above the lit row. A guess
  /// lays the sheet out so the kit can measure the block, and none of it
  /// is drawn, so the first frame on screen is already the settled one.
  final bool isMeasured;

  /// True when the mascot stands whole in front of the sheet, astride its
  /// top edge, beside the preview. False past the default text size: the
  /// words then take the room its lower half needs, so it stands behind
  /// the sheet and looks over the edge.
  final bool standsInFront;

  /// The back row at the top of the screen behind.
  double get navHeight => switch (header) {
    SheetHeader.none => 0,
    _ => isCompact ? 32 : 40,
  };

  /// True when the title has a line of its own under the back row.
  bool get hasTitleLine => header == SheetHeader.full;

  double get titleSize => isCompact ? 26 : 30;

  /// The title and the gap under it, or only the gap.
  double get titleBlock => switch (header) {
    SheetHeader.full => isCompact ? 38 : 46,
    SheetHeader.inline => 4,
    SheetHeader.none => 6,
  };

  double get rowHeight => isCompact ? 44 : 50;
  double get rowGap => isCompact ? 6 : 8;

  /// The lit row's height.
  double get litHeight => isCompact ? 64 : 72;

  /// The mascot on the sheet's edge. In front of the sheet it is close to
  /// the size the approved stage draws it at.
  double get faceSize =>
      standsInFront ? (isCompact ? 112 : 150) : (isCompact ? 72 : 108);

  /// How much of the mascot is above the sheet's edge. In front of the
  /// sheet the rest of it is on the sheet, beside the preview.
  double get faceShown =>
      standsInFront ? (isCompact ? 0.36 : 0.37) : faceShownBehind;

  /// How many points of the mascot are above the sheet's edge.
  double get faceAbove => faceSize * faceShown;

  /// The room between the lit row and the sheet. The mascot's top is in
  /// it, with a little air for a hop and for what it wears.
  double get peekGap =>
      faceAbove +
      (standsInFront ? (isCompact ? 10 : 16) : (isCompact ? 6 : 10));

  double get litTop =>
      topInset + navHeight + titleBlock + rowsAbove * (rowHeight + rowGap);

  double get litBottom => litTop + litHeight;

  /// The sheet's top edge.
  double get sheetTop => litBottom + peekGap;
}

/// The room the preview keeps above and below it in the sheet's stage.
const double sheetCardRoom = 6;

/// The stage height at which the preview is at its largest.
const double sheetStageFull = heroCardMax + sheetCardRoom * 2;

/// The shortest stage that holds the preview at its large class.
const double sheetStageLarge = heroCardMin + sheetCardRoom * 2;

/// The edge of a preview at its middle size class.
const double sheetCardMedium = 120;

/// The height of the words in the sheet at the default text size: the
/// headline on one line over [benefitCount] lines, with the gaps around
/// them. The sheet sets its words at the kit's compact sizes on every
/// phone.
double sheetWordsHeight(int benefitCount) =>
    56 + 24.0 * math.max(1, benefitCount);

/// The height the sheet needs at the default text size for a stage
/// [stage] points tall: the stage, the words, and the buy block as the kit
/// laid it out.
double sheetWantedHeight({
  required double buyBlockHeight,
  required int benefitCount,
  required double bottomInset,
  double stage = sheetStageFull,
}) => stage + sheetWordsHeight(benefitCount) + buyBlockHeight + bottomInset;

/// Lays the screen out for one phone.
///
/// The preview comes first. Quiet rows are kept above the lit row only
/// while the preview stays at its largest. After that the screen behind
/// gives up its title line, then its back row, for as long as that keeps
/// the preview at its large class. The lit row is always there and always
/// above the sheet. A phone too short for the large class whatever is
/// given up keeps the back row and gets the middle class.
///
/// Past the default text size the sheet needs every point, so nothing is
/// drawn above the lit row, whatever the buy block measures. At the
/// default size the choice needs [buyBlockHeight]. While it is null the
/// buy block has not been laid out yet, and the plan comes back with
/// [SheetPlan.isMeasured] false: it is there to be laid out and measured,
/// never drawn.
SheetPlan sheetPlanFor({
  required double screenHeight,
  required double topInset,
  required double bottomInset,
  required bool isCompact,
  required double? buyBlockHeight,
  required int benefitCount,
  double textScale = 1,
}) {
  final isLargeText = textScale > 1.01;
  SheetPlan plan(SheetHeader header, int rows, {bool isMeasured = true}) =>
      SheetPlan(
        isCompact: isCompact,
        topInset: topInset,
        header: header,
        rowsAbove: rows,
        isMeasured: isMeasured,
        standsInFront: !isLargeText,
      );
  if (isLargeText) return plan(SheetHeader.none, 0);
  if (buyBlockHeight == null) {
    return plan(SheetHeader.none, 0, isMeasured: false);
  }

  double wanted(double stage) => sheetWantedHeight(
    buyBlockHeight: buyBlockHeight,
    benefitCount: benefitCount,
    bottomInset: bottomInset,
    stage: stage,
  );
  bool fits(SheetPlan plan, double stage) =>
      screenHeight - plan.sheetTop >= wanted(stage);

  for (var rows = SheetPlan.maxRowsAbove; rows > 0; rows--) {
    final withRows = plan(SheetHeader.full, rows);
    if (fits(withRows, sheetStageFull)) return withRows;
  }
  for (final header in SheetHeader.values) {
    final bare = plan(header, 0);
    if (fits(bare, sheetStageLarge)) return bare;
  }
  return plan(SheetHeader.inline, 0);
}

/// The room kept at the stage's right for the close cross.
const double sheetCrossRoom = 48;

/// The side inset of the sheet's content, the same as the words'.
const double sheetSide = 20;

/// Places the preview in the sheet's stage. The mascot is not drawn by
/// this stage: the layout draws it astride the sheet's top edge, at the
/// left. So its box here is empty and sits at the preview's middle, where
/// the air is drawn.
///
/// [face] is the edge of that mascot when it stands in front of the
/// sheet. The preview then stands to its right, between the mascot (which
/// may lie over the preview's corner by [heroOverlapX] of its own width,
/// as on the approved stage) and the close cross. With no [face] the
/// preview has the stage to itself and stands in the middle.
///
/// The preview is as large as the stage allows, up to [heroCardMax]. A
/// stage too short for the large class holds the middle class at
/// [sheetCardMedium], and one too short for that holds nothing.
HeroArrangement sheetStageArrangement(Size size, {double face = 0}) {
  final from = face <= 0 ? 0.0 : sheetSide + face * (1 - heroOverlapX);
  final to = face <= 0 ? size.width : size.width - sheetCrossRoom;
  final room = size.height - sheetCardRoom * 2;
  final double card;
  if (room >= heroCardMin) {
    card = math.min(
      heroCardMax,
      math.min(room, math.max(heroCardMin, to - from)),
    );
  } else if (room >= sheetCardMedium) {
    card = sheetCardMedium;
  } else {
    return const HeroArrangement(
      kind: HeroStageKind.none,
      mascot: Rect.zero,
      card: Rect.zero,
    );
  }
  final rect = Rect.fromLTWH(
    from + math.max(0, (to - from - card) / 2),
    (size.height - card) / 2,
    card,
    card,
  );
  return HeroArrangement(
    kind: HeroStageKind.pair,
    mascot: Rect.fromCenter(center: rect.center, width: 0, height: 0),
    card: rect,
  );
}

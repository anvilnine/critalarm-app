import 'dart:math' as math;
import 'dart:ui';

// Where the mascot and the card stand on a stage, and how much height the
// stage gets. Numbers only, so the rules that pick them have tests.

/// What the stage holds.
enum HeroStageKind {
  /// The mascot up and to the left, the card down and to the right, the
  /// mascot's corner over the card's.
  pair,

  /// The mascot alone, when the stage is too short for a preview to read.
  mascot,

  /// Nothing: no room for a face worth drawing.
  none,
}

/// The mascot and the card, placed in a stage.
class HeroArrangement {
  const HeroArrangement({
    required this.kind,
    required this.mascot,
    required this.card,
  });

  final HeroStageKind kind;

  /// The square the face is drawn in.
  final Rect mascot;

  /// The square the preview is drawn in. Empty unless [kind] is `pair`.
  final Rect card;

  /// The box around both.
  Rect get group =>
      kind == HeroStageKind.pair ? mascot.expandToInclude(card) : mascot;
}

/// The preview is drawn at its large class, which reads from this edge up
/// and stops growing at [heroCardMax].
const double heroCardMin = 160;
const double heroCardMax = 200;

/// The mascot's edge against the card's when both have the room.
const double heroMascotShare = 0.9;

/// How much of the mascot's width and height lies over the card.
const double heroOverlapX = 0.1;
const double heroOverlapY = 0.3;

/// Room kept clear above the mascot, for what it wears, and at the sides.
const double heroTopRoom = 12;
const double heroSideRoom = 16;

/// The smallest mascot drawn. Under it the stage is left empty.
const double heroMascotMin = 56;

/// Places the mascot and whatever stands beside it in a stage of the given
/// size. [heroArrangementFor] is the approved rule. A layout with its own
/// composition passes its own function to the stage: the mascot centred
/// and alone, the card on the left, a card as wide as the stage.
typedef HeroArranger = HeroArrangement Function(Size size);

/// Places the mascot and the card in a stage of [size].
///
/// The card takes its edge first: as large as the stage allows, up to
/// [heroCardMax]. The mascot takes what height is left, never more than
/// [heroMascotShare] of the card. A stage too short for the card at
/// [heroCardMin] with a mascot at least half its edge holds the mascot
/// alone.
HeroArrangement heroArrangementFor(Size size) {
  final height = size.height - heroTopRoom;
  final width = size.width - heroSideRoom * 2;

  // The card and a mascot of full share, as large as both fit.
  const perCard = 1 + heroMascotShare * (1 - heroOverlapY);
  const perCardWide = 1 + heroMascotShare * (1 - heroOverlapX);
  final card = math.min(
    heroCardMax,
    math.min(height / perCard, width / perCardWide),
  );

  if (card >= heroCardMin) {
    return _pair(size, card: card, mascot: card * heroMascotShare);
  }
  // Short of that, the card keeps its smallest edge and the mascot gives.
  final mascot = math.min(
    (height - heroCardMin) / (1 - heroOverlapY),
    (width - heroCardMin) / (1 - heroOverlapX),
  );
  if (mascot >= heroCardMin * 0.5) {
    return _pair(size, card: heroCardMin, mascot: mascot);
  }

  final alone = math.min(math.min(height, width), heroCardMax);
  if (alone < heroMascotMin) {
    return const HeroArrangement(
      kind: HeroStageKind.none,
      mascot: Rect.zero,
      card: Rect.zero,
    );
  }
  return HeroArrangement(
    kind: HeroStageKind.mascot,
    mascot: Rect.fromLTWH(
      (size.width - alone) / 2,
      heroTopRoom + (height - alone) / 2,
      alone,
      alone,
    ),
    card: Rect.zero,
  );
}

HeroArrangement _pair(
  Size size, {
  required double card,
  required double mascot,
}) {
  final groupWidth = card + mascot * (1 - heroOverlapX);
  final groupHeight = card + mascot * (1 - heroOverlapY);
  final left = (size.width - groupWidth) / 2;
  final top = heroTopRoom + (size.height - heroTopRoom - groupHeight) / 2;
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

/// The stage stops growing at this height. Past it the mascot and the card
/// are at their largest, and more height is only more air.
const double heroStageMax = 380;

/// How one column of height is shared between a stage and the words under
/// it.
class HeroStageRoom {
  const HeroStageRoom({
    required this.stage,
    required this.gap,
    required this.under,
  });

  /// The stage's height, in whole points.
  final double stage;

  /// Between the stage and the words. The pips sit in it.
  final double gap;

  /// What is left under the words, down to the buy block.
  final double under;
}

/// Shares [height] between a stage and [words] points of text under it.
///
/// The stage takes what the words leave, with [gap] between them and
/// [bottomGap] under the words. Past [stageMax] the spare height is shared
/// out: most above and below the words, some to the stage. At a large text
/// size the words may leave nothing, and the stage is zero: the stage's
/// arrangement then drops the card, then the mascot.
HeroStageRoom heroStageRoomFor({
  required double height,
  required double words,
  required double gap,
  required double bottomGap,
  double stageMax = heroStageMax,
}) {
  final left = height - words - gap - bottomGap;
  final spare = math.max(0, left - stageMax);
  final stage = math.max(0, math.min(left, stageMax) + spare * 0.4);
  final stageGap = gap + spare * 0.3;
  final under = math.max(0, height - stage.floorToDouble() - stageGap - words);
  return HeroStageRoom(
    stage: stage.floorToDouble(),
    gap: stageGap,
    under: under.toDouble(),
  );
}

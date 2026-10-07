import 'dart:math' as math;
import 'dart:ui';

// Where the mascot and the card stand on the Hero layout's stage. Numbers
// only, so the rule that picks them has a test.

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

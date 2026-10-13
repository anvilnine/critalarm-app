import 'dart:math' as math;
import 'dart:ui';

// Where an intro's tag stands by the layout's mascot, as numbers. No widget
// is in here, so the rule has tests. The host measures the layout and calls
// [paywallIntroTagPlace]; the tag layer draws what comes back.

/// Which side of the mascot the tag stands on: its tail points at the
/// mascot's top edge from [above] and at its foot from [below].
enum PaywallIntroTagSide { above, below }

/// The tag's height, not counting its tail.
const double paywallIntroTagHeight = 28;

/// The tail's height and width, and the gap between its tip and the mascot.
const double paywallIntroTagTail = 6;
const double paywallIntroTagTailWidth = 12;
const double paywallIntroTagGap = 4;

/// The widest the tag is drawn. Its box is this wide and the tag stands in
/// the middle of it.
const double paywallIntroTagMaxWidth = 180;

/// The room kept between the tag and the edge of the screen.
const double paywallIntroTagEdge = 8;

/// The room kept between the tag and any words or picture.
const double paywallIntroTagClear = 4;

/// The corner radius of the tag. A tail never stands over a corner.
const double paywallIntroTagCorner = 12;

/// How far the tag slides along the mascot, point by point, to find room.
const double paywallIntroTagStep = 2;

/// Where the tag stands.
class PaywallIntroTagPlace {
  const PaywallIntroTagPlace({
    required this.side,
    required this.left,
    required this.top,
    required this.width,
    required this.tailX,
  });

  final PaywallIntroTagSide side;

  /// The tag's left edge and its top, tail included.
  final double left;
  final double top;

  /// The tag's width.
  final double width;

  /// The middle of the tail, along the screen.
  final double tailX;

  /// The tag without its tail.
  Rect get pill => Rect.fromLTWH(
    left,
    side == PaywallIntroTagSide.above ? top : top + paywallIntroTagTail,
    width,
    paywallIntroTagHeight,
  );

  /// The tail on its own.
  Rect get tail => Rect.fromLTWH(
    tailX - paywallIntroTagTailWidth / 2,
    side == PaywallIntroTagSide.above ? top + paywallIntroTagHeight : top,
    paywallIntroTagTailWidth,
    paywallIntroTagTail,
  );

  /// The whole tag, tail included.
  Rect get box => pill.expandToInclude(tail);
}

/// Where a tag [width] points wide stands by [mascot], or null when there
/// is no room that is clear.
///
/// The tag tries each side of [order] in turn. On a side it starts in the
/// middle of the mascot and slides along it, never so far that its tail
/// leaves the mascot, to the nearest place that is clear. It is clear when
/// it, and its tail, are inside [bounds] and keep [paywallIntroTagClear]
/// off every rect of [keepOut]: the words and pictures of the layout. A tag
/// with no clear place is not shown. It never covers a headline, a line, a
/// picture or a button, whatever the size.
PaywallIntroTagPlace? paywallIntroTagPlace({
  required Rect mascot,
  required double width,
  required Rect bounds,
  required List<Rect> keepOut,
  required List<PaywallIntroTagSide> order,
}) {
  final pillWidth = math.min(width, paywallIntroTagMaxWidth);
  const room = paywallIntroTagGap + paywallIntroTagTail;
  const span = paywallIntroTagHeight + paywallIntroTagTail;

  // The middle of the box the tag stands in, kept on screen.
  final boxLeft = (mascot.center.dx - paywallIntroTagMaxWidth / 2)
      .clamp(
        bounds.left + paywallIntroTagEdge,
        math.max(
          bounds.left + paywallIntroTagEdge,
          bounds.right - paywallIntroTagMaxWidth - paywallIntroTagEdge,
        ),
      )
      .toDouble();
  final preferred = boxLeft + (paywallIntroTagMaxWidth - pillWidth) / 2;
  final lowest = bounds.left + paywallIntroTagEdge;
  final highest = bounds.right - paywallIntroTagEdge - pillWidth;
  // The tail stays over the mascot, short of its corners.
  final tailMin = mascot.left + paywallIntroTagCorner;
  final tailMax = mascot.right - paywallIntroTagCorner;
  final towardsMiddle = preferred + pillWidth / 2 < bounds.center.dx ? 1 : -1;

  for (final side in order) {
    final top = side == PaywallIntroTagSide.above
        ? mascot.top - room - paywallIntroTagHeight
        : mascot.bottom + paywallIntroTagGap;
    if (top < bounds.top || top + span > bounds.bottom) continue;

    final steps =
        ((paywallIntroTagMaxWidth + bounds.width) / paywallIntroTagStep).ceil();
    for (var i = 0; i <= steps; i++) {
      for (final sign in i == 0 ? const [1] : [towardsMiddle, -towardsMiddle]) {
        final left = preferred + sign * i * paywallIntroTagStep;
        if (left < lowest || left > highest) continue;
        final tailX = mascot.center.dx.clamp(
          left + _tailInset,
          left + pillWidth - _tailInset,
        );
        if (tailX < tailMin || tailX > tailMax) continue;
        final place = PaywallIntroTagPlace(
          side: side,
          left: left,
          top: top,
          width: pillWidth,
          tailX: tailX,
        );
        if (_isClear(place, keepOut)) return place;
      }
    }
  }
  return null;
}

/// A tail's middle keeps this far from the tag's ends: past the corner and
/// half the tail.
const double _tailInset = paywallIntroTagCorner + paywallIntroTagTailWidth / 2;

bool _isClear(PaywallIntroTagPlace place, List<Rect> keepOut) {
  final pill = place.pill.inflate(paywallIntroTagClear);
  final tail = place.tail.inflate(paywallIntroTagClear);
  for (final rect in keepOut) {
    if (rect.overlaps(pill) || rect.overlaps(tail)) return false;
  }
  return true;
}

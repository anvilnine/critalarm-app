import 'dart:math' as math;
import 'dart:ui';

/// Gap between the spotlight and the card that explains it.
const double featureGuideCardGap = 14;

/// Space kept around the spotlit widget, so its edges are not cut.
const double featureGuideHolePadding = 6;

/// True when the card goes above the spotlight: whichever side has more room.
bool featureGuideCardGoesAbove(Rect hole, Size screen) =>
    hole.top > screen.height - hole.bottom;

/// Whether [rect] sits fully inside the part of the screen the user can see,
/// leaving [topInset] and [bottomInset] clear for bars. If it does, the guide
/// leaves the scroll where it is.
bool featureGuideRectOnScreen(
  Rect rect,
  Size screen, {
  double topInset = 0,
  double bottomInset = 0,
}) =>
    rect.top >= topInset &&
    rect.bottom <= screen.height - bottomInset &&
    rect.height > 0;

/// The spotlight around [target], grown by [featureGuideHolePadding] and
/// kept on the screen.
Rect featureGuideHoleFor(Rect target, Size screen) {
  final grown = target.inflate(featureGuideHolePadding);
  return Rect.fromLTRB(
    math.max(grown.left, 0),
    math.max(grown.top, 0),
    math.min(grown.right, screen.width),
    math.min(grown.bottom, screen.height),
  );
}

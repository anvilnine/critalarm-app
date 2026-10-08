import 'dart:math' as math;
import 'dart:ui';

// The sizes a preview is drawn at. Each one was designed: a preview never
// stretches to fill the room it is given.

/// One of the three sizes a preview is drawn at.
enum PaywallPreviewClass {
  /// One glyph on the shared tile, 56 points at most. For a row or a list.
  small(56),

  /// The feature at work, 120 points at most. For a tile or a card.
  medium(120),

  /// The same scene with its words, 200 points at most. For the one
  /// preview a screen is about.
  large(200);

  const PaywallPreviewClass(this.edge);

  /// The longest side a preview of this class is drawn at.
  final double edge;
}

/// A box with a short side under this many points holds the glyph tile and
/// never a scene.
const double paywallPreviewSceneMinEdge = 88;

/// A box with a short side from this many points up holds the large scene.
const double paywallPreviewLargeMinEdge = 160;

/// The biggest class that reads in [box].
PaywallPreviewClass paywallPreviewClassFor(Size box) {
  final edge = box.shortestSide;
  if (edge < paywallPreviewSceneMinEdge) return PaywallPreviewClass.small;
  if (edge < paywallPreviewLargeMinEdge) return PaywallPreviewClass.medium;
  return PaywallPreviewClass.large;
}

/// The room a preview takes and the size it is drawn at inside that room.
typedef PaywallPreviewFit = ({
  PaywallPreviewClass sizeClass,
  Size box,
  Size drawn,
});

/// Works out what a preview draws from what its caller gave it.
///
/// - Neither: the small tile at its full size.
/// - [sizeClass] alone: that class at its full size.
/// - [box] alone: the biggest class that reads in the box.
/// - Both: [sizeClass], or a smaller one when the box is too small for it.
///
/// The drawing never grows past its class. In a bigger box it keeps its
/// class size and the caller centres it.
PaywallPreviewFit paywallPreviewFit({
  PaywallPreviewClass? sizeClass,
  Size? box,
}) {
  if (box == null) {
    final asked = sizeClass ?? PaywallPreviewClass.small;
    final size = Size.square(asked.edge);
    return (sizeClass: asked, box: size, drawn: size);
  }

  final fits = paywallPreviewClassFor(box);
  final used = sizeClass == null || sizeClass.index > fits.index
      ? fits
      : sizeClass;
  final drawn = used == PaywallPreviewClass.small
      // The tile is always a square.
      ? Size.square(math.min(box.shortestSide, used.edge))
      : Size(math.min(box.width, used.edge), math.min(box.height, used.edge));
  return (sizeClass: used, box: box, drawn: drawn);
}

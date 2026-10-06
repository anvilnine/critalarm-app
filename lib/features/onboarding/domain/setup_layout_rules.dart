// How a setup screen gives room when the system text size grows.
//
// The order is always the same: the face shrinks first and can go away
// entirely, then the spacing, and a screen that still does not fit scrolls.
// At the default text size nothing here changes a thing.

/// The size of the face on a task step, in logical pixels, or 0 when the face
/// should not be drawn at all.
///
/// [base] is the size at the default text size. [textScale] is how much the
/// system has grown the text (1 is the default) and [viewportHeight] is the
/// height of the screen. The room the text needs grows with [textScale], so
/// the room that is left is judged against the screen height as it would be
/// at the default size.
double setupFaceSizeFor({
  required double textScale,
  required double viewportHeight,
  double base = 80,
}) {
  if (textScale <= 1) return base;
  if (viewportHeight / textScale < _faceHiddenBelow) return 0;
  final shrunk = base / textScale;
  return shrunk < _faceFloor ? _faceFloor : shrunk;
}

/// The screen height, at the default text size, below which the face of a
/// task step is dropped once the text is larger than the default.
const double _faceHiddenBelow = 340;

/// The smallest a face gets before it is dropped.
const double _faceFloor = 32;

/// The least room the animation of an intro step keeps, in logical pixels.
///
/// At the default text size the animation keeps 380 and the page scrolls
/// when the words do not fit beside it. Once the text is larger the words
/// come first, so the animation keeps no room of its own and takes what is
/// left.
double introHeroMinHeightFor(double textScale) =>
    textScale <= 1 ? introHeroDefaultMinHeight : 0;

/// The room an intro animation keeps at the default text size.
const double introHeroDefaultMinHeight = 380;

/// Whether an intro animation is drawn when [height] is all the room it has.
/// Below this it is a stamp, so it goes away and the words keep the page.
bool introHeroFits(double height) => height >= _introHeroHiddenBelow;

const double _introHeroHiddenBelow = 120;

/// How tall a pinned button comes out at [textScale].
///
/// [minHeight] is the button's own height (36, 48 or 60), [fontSize] the size
/// of its label, and the label gets [verticalPadding] above and below. The
/// label grows with the text size, so a button only gets taller than its
/// minimum once the text is large enough to need it.
double setupButtonHeightFor({
  required double minHeight,
  required double fontSize,
  required double textScale,
  double verticalPadding = 8,
}) {
  final needed = fontSize * textScale + 2 * verticalPadding;
  return needed > minHeight ? needed : minHeight;
}

/// Whether the hook-up step pins the first-message row above its button.
///
/// The row is pinned so it is in view when the message lands. Once the text
/// is large it would take a third of the screen, so it moves into the page
/// under the command, where it scrolls with the rest.
bool setupPinsFirstMessageRow(double textScale) => textScale <= 1.5;

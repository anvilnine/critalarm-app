/// Widest the own-server line gets at text scale 1, in logical pixels. The
/// card's text column has to be this wide, times the text scale, for every
/// line to sit on one row without an awkward break.
const double countCardTextWidth = 290;

/// Room for the "See Hosted plans" button at text scale 1.
const double countCardButtonWidth = 170;

/// Gap between the text column and the button.
const double countCardGap = 12;

/// Whether the create form's count card puts its button under the text.
///
/// [innerWidth] is the width inside the card's padding. The card keeps the
/// side-by-side row only when the text column still has [countCardTextWidth]
/// (scaled with [textScale]) after the button and the gap. On the 375 and
/// 430 phones that is never the case, so both stack.
bool countCardStacks({required double innerWidth, required double textScale}) {
  final scale = textScale < 1 ? 1.0 : textScale;
  final needed =
      countCardTextWidth * scale + countCardGap + countCardButtonWidth * scale;
  return innerWidth < needed;
}

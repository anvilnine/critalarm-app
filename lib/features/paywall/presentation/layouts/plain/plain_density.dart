/// How much of each benefit row the plain layout draws. In order, each one
/// is shorter than the one before.
enum PlainDensity {
  /// The face, and every row with its picture, title and line.
  full,

  /// The second line of each row is gone.
  titles,

  /// The pictures are gone too: the face over a list of titles.
  bare,

  /// The face is gone. Every benefit is still named.
  bareNoFace,
}

/// The fullest density that fits in [room] points, where [heightOf] says
/// how tall the composition is at each.
///
/// A row is never dropped: at a large text size the rows lose their second
/// line, then their picture, then the face goes, and every benefit is
/// still on screen. When even the shortest does not fit, it is the answer
/// and the layout scrolls in its own box.
PlainDensity plainDensityFor({
  required double room,
  required double Function(PlainDensity density) heightOf,
}) {
  for (final density in PlainDensity.values) {
    if (heightOf(density) <= room) return density;
  }
  return PlainDensity.values.last;
}

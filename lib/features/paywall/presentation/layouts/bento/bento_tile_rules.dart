import 'dart:ui';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:flutter/foundation.dart';

/// Where a tile puts its benefit's line.
enum BentoLinePlace {
  /// The tile has no room for it. A screen reader still hears it.
  none,

  /// On the title's row, at the far end.
  beside,

  /// Under the title.
  below,
}

/// How a tile's words are set, and the height they take.
@immutable
class BentoTileText {
  const BentoTileText({
    required this.titleLines,
    required this.linePlace,
    required this.lineLines,
    required this.height,
    this.previewBeside = false,
  });

  /// Lines the title may take: 1 or 2.
  final int titleLines;
  final BentoLinePlace linePlace;

  /// Lines the line may take when it is [BentoLinePlace.below].
  final int lineLines;

  /// The height of the words. The preview gets the rest of the tile.
  final double height;

  /// True on a tile too short to stack: the title sits at the start, on
  /// one line, and the preview takes the rest of the row at full height.
  final bool previewBeside;
}

/// The space between a tile's words and its preview.
const double bentoTextGap = 6;

/// The space between a title and the line under or beside it.
const double bentoLineGap = 2;

/// The space between a title and a line on the same row.
const double bentoBesideGap = 8;

/// The least height a preview keeps before the words give way.
const double bentoMinPreview = 24;

/// Decides how a tile sets its words in [inner], its room less padding.
///
/// The preview comes first: the line shows only where the tile has room,
/// and a title takes a second line only when the preview keeps its height.
/// [titleWidth] and [lineWidth] are the widths on one line, and the two
/// heights are of one line each.
BentoTileText bentoTileText({
  required Size inner,
  required double titleWidth,
  required double titleLineHeight,
  required double lineWidth,
  required double lineLineHeight,
  required bool isLead,
}) {
  final fitsOneLine = titleWidth + 1 <= inner.width;
  final roomForTwo =
      inner.height - 2 * titleLineHeight - bentoTextGap >= bentoMinPreview;
  final titleLines = fitsOneLine || !roomForTwo ? 1 : 2;
  final titleHeight = titleLines * titleLineHeight;

  // A short line sits at the end of the title's row, as a note.
  if (!isLead &&
      fitsOneLine &&
      titleWidth + bentoBesideGap + lineWidth + 1 <= inner.width) {
    return BentoTileText(
      titleLines: 1,
      linePlace: BentoLinePlace.beside,
      lineLines: 1,
      height: titleLineHeight > lineLineHeight
          ? titleLineHeight
          : lineLineHeight,
    );
  }

  // Under the title, when the preview still keeps most of the tile.
  // Wrapping wastes some of each line, so the estimate runs a little long.
  final lineLines = inner.width <= 0
      ? 99
      : (lineWidth * 1.1 / inner.width).ceil().clamp(1, 99);
  final maxLineLines = isLead ? 3 : 2;
  final wordsHeight = titleHeight + bentoLineGap + lineLines * lineLineHeight;
  final previewShare = isLead ? 0.5 : 0.55;
  final previewLeft = inner.height - wordsHeight - bentoTextGap;
  if (lineLines <= maxLineLines &&
      previewLeft >= bentoMinPreview * 1.5 &&
      previewLeft >= inner.height * previewShare) {
    return BentoTileText(
      titleLines: titleLines,
      linePlace: BentoLinePlace.below,
      lineLines: lineLines,
      height: wordsHeight,
    );
  }

  // Too short to stack and wide enough for a row: the preview goes
  // beside the title and keeps the whole height.
  final stackedPreview = inner.height - titleHeight - bentoTextGap;
  final besideWidth = inner.width - titleWidth - bentoBesideGap;
  if (!isLead &&
      fitsOneLine &&
      stackedPreview < bentoMinPreview &&
      inner.height >= titleLineHeight &&
      besideWidth >= inner.height * 1.2) {
    return BentoTileText(
      titleLines: 1,
      linePlace: BentoLinePlace.none,
      lineLines: 0,
      height: titleLineHeight,
      previewBeside: true,
    );
  }

  return BentoTileText(
    titleLines: titleLines,
    linePlace: BentoLinePlace.none,
    lineLines: 0,
    height: titleHeight,
  );
}

/// How one tile is drawn at a moment of its entrance.
@immutable
class BentoEntrance {
  const BentoEntrance({
    required this.opacity,
    required this.scale,
    required this.rise,
  });

  /// The tile at rest: there, full size, in place.
  static const BentoEntrance rest = BentoEntrance(
    opacity: 1,
    scale: 1,
    rise: 0,
  );

  final double opacity;
  final double scale;

  /// Points below its place.
  final double rise;
}

/// Seconds before the first tile starts.
const double bentoEntranceStart = 0.05;

/// Seconds between one tile starting and the next.
const double bentoEntranceEach = 0.06;

/// Seconds one tile takes to come in.
const double bentoEntranceLength = 0.55;

/// The second every tile of a grid of [count] has come to rest by.
double bentoEntranceEnd(int count) =>
    bentoEntranceStart +
    (count < 1 ? 0 : count - 1) * bentoEntranceEach +
    bentoEntranceLength;

/// The tile whose turn is [turn] at clock second [t]: it grows from four
/// fifths, rises ten points and fades in, with a small overshoot, and ends
/// flat and upright. It never turns.
BentoEntrance bentoEntrance(int turn, double t) {
  final p = phase(
    stagger(turn, t, each: bentoEntranceEach, start: bentoEntranceStart),
    0,
    bentoEntranceLength,
  );
  if (p >= 1) return BentoEntrance.rest;
  final spring = AppCurves.easeSpring.transform(p);
  final out = AppCurves.easeOut.transform(p);
  return BentoEntrance(
    opacity: out.clamp(0.0, 1.0),
    scale: lerpDouble(0.8, 1, spring)!,
    rise: 10 * (1 - out),
  );
}

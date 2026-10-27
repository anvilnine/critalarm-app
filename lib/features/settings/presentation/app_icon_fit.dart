import 'dart:math' as math;

import 'package:critalarm/features/settings/presentation/app_icon_showcase_logic.dart';

/// The smallest icon the carousel draws. Below this the page scrolls instead.
const double kIconMinTile = 88;

/// Air around the centred icon for its tilt, its shadow and the pop.
const double kIconRoomRoomy = 56;
const double kIconRoomTight = 32;

/// The gap between the carousel and the dots, the dots' own height, and the
/// gap between the dots and the name.
const double kIconDotsGap = 12;
const double kIconDotsHeight = 32;
const double kIconNameGap = 16;

/// The gap between the name and the plan badge.
const double kIconBadgeGap = 8;

/// A tile at or above this size keeps the roomy air around it.
const double _kRoomyFrom = 140;

/// How far from the top of the badge to its text: padding and border.
const double _kBadgeChrome = 9;

/// The line height of the badge's 11 point text.
const double _kBadgeLine = 11 * 1.2;

/// The height of the plan badge under the icon's name at [textScale].
double iconBadgeHeight(double textScale) =>
    _kBadgeChrome + _kBadgeLine * textScale;

/// How the App icon page lays out its body in the room it has.
class IconPageFit {
  const IconPageFit({
    required this.tile,
    required this.room,
    required this.sideBySide,
  });

  /// The side of the centred icon.
  final double tile;

  /// Air above and below the icon inside the carousel.
  final double room;

  /// True on a short display: the carousel stands at the left, and the name,
  /// the badge and the dots stand at the right.
  final bool sideBySide;

  double get carouselHeight => tile + room;
}

/// Sizes the carousel for a body [width] by [height] points.
///
/// [nameHeight] is the tallest of the four names at the current text size,
/// [headlineHeight] is what the welcome line takes (0 when it is not shown),
/// and [badgeHeight] is what the plan badge takes (0 when no icon is
/// locked). The icon is never wider than the width gives it, and it shrinks
/// before it lets the name or the badge fall off the bottom, down to
/// [kIconMinTile]. Below that the page scrolls.
IconPageFit fitIconPage({
  required double width,
  required double height,
  required double nameHeight,
  required double headlineHeight,
  required double badgeHeight,
  required bool sideBySide,
}) {
  if (sideBySide) {
    // The carousel takes 60% of the width and shows each icon in 60% of
    // that, so an icon wider than 0.36 of the width would touch its
    // neighbour.
    final widthTile = math.max(kIconMinTile, width * 0.36 * 0.95);
    final tile = _between(height - kIconRoomTight, kIconMinTile, widthTile);
    return IconPageFit(tile: tile, room: kIconRoomTight, sideBySide: true);
  }
  final widthTile = showcaseTileSize(width);
  final below =
      kIconDotsGap +
      kIconDotsHeight +
      kIconNameGap +
      nameHeight +
      (badgeHeight > 0 ? kIconBadgeGap + badgeHeight : 0);
  final free = height - headlineHeight - below;
  var room = kIconRoomRoomy;
  var tile = free - room;
  if (tile < _kRoomyFrom) {
    room = kIconRoomTight;
    tile = free - room;
  }
  return IconPageFit(
    tile: _between(tile, kIconMinTile, widthTile),
    room: room,
    sideBySide: false,
  );
}

double _between(double v, double lo, double hi) =>
    math.min(hi, math.max(lo, v));

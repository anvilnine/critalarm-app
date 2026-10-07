import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Where everything in the Sheet layout sits on one phone.
///
/// The screen behind is a picture with fixed sizes, so the lit row's place
/// is known before anything is laid out and the sheet can stop just under
/// it.
@immutable
class SheetPlan {
  const SheetPlan({
    required this.isCompact,
    required this.topInset,
    required this.rowsAbove,
    required this.litHeight,
  });

  /// The most quiet rows drawn between the title and the lit row.
  static const int maxRowsAbove = 2;

  final bool isCompact;

  /// The status bar's height.
  final double topInset;

  /// Quiet rows between the title and the lit row.
  final int rowsAbove;

  /// The lit row's height.
  final double litHeight;

  /// The back row at the top of the screen behind.
  double get navHeight => isCompact ? 32 : 44;

  double get titleSize => isCompact ? 26 : 32;

  /// The title and the gap under it.
  double get titleBlock => isCompact ? 38 : 52;

  double get rowHeight => isCompact ? 44 : 50;
  double get rowGap => isCompact ? 6 : 8;

  /// The face that looks over the sheet's edge.
  double get faceSize => isCompact ? 48 : 56;

  /// The room between the lit row and the sheet. The top half of the face
  /// sits in it.
  double get peekGap => faceSize / 2 + (isCompact ? 2 : 8);

  double get litTop =>
      topInset + navHeight + titleBlock + rowsAbove * (rowHeight + rowGap);

  double get litBottom => litTop + litHeight;

  /// The sheet's top edge.
  double get sheetTop => litBottom + peekGap;
}

/// The lit row's height: a switch with a count under it, or a locked row.
double sheetLitHeight({required bool isCompact, required bool isSwitch}) =>
    isSwitch ? (isCompact ? 92 : 98) : (isCompact ? 74 : 80);

/// The height the sheet would like at the default text size: its own part
/// at a comfortable size, over the buy block.
double sheetWantedHeight({
  required bool isCompact,
  required bool isHosted,
  required int benefitCount,
  required double bottomInset,
}) {
  final others = math.max(0, benefitCount - 1);
  // The buy block's height is the kit's to decide. These are what it
  // measures today, and being wrong only moves one quiet row.
  final buyBlock = isHosted ? 262.0 : 180.0;
  final handleAndHeadline = isCompact ? 72.0 : 92.0;
  final lead = others == 0
      ? (isCompact ? 150.0 : 190.0)
      : (isCompact ? 64.0 : 96.0);
  final rest = others == 0 ? 0.0 : (isCompact ? 82.0 : 96.0);
  final gaps = isCompact ? 14.0 : 20.0;
  return handleAndHeadline + lead + rest + gaps + buyBlock + bottomInset;
}

/// Lays the screen out for one phone.
///
/// It keeps as many quiet rows above the lit row as leave the sheet the
/// height it wants, so a short sheet shows more of the screen behind and a
/// long one less. The lit row is always above the sheet. Past the default
/// text size the sheet needs every point, so no quiet row is kept.
SheetPlan sheetPlanFor({
  required double screenHeight,
  required double topInset,
  required double bottomInset,
  required bool isCompact,
  required bool isHosted,
  required bool isSwitch,
  required int benefitCount,
  double textScale = 1,
}) {
  final litHeight = sheetLitHeight(isCompact: isCompact, isSwitch: isSwitch);
  SheetPlan plan(int rows) => SheetPlan(
    isCompact: isCompact,
    topInset: topInset,
    rowsAbove: rows,
    litHeight: litHeight,
  );
  if (textScale > 1.01) return plan(0);

  final wanted = sheetWantedHeight(
    isCompact: isCompact,
    isHosted: isHosted,
    benefitCount: benefitCount,
    bottomInset: bottomInset,
  );
  for (var rows = SheetPlan.maxRowsAbove; rows > 0; rows--) {
    if (screenHeight - plan(rows).sheetTop >= wanted) return plan(rows);
  }
  return plan(0);
}

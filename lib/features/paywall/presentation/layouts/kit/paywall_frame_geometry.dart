import 'dart:math' as math;

import 'package:critalarm/design/components/screen_scaffold.dart';
import 'package:critalarm/design/fold.dart';
import 'package:critalarm/design/size_class.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

// Where a paywall sits in a window wider than a phone. Numbers only, so the
// rules that pick them have tests.

/// The room a layout keeps at each side of its words, and the buy block at
/// each side of its plans and button.
const double paywallColumnPadding = 20;

/// The widest a paywall's one column grows: stage, words, plans, button and
/// legal lines, centred in the window. On a phone the column is the window.
/// It is the buy block's width, so the words and the button share their
/// left edge: both are `AppSize.actionMaxWidth` wide inside the padding.
const double paywallColumnMaxWidth =
    AppSize.actionMaxWidth + 2 * paywallColumnPadding;

/// The tallest the one column grows on a tablet held upright. Past it the
/// column centres in the window's height, so the stage, the words and the
/// plans stay one group and the room left over is above and below it. A
/// phone is never this tall, so it keeps the whole window.
const double paywallColumnMaxHeight = 900;

/// The frame the stage and the offer share on a wide window, centred.
const double paywallWideFrameWidth = 1040;

/// The offer column of a split paywall: pips, headline, benefits, plans,
/// button and legal lines.
const double paywallOfferWidth = 420;

/// Between the stage and the offer on a wide window.
const double paywallWideGap = 48;

/// Kept clear at each side of a wide frame when the window is narrower than
/// the frame and this twice.
const double paywallWideMargin = 32;

/// How a split paywall is held.
enum PaywallSplitKind {
  /// A wide window: the stage at the start, the offer at the end.
  wide,

  /// A half-open foldable held like a book: the stage in the start pane,
  /// the offer in the end pane.
  book,

  /// A half-open foldable on a table: the stage in the top half, the offer
  /// in the bottom half.
  tabletop,
}

/// Where the two parts of a split paywall go, in window coordinates.
@immutable
class PaywallSplit {
  const PaywallSplit({
    required this.kind,
    required this.stage,
    required this.offer,
  });

  final PaywallSplitKind kind;

  /// The box the stage fills: the mascot and the card, as large as it
  /// allows.
  final Rect stage;

  /// The box the offer is laid out in. It is never wider than
  /// [paywallOfferWidth]. The offer centres in its height and scrolls its
  /// words when they do not fit, with the buy block pinned under them.
  final Rect offer;

  @override
  bool operator ==(Object other) =>
      other is PaywallSplit &&
      other.kind == kind &&
      other.stage == stage &&
      other.offer == offer;

  @override
  int get hashCode => Object.hash(kind, stage, offer);

  @override
  String toString() => 'PaywallSplit(${kind.name}, stage $stage, offer $offer)';
}

/// The split for a paywall that can draw one, or null for the one column.
///
/// - Book posture: the stage in the start pane, the offer in the end pane.
/// - Tabletop posture: the stage in the top half, the offer in the bottom
///   half, centred and at most [paywallOfferWidth] wide.
/// - A wide window with no fold (`AppScreenScaffold.showsDetailFor`): a
///   frame of [paywallWideFrameWidth], centred, the stage at the start and
///   the offer, [paywallOfferWidth] wide, at the end.
///
/// A fold wins over the size class, as everywhere in the app.
PaywallSplit? paywallSplitFor({
  required Size window,
  required AppSize size,
  required AppFold fold,
  TextDirection direction = TextDirection.ltr,
}) {
  if (!fold.isNone) {
    final panes = fold.panes(window, direction: direction);
    return PaywallSplit(
      kind: fold.isBook ? PaywallSplitKind.book : PaywallSplitKind.tabletop,
      stage: panes.first,
      offer: _centredIn(panes.second, paywallOfferWidth),
    );
  }
  if (!AppScreenScaffold.showsDetailFor(size, fold)) return null;

  final frame = math.min(
    paywallWideFrameWidth,
    window.width - paywallWideMargin * 2,
  );
  final left = (window.width - frame) / 2;
  final stageWidth = frame - paywallOfferWidth - paywallWideGap;
  final isLtr = direction == TextDirection.ltr;
  final stage = Rect.fromLTWH(
    isLtr ? left : left + frame - stageWidth,
    0,
    stageWidth,
    window.height,
  );
  final offer = Rect.fromLTWH(
    isLtr ? left + frame - paywallOfferWidth : left,
    0,
    paywallOfferWidth,
    window.height,
  );
  return PaywallSplit(kind: PaywallSplitKind.wide, stage: stage, offer: offer);
}

/// The split a frame lays out, or null for the one column.
///
/// A layout that [splits] gets `paywallSplitFor`. Every other layout gets
/// it only on a half-open foldable, where the fold rule wins over the
/// layout: the frame then puts the layout's own part in the stage box and
/// the buy block in the offer box. On a wide window such a layout keeps
/// the one column.
PaywallSplit? paywallFrameSplitFor({
  required Size window,
  required AppSize size,
  required AppFold fold,
  required bool splits,
  TextDirection direction = TextDirection.ltr,
}) => splits || !fold.isNone
    ? paywallSplitFor(
        window: window,
        size: size,
        fold: fold,
        direction: direction,
      )
    : null;

/// The width of the one column in a box [width] wide: the whole box on a
/// phone, [paywallColumnMaxWidth] from the medium size class up.
double paywallColumnWidthFor(double width) => width >= AppSize.mediumMinWidth
    ? math.min(width, paywallColumnMaxWidth)
    : width;

/// The widest the buy block of the one column grows in a box [width]
/// wide, with [padding] at each side of its plans and button: none on a
/// phone, and from the medium size class up the plans and Get Cloud stop at
/// `AppSize.actionMaxWidth`, as every pinned action in the app does.
double? paywallBuyBlockMaxWidthFor({
  required double width,
  required double padding,
}) => width >= AppSize.mediumMinWidth
    ? AppSize.actionMaxWidth + padding * 2
    : null;

/// The height of the one column in a box [height] tall and [width] wide:
/// the whole box on a phone, at most [paywallColumnMaxHeight] from the
/// medium size class up.
double paywallColumnHeightFor({
  required double width,
  required double height,
}) => width >= AppSize.mediumMinWidth
    ? math.min(height, paywallColumnMaxHeight)
    : height;

/// Whether the plans of a split offer stack, one card per row: an offer
/// pane narrower than a phone (a book posture pane of a Galaxy Fold) has
/// the height for it and not the width for two cards side by side.
bool paywallSplitStacksPlans(PaywallSplit split) =>
    split.offer.width < AppSize.narrowMaxWidth &&
    split.offer.height >= paywallStackedPlansMinHeight;

/// The least offer height [paywallSplitStacksPlans] stacks the plans in.
const double paywallStackedPlansMinHeight = 700;

/// How much a split stage of [box] is drawn up from the size the stage
/// parts are drawn at. The mascot and the card stop growing at a phone's
/// largest stage, so a wide column draws that stage larger, up to
/// [paywallStageMaxScale]. A pane the size of a phone is drawn at 1.
double paywallStageScaleFor(Size box) =>
    (box.shortestSide / paywallStageBaseEdge).clamp(1, paywallStageMaxScale);

/// The short side a stage needs before [paywallStageScaleFor] draws it up.
const double paywallStageBaseEdge = 440;

/// The most a stage is drawn up.
const double paywallStageMaxScale = 1.4;

Rect _centredIn(Rect box, double maxWidth) {
  final width = math.min(box.width, maxWidth);
  return Rect.fromLTWH(
    box.left + (box.width - width) / 2,
    box.top,
    width,
    box.height,
  );
}

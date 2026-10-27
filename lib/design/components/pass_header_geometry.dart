import 'dart:math' as math;

import 'package:critalarm/design/components/pass_page.dart';
import 'package:critalarm/design/components/pass_route.dart';
import 'package:critalarm/design/tokens/typography.dart';
import 'package:flutter/foundation.dart';

/// The value's size once the header has collapsed into the bar.
const double kPassCollapsedValueSize = 22;

/// The most the text scale grows the collapsed value. The bar is one fixed
/// height, so a value at twice the size would not fit beside the ring.
const double kPassCollapsedMaxTextScale = 1.15;

/// The gap between the back ring and the collapsed label.
const double kPassCollapsedGap = 12;

/// The gap between the label and the value at rest and once collapsed.
const double _kRestGap = 4;
const double _kCollapsedGap = 2;

/// The label's size and line height, as the card draws it.
const double _kLabelSize = 11;
const double _kLabelLineHeight = 1.2;

/// The value's line height, as the card draws it.
const double _kValueLineHeight = 1.05;

/// The share of a tall value's extra height that the collapse adds to its
/// distance. At 0.4 the lines of a value that wraps at rest stay clear of the
/// body for any size the value can have.
const double _kTallShare = 0.4;

/// How much of the collapse the sideways move takes. The label has to be
/// clear of the ring's right edge before it rises past the ring's bottom
/// edge, so it moves over in the first part of the way.
const double _kSidewaysShare = 0.28;

/// Where the pass page's label and value are, for one scroll offset. Pure.
@immutable
class PassHeaderPose {
  const PassHeaderPose({
    required this.progress,
    required this.labelLeft,
    required this.labelTop,
    required this.labelWidth,
    required this.labelHeight,
    required this.valueLeft,
    required this.valueTop,
    required this.valueWidth,
    required this.valueSize,
    required this.valueScale,
    required this.valueMaxLines,
    required this.distance,
  });

  /// 0 at rest and 1 once collapsed.
  final double progress;

  /// The label's box, from the left edge of the column and the top of the
  /// display.
  final double labelLeft;
  final double labelTop;
  final double labelWidth;
  final double labelHeight;

  /// The value's box, in the same coordinates. Its height follows its text.
  final double valueLeft;
  final double valueTop;
  final double valueWidth;

  /// The value's font size before scaling, and the text scale it is drawn at.
  final double valueSize;
  final double valueScale;

  /// How many lines the value may take, or null for as many as it needs at
  /// rest. Once collapsed it is one line, ending in an ellipsis when it is
  /// long. On the way it keeps no more lines than it had at rest.
  final int? valueMaxLines;

  /// How far the page scrolls before the header is collapsed.
  final double distance;

  bool get isCollapsed => progress >= 1;

  @override
  bool operator ==(Object other) =>
      other is PassHeaderPose &&
      other.progress == progress &&
      other.labelLeft == labelLeft &&
      other.labelTop == labelTop &&
      other.labelWidth == labelWidth &&
      other.labelHeight == labelHeight &&
      other.valueLeft == valueLeft &&
      other.valueTop == valueTop &&
      other.valueWidth == valueWidth &&
      other.valueSize == valueSize &&
      other.valueScale == valueScale &&
      other.valueMaxLines == valueMaxLines &&
      other.distance == distance;

  @override
  int get hashCode => Object.hash(
    progress,
    labelLeft,
    labelTop,
    labelWidth,
    labelHeight,
    valueLeft,
    valueTop,
    valueWidth,
    valueSize,
    valueScale,
    valueMaxLines,
    distance,
  );

  @override
  String toString() =>
      'PassHeaderPose(progress $progress, label $labelLeft,$labelTop, '
      'value $valueLeft,$valueTop at $valueSize x $valueScale)';
}

/// The label and value of a pass page when the page is scrolled by [offset].
///
/// At rest (offset 0) the label sits at the page's header spot, [safeTop] +
/// [kPassHeaderTop] from the top, with the value under it at
/// [restValueSize]. As the page scrolls both rise and move right toward the
/// space beside the back ring, and the value steps down to
/// [kPassCollapsedValueSize]. Collapsed, the label and the value are one block
/// centred on the ring's centre line, from [kPassCollapsedGap] right of the
/// ring to the right edge, or to the trailing control when [trailingWidth] is
/// more than zero.
///
/// [width] is the column's width, [textScale] the text scale. The label stops
/// growing at the chrome limit, like the other chrome. The collapsed value
/// stops at [kPassCollapsedMaxTextScale]. [restValueHeight] is the height the
/// value takes at rest, which is the height of its wrapped text; leave it out
/// for a one line value.
///
/// The positions follow [offset] only. There is no clock, so reduce motion
/// changes nothing.
PassHeaderPose passHeaderPoseAt({
  required double offset,
  required double width,
  required double textScale,
  double ringSize = kPassRingSize,
  double trailingWidth = 0,
  double safeTop = 0,
  double restValueSize = kPassPageValueSize,
  double? restValueHeight,
}) {
  final labelScale = math.min(textScale, kChromeMaxTextScale);
  final labelHeight = _kLabelSize * _kLabelLineHeight * labelScale;
  final collapsedScale = math.min(textScale, kPassCollapsedMaxTextScale);

  final restLineHeight = restValueSize * textScale * _kValueLineHeight;
  final collapsedLineHeight =
      kPassCollapsedValueSize * collapsedScale * _kValueLineHeight;
  final restHeight = math.max(
    restValueHeight ?? restLineHeight,
    restLineHeight,
  );

  // Collapsed, the label and the value are one block on the ring's centre
  // line.
  final block = labelHeight + _kCollapsedGap + collapsedLineHeight;
  final ringCentre = safeTop + kPassRingTop + ringSize / 2;
  final collapsedTop = ringCentre - block / 2;
  final restTop = safeTop + kPassHeaderTop;

  // The block rises as far as the label has to, and a taller value adds a
  // share of the height it gives up. The page body rises one to one with the
  // scroll, so a longer collapse keeps the value's lines clear of it.
  final distance = math.max<double>(
    1,
    restTop - collapsedTop + _kTallShare * (restHeight - collapsedLineHeight),
  );
  final t = (offset / distance).clamp(0.0, 1.0);

  final sideways = _smooth((t / _kSidewaysShare).clamp(0.0, 1.0));
  const restLeft = kPassSidePadding;
  final collapsedLeft = kPassRingLeft + ringSize + kPassCollapsedGap;
  final restRight = width - kPassSidePadding;
  final collapsedRight = trailingWidth > 0
      ? width - kPassRingLeft - trailingWidth - kPassCollapsedGap
      : width - kPassSidePadding;
  final left = _lerp(restLeft, collapsedLeft, sideways);
  final right = math.max(left, _lerp(restRight, collapsedRight, sideways));

  final top = _lerp(restTop, collapsedTop, t);
  final size = _lerp(restValueSize, kPassCollapsedValueSize, t);
  final scale = _lerp(textScale, collapsedScale, t);
  final gap = _lerp(_kRestGap, _kCollapsedGap, t);

  // The value keeps the lines it had at rest and gives them all up but one
  // when it is collapsed.
  int? maxLines;
  if (t >= 1) {
    maxLines = 1;
  } else if (t > 0) {
    maxLines = math.max(1, (restHeight / restLineHeight).round());
  }

  return PassHeaderPose(
    progress: t,
    labelLeft: left,
    labelTop: top,
    labelWidth: right - left,
    labelHeight: labelHeight,
    valueLeft: left,
    valueTop: top + labelHeight + gap,
    valueWidth: right - left,
    valueSize: size,
    valueScale: scale,
    valueMaxLines: maxLines,
    distance: distance,
  );
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _smooth(double x) => x * x * (3 - 2 * x);

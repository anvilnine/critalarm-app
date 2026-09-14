import 'package:flutter/widgets.dart';

/// How much room the display gives a screen.
///
/// Every screen picks its layout from this and nothing else. The steps match
/// the layout proposal: a phone is compact, an iPad mini upright is medium,
/// an iPad on its side is expanded.
enum AppSizeClass {
  /// One column, edge to edge, tab bar along the bottom.
  compact,

  /// One column capped at [AppSize.contentMaxWidth] and centred.
  medium,

  /// Two panes, list beside detail, tab bar stood up as a rail.
  expanded,
}

/// What a screen needs to know about the display it is drawn on.
///
/// Read it with `AppSize.of(context)`. The thresholds live here so no screen
/// hardcodes a width of its own.
@immutable
class AppSize {
  const AppSize(this.width, this.height);

  AppSize.from(Size size) : this(size.width, size.height);

  AppSize.of(BuildContext context) : this.from(MediaQuery.sizeOf(context));

  /// Below this the display is compact.
  static const double mediumMinWidth = 600;

  /// Two panes need this much width and this much height. A big phone on its
  /// side is wide enough but far too short, so it stays on one column.
  static const double expandedMinWidth = 900;
  static const double expandedMinHeight = 600;

  /// A folded Razr cover screen and any phone on its side land here.
  static const double shortMaxHeight = 500;

  /// A Galaxy Fold cover screen lands here.
  static const double narrowMaxWidth = 360;

  /// How wide a single column of content is allowed to get.
  static const double contentMaxWidth = 560;

  final double width;
  final double height;

  AppSizeClass get sizeClass {
    if (width >= expandedMinWidth && height >= expandedMinHeight) {
      return AppSizeClass.expanded;
    }
    if (width >= mediumMinWidth) return AppSizeClass.medium;
    return AppSizeClass.compact;
  }

  bool get isCompact => sizeClass == AppSizeClass.compact;
  bool get isMedium => sizeClass == AppSizeClass.medium;
  bool get isExpanded => sizeClass == AppSizeClass.expanded;

  /// Too short to stand the face above the words.
  bool get isShort => height < shortMaxHeight;

  /// Too narrow to spell out the tab labels.
  bool get isNarrow => width < narrowMaxWidth;

  /// Empty space to leave either side so the column sits in the middle.
  double get sideGutter =>
      width <= contentMaxWidth ? 0 : (width - contentMaxWidth) / 2;

  @override
  bool operator ==(Object other) =>
      other is AppSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

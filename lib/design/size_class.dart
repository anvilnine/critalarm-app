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

/// Where the tab bar sits.
enum AppNavPlacement {
  /// The floating pill along the bottom edge.
  bottom,

  /// Stood up as a rail down the left edge.
  left,

  /// Stood up as a rail down the right edge.
  right,
}

/// Tells [AppSize] whether the app is running on an iPhone, which is the one
/// thing about the device its width and height cannot answer: an unfolded
/// iPhone Fold and an iPad mini are about the same size. Placed once above the
/// router, so every screen reads the same answer.
class AppDeviceScope extends InheritedWidget {
  const AppDeviceScope({
    required this.isIphone,
    required super.child,
    super.key,
  });

  final bool isIphone;

  static bool isIphoneOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppDeviceScope>()?.isIphone ??
      false;

  @override
  bool updateShouldNotify(AppDeviceScope oldWidget) =>
      oldWidget.isIphone != isIphone;
}

/// What a screen needs to know about the display it is drawn on.
///
/// Read it with `AppSize.of(context)`. The thresholds live here so no screen
/// hardcodes a width of its own.
@immutable
class AppSize {
  const AppSize(this.width, this.height, {this.isIphone = false});

  AppSize.from(Size size, {bool isIphone = false})
    : this(size.width, size.height, isIphone: isIphone);

  AppSize.of(BuildContext context)
    : this.from(
        MediaQuery.sizeOf(context),
        isIphone: AppDeviceScope.isIphoneOf(context),
      );

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

  /// No iPhone that does not fold has a short side this long, so an iPhone
  /// display past it is an unfolded iPhone Fold. The biggest Pro Max is 440.
  static const double foldMinShortSide = 600;

  final double width;
  final double height;

  /// True on an iPhone. Only used to tell an unfolded iPhone Fold apart from
  /// an iPad, which is about the same size.
  final bool isIphone;

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

  /// An iPhone Fold opened up.
  bool get isUnfoldedIphone =>
      isIphone && (width < height ? width : height) >= foldMinShortSide;

  /// Where the tab bar goes. An unfolded iPhone Fold stands it up on the
  /// right. Anything on its side, and anything wide enough for two panes,
  /// stands it up on the left, so a short landscape display keeps its height
  /// for content. Everything else keeps it along the bottom.
  AppNavPlacement get navPlacement {
    if (isUnfoldedIphone) return AppNavPlacement.right;
    if (isExpanded || width > height) return AppNavPlacement.left;
    return AppNavPlacement.bottom;
  }

  /// True when the tab bar is stood up as a rail on either side.
  bool get hasRail => navPlacement != AppNavPlacement.bottom;

  /// Empty space to leave either side so the column sits in the middle.
  double get sideGutter =>
      width <= contentMaxWidth ? 0 : (width - contentMaxWidth) / 2;

  @override
  bool operator ==(Object other) =>
      other is AppSize &&
      other.width == width &&
      other.height == height &&
      other.isIphone == isIphone;

  @override
  int get hashCode => Object.hash(width, height, isIphone);
}

import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:critalarm/design/size_class.dart';
import 'package:flutter/widgets.dart';

/// How a folding display is held, read from its fold.
enum AppPosture {
  /// No fold splits the window: a phone, a tablet, a foldable opened flat.
  none,

  /// The fold runs top to bottom, like an open book. Two panes side by side.
  book,

  /// The fold runs left to right, like a laptop. A top half and a bottom half.
  tabletop,
}

/// The one fold or hinge that splits the window, if there is one.
///
/// Built on what Flutter ships (`MediaQuery.displayFeatures`), no package.
/// A fold counts while it is half opened, and a hinge counts whenever it has
/// a width, because a hinge hides pixels even when the device is flat. A fold
/// opened flat is no fold, so a Galaxy Fold laid flat keeps the normal size
/// classes.
///
/// Read it with `AppFold.of(context)`, or build one from plain values with
/// [AppFold.fromFeatures] (that is what the unit tests do).
@immutable
class AppFold {
  const AppFold._(this.posture, this.bounds);

  /// The one feature in [features] that splits a window of [window], in
  /// window coordinates (logical pixels), or [none].
  ///
  /// A feature that runs the full height is [AppPosture.book]. One that runs
  /// the full width is [AppPosture.tabletop]. Cutouts and anything that runs
  /// neither way are ignored.
  factory AppFold.fromFeatures(Iterable<DisplayFeature> features, Size window) {
    for (final feature in features) {
      if (!_splits(feature)) continue;
      final b = feature.bounds;
      final fullHeight = b.top <= 0 && b.bottom >= window.height;
      final fullWidth = b.left <= 0 && b.right >= window.width;
      if (fullHeight && !fullWidth) return AppFold._(AppPosture.book, b);
      if (fullWidth && !fullHeight) return AppFold._(AppPosture.tabletop, b);
    }
    return none;
  }

  /// The fold of the window [context] is drawn in.
  ///
  /// Inside a pane of [AppFoldSplit] this is [none]: each pane gets a
  /// `MediaQuery` without display features, so the phone layout runs in it.
  factory AppFold.of(BuildContext context) => AppFold.fromFeatures(
    MediaQuery.displayFeaturesOf(context),
    MediaQuery.sizeOf(context),
  );

  /// The window has no fold.
  static const AppFold none = AppFold._(AppPosture.none, Rect.zero);

  /// How far the band reaches past the fold on each side.
  static const double bandMargin = 16;

  /// How the display is held.
  final AppPosture posture;

  /// The feature's own bounds. A fold has no thickness, so this is a line.
  final Rect bounds;

  bool get isNone => posture == AppPosture.none;
  bool get isBook => posture == AppPosture.book;
  bool get isTabletop => posture == AppPosture.tabletop;

  /// The fold band: [bounds] grown by [bandMargin] on the two sides that face
  /// the panes. At scroll offset 0 no text line, button, field, face or dark
  /// panel may overlap it. Scrolling content may pass through. Empty with no
  /// fold.
  Rect get band => switch (posture) {
    AppPosture.none => Rect.zero,
    AppPosture.book => Rect.fromLTRB(
      bounds.left - bandMargin,
      bounds.top,
      bounds.right + bandMargin,
      bounds.bottom,
    ),
    AppPosture.tabletop => Rect.fromLTRB(
      bounds.left,
      bounds.top - bandMargin,
      bounds.right,
      bounds.bottom + bandMargin,
    ),
  };

  /// The two panes of a window of [window], with the band between them.
  ///
  /// Book: `first` is the start pane (the left one when [direction] is
  /// left to right) and `second` the end pane. Tabletop: `first` is the top
  /// half and `second` the bottom half. With no fold both are the whole
  /// window.
  ({Rect first, Rect second}) panes(
    Size window, {
    TextDirection direction = TextDirection.ltr,
  }) {
    final whole = Offset.zero & window;
    final band = this.band;
    switch (posture) {
      case AppPosture.none:
        return (first: whole, second: whole);
      case AppPosture.book:
        final left = Rect.fromLTRB(0, 0, math.max(0, band.left), window.height);
        final right = Rect.fromLTRB(
          math.min(window.width, band.right),
          0,
          window.width,
          window.height,
        );
        return direction == TextDirection.ltr
            ? (first: left, second: right)
            : (first: right, second: left);
      case AppPosture.tabletop:
        return (
          first: Rect.fromLTRB(0, 0, window.width, math.max(0, band.top)),
          second: Rect.fromLTRB(
            0,
            math.min(window.height, band.bottom),
            window.width,
            window.height,
          ),
        );
    }
  }

  static bool _splits(DisplayFeature feature) {
    final isFoldOrHinge =
        feature.type == DisplayFeatureType.fold ||
        feature.type == DisplayFeatureType.hinge;
    if (!isFoldOrHinge) return false;
    if (feature.state == DisplayFeatureState.postureHalfOpened) return true;
    final b = feature.bounds;
    return feature.type == DisplayFeatureType.hinge &&
        (b.width > 0 || b.height > 0);
  }

  @override
  bool operator ==(Object other) =>
      other is AppFold && other.posture == posture && other.bounds == bounds;

  @override
  int get hashCode => Object.hash(posture, bounds);

  @override
  String toString() => 'AppFold(${posture.name}, $bounds)';
}

/// Where the shell puts the tab bar on a display of [size] with [fold], and
/// so where every screen leaves room for it. The one rule the shell, the
/// scaffold and [AppFold] users share.
///
/// Book posture beats the size class: the bar is always the pill at the foot
/// of the start pane, never a rail, so it does not cross the fold. Otherwise
/// it is [AppSize.navPlacement] (in tabletop posture the rail or pill sits in
/// the bottom half, see [navAreaFor]).
AppNavPlacement navPlacementFor(AppSize size, AppFold fold) =>
    fold.isBook ? AppNavPlacement.bottom : size.navPlacement;

/// The part of a window of [window] the tab bar or rail floats in: the start
/// pane in book posture, the bottom half in tabletop posture, the whole
/// window otherwise. Search opens in the same part.
Rect navAreaFor(
  Size window,
  AppFold fold, {
  TextDirection direction = TextDirection.ltr,
}) {
  final panes = fold.panes(window, direction: direction);
  return switch (fold.posture) {
    AppPosture.book => panes.first,
    AppPosture.tabletop => panes.second,
    AppPosture.none => Offset.zero & window,
  };
}

/// True when [box] covers part of [band]. Boxes that only touch its edge, and
/// empty boxes, are clear.
bool boxCrossesFold(Rect box, Rect band) {
  if (box.isEmpty || band.isEmpty) return false;
  return box.left < band.right &&
      box.right > band.left &&
      box.top < band.bottom &&
      box.bottom > band.top;
}

/// True when any of [boxes] covers part of the fold [band]. The fold
/// clearance check in `tool/fold_clearance.dart` feeds it the render boxes of
/// every text, button and face on screen at scroll offset 0.
bool foldOverlaps(Iterable<Rect> boxes, Rect band) =>
    boxes.any((box) => boxCrossesFold(box, band));

/// The `MediaQuery` a pane at [pane] (window coordinates) gets inside a
/// window described by [window].
///
/// The pane's own size, and only the part of each inset that reaches into the
/// pane: a status bar along the top edge pads the top pane, not the bottom
/// one, and a keyboard pads the bottom half before it reaches the top. No
/// display features, so `AppSize.of` and `AppFold.of` inside a 329 wide pane
/// answer a compact phone with no fold.
MediaQueryData foldPaneMediaQuery(MediaQueryData window, Rect pane) {
  final size = window.size;
  EdgeInsets clip(EdgeInsets insets) => EdgeInsets.fromLTRB(
    math.max(0, insets.left - pane.left),
    math.max(0, insets.top - pane.top),
    math.max(0, insets.right - (size.width - pane.right)),
    math.max(0, insets.bottom - (size.height - pane.bottom)),
  );
  return window.copyWith(
    size: pane.size,
    padding: clip(window.padding),
    viewPadding: clip(window.viewPadding),
    viewInsets: clip(window.viewInsets),
    systemGestureInsets: clip(window.systemGestureInsets),
    displayFeatures: const <DisplayFeature>[],
  );
}

/// Lays out the two parts of a screen around a fold.
///
/// - Book: [stage] in the start pane, [body] in the end pane.
/// - Tabletop: [stage] in the top half, [body] (with every pinned action) in
///   the bottom half.
///
/// The fold band stays empty between them. Each pane gets its own
/// `MediaQuery` from [foldPaneMediaQuery], so the phone layout runs unchanged
/// inside it. With no fold this shows [unfolded], or [stage] above [body]
/// when there is none.
///
/// It reads the fold in window coordinates, so place it where it fills the
/// window, as a screen's root does.
class AppFoldSplit extends StatelessWidget {
  const AppFoldSplit({
    required this.stage,
    required this.body,
    this.unfolded,
    super.key,
  });

  /// The part that holds still: a face and its panel.
  final Widget stage;

  /// The part that scrolls, and the actions.
  final Widget body;

  /// What to show with no fold. Null stacks [stage] above [body].
  final Widget? unfolded;

  @override
  Widget build(BuildContext context) {
    final fold = AppFold.of(context);
    if (fold.isNone) {
      return unfolded ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              stage,
              Expanded(child: body),
            ],
          );
    }
    final window = MediaQuery.of(context);
    final panes = fold.panes(
      window.size,
      direction: Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
    return Stack(
      children: [
        AppFoldPane(rect: panes.first, window: window, child: stage),
        AppFoldPane(rect: panes.second, window: window, child: body),
      ],
    );
  }
}

/// One pane of a split window: [child] placed at [rect] with the pane's own
/// `MediaQuery`. A child of a [Stack] that fills the window.
class AppFoldPane extends StatelessWidget {
  const AppFoldPane({
    required this.rect,
    required this.window,
    required this.child,
    super.key,
  });

  /// Where the pane sits, in window coordinates.
  final Rect rect;

  /// The window's own `MediaQuery`.
  final MediaQueryData window;

  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned.fromRect(
    rect: rect,
    child: MediaQuery(
      data: foldPaneMediaQuery(window, rect),
      child: child,
    ),
  );
}

import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureType;

import 'package:critalarm/core/device/fold_division_switches.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:foldable_ext/foldable_ext.dart';

/// [features] with every fold in [published] made to run the whole window
/// of [window].
///
/// [features] is what `MediaQuery` holds under the fold package's scope, and
/// [published] is the part of it the package put there: the iPhone Duo
/// division, or the division an Android foldable stands in for.
///
/// - Nothing published leaves [features] as they are, the same list. That is
///   every Android device with the division switch off: the engine's own
///   list goes through untouched.
/// - A published fold runs across the window along its long side. A division
///   taller than it is wide becomes a top to bottom band through the window,
///   and a wider one a left to right band, so `AppFold` reads it as book or
///   tabletop even when UIKit leaves a few points off its ends.
/// - A fold or hinge in [features] that the package did not publish wins:
///   the engine reported it itself, so the published one is dropped and
///   nothing is there twice.
/// - Cutouts, and every feature that is not a fold, stay as they are.
List<DisplayFeature> foldFeaturesAcrossWindow(
  List<DisplayFeature> features,
  List<DisplayFeature> published,
  Size window,
) {
  if (published.isEmpty) return features;
  bool isPublishedFold(DisplayFeature feature) =>
      feature.type == DisplayFeatureType.fold && published.contains(feature);
  final engineHasFold = features.any(
    (f) =>
        (f.type == DisplayFeatureType.fold ||
            f.type == DisplayFeatureType.hinge) &&
        !published.contains(f),
  );
  var changed = false;
  final out = <DisplayFeature>[];
  for (final feature in features) {
    if (!isPublishedFold(feature)) {
      out.add(feature);
      continue;
    }
    if (engineHasFold) {
      changed = true;
      continue;
    }
    final b = feature.bounds;
    final bounds = b.height >= b.width
        ? Rect.fromLTRB(b.left, 0, b.right, window.height)
        : Rect.fromLTRB(0, b.top, window.width, b.bottom);
    if (bounds == b) {
      out.add(feature);
      continue;
    }
    changed = true;
    out.add(
      DisplayFeature(
        bounds: bounds,
        type: DisplayFeatureType.fold,
        state: feature.state,
      ),
    );
  }
  return changed ? out : features;
}

/// Whether layout follows the iPhone rules: on an iPhone, and on a device
/// that is rendered as one ([isRenderedAsIphone], see
/// [AppFoldScope.isRenderedAsIphoneOf]).
///
/// Layout only. What the platform can do (alarms, notifications, purchases)
/// is still asked of `PlatformCapabilities`, which answers for the real
/// device.
bool layoutIsIphone({
  required bool isIphone,
  required bool isRenderedAsIphone,
}) => isIphone || isRenderedAsIphone;

/// What `MediaQueryData.fromView` answers for the window the app is drawn
/// in: [view] as it is, or the window of the device in [emulation] while
/// the app is rendered as one.
///
/// - No emulation: [view], the same instance.
/// - The window size is matched: the size and the safe area of the emulated
///   window, a pixel ratio multiplied by its scale, no keyboard inset, no
///   system gesture insets and no display features. An iPhone reports no
///   display features through its view either.
/// - The window size is kept: [view] with the safe area of the emulation.
///
/// The text size, the brightness and every other setting are those of
/// [view].
MediaQueryData appWindowMediaFor(
  MediaQueryData view,
  DeviceEmulation? emulation,
) {
  if (emulation == null) return view;
  final safeArea = emulation.safeArea;
  if (!emulation.matchesWindowSize) {
    final keyboard = view.viewInsets;
    return view.copyWith(
      viewPadding: safeArea,
      padding: EdgeInsets.fromLTRB(
        math.max(0, safeArea.left - keyboard.left),
        math.max(0, safeArea.top - keyboard.top),
        math.max(0, safeArea.right - keyboard.right),
        math.max(0, safeArea.bottom - keyboard.bottom),
      ),
    );
  }
  return view.copyWith(
    size: emulation.windowSize,
    devicePixelRatio: view.devicePixelRatio * emulation.scale,
    padding: safeArea,
    viewPadding: safeArea,
    viewInsets: EdgeInsets.zero,
    systemGestureInsets: EdgeInsets.zero,
    displayFeatures: const <DisplayFeature>[],
  );
}

/// The window the app is drawn in, for code that has to step outside the
/// `MediaQuery` it is under: a pane's `MediaQuery` has lost the side insets
/// and the status bar the window has.
///
/// Ask this in place of `MediaQueryData.fromView(View.of(context))`. The
/// view is the real screen, which is another size with another safe area
/// while the app is rendered as an iPhone Duo.
MediaQueryData appWindowMediaOf(BuildContext context) => appWindowMediaFor(
  MediaQueryData.fromView(View.of(context)),
  FoldDivision.emulationOf(context),
);

/// The bounds of the render box of [context] in the coordinates of the
/// window `MediaQuery` describes, or null before the box is laid out.
///
/// Use it for a rect that is drawn or compared in window coordinates: an
/// overlay over the app, a route that grows out of a card.
/// `RenderBox.localToGlobal` answers for the real screen, which is not the
/// window while the app is rendered as an iPhone Duo. Everywhere else the
/// two agree.
///
/// Call it after layout, from a post-frame callback or an event handler.
Rect? appWindowRectOf(BuildContext context) =>
    FoldDivision.windowRectOf(context);

/// How much of the fold goes into `MediaQuery.displayFeatures`: the division
/// and the cutouts, because `AppFold` reads the fold from there.
const DisplayFeatureBridgeMode appFoldBridgeMode =
    DisplayFeatureBridgeMode.full;

/// Puts the fold of a folding phone into the `MediaQuery` under it, so
/// `AppFold` and every book and tabletop layout run on a folding iPhone the
/// way they do on an Android foldable.
///
/// The fold comes from the `foldable_ext` package on both platforms:
///
/// - iOS: Flutter reports no display features there. The package reads the
///   iPhone Duo division and publishes it as a half opened fold while the
///   hinge is partly open. Flat or closed, there is no fold.
/// - Android: the engine fills `MediaQuery.displayFeatures` itself and the
///   list goes through untouched. With the developer switch on
///   ([switches]), a foldable renders the app as an iPhone Duo instead: the
///   subtree is laid out in the iPhone Duo window, scaled to fit the screen,
///   and `MediaQuery` under the scope describes that window, its safe area
///   and its division. [isRenderedAsIphoneOf] says so.
/// - Everywhere else there is no fold.
///
/// While the app is rendered as an iPhone Duo, `RenderBox.localToGlobal`
/// and the view still answer for the real screen. [appWindowRectOf] and
/// [appWindowMediaOf] answer for the window.
///
/// Place it once, inside the `MaterialApp` builder, above the router. Every
/// widget it adds is there fold or not, so the tree keeps its shape (and its
/// state) when the phone folds and when a switch changes.
class AppFoldScope extends StatelessWidget {
  const AppFoldScope({required this.child, this.switches, super.key});

  /// The developer switches of the division, or null in a build or on a
  /// platform that has none. With none the overlay is never drawn.
  final DevFoldDivisionSwitches? switches;

  final Widget child;

  /// Whether the subtree of [context] is rendered as an iPhone Duo on a
  /// device that is not one. The caller rebuilds when that changes.
  static bool isRenderedAsIphoneOf(BuildContext context) =>
      FoldDivision.emulatedDeviceOf(context) != null;

  @override
  Widget build(BuildContext context) {
    final inner = _FoldAcrossWindow(child: child);
    final switches = this.switches;
    if (switches == null) {
      return FoldDivisionScope(
        bridgeMode: appFoldBridgeMode,
        showOverlay: false,
        child: inner,
      );
    }
    return ListenableBuilder(
      listenable: switches,
      builder: (context, child) => FoldDivisionScope(
        bridgeMode: appFoldBridgeMode,
        showOverlay: switches.showsOverlay,
        child: child!,
      ),
      child: inner,
    );
  }
}

/// Applies [foldFeaturesAcrossWindow] to the `MediaQuery` above it.
///
/// Always wraps [child] in a `MediaQuery`, fold or not.
class _FoldAcrossWindow extends StatefulWidget {
  const _FoldAcrossWindow({required this.child});

  final Widget child;

  @override
  State<_FoldAcrossWindow> createState() => _FoldAcrossWindowState();
}

class _FoldAcrossWindowState extends State<_FoldAcrossWindow> {
  List<DisplayFeature> _features = const [];

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Only this aspect, so the hinge angle sweeping does not rebuild it.
    final published =
        InheritedModel.inheritFrom<DuoMediaQuery>(
          context,
          aspect: FoldableAspect.displayFeatures,
        )?.data.displayFeatures ??
        const <DisplayFeature>[];
    final features = foldFeaturesAcrossWindow(
      media.displayFeatures,
      published,
      media.size,
    );
    if (identical(features, media.displayFeatures)) {
      return MediaQuery(data: media, child: widget.child);
    }
    // MediaQuery compares this list by identity. Keep the old instance
    // while the contents are the same.
    if (!listEquals(features, _features)) _features = features;
    return MediaQuery(
      data: media.copyWith(displayFeatures: _features),
      child: widget.child,
    );
  }
}

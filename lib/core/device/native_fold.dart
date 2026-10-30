import 'dart:async';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The fold of a folding iPhone (iPhone Duo) as the native side reads it.
///
/// Flutter reports no display features on iOS, so `MediaQuery` never holds
/// the fold there. `ios/Runner/DisplayFoldChannel.swift` reads the Flutter
/// view's `.division` reserved region (iOS 27.1) and sends it here. Older iOS
/// and every iPhone that does not fold send none.
@immutable
final class NativeFold {
  const NativeFold({
    required this.bounds,
    required this.isActive,
    this.margins = EdgeInsets.zero,
  });

  /// The reserved rect without its margins, in the Flutter view's logical
  /// pixels.
  final Rect bounds;

  /// The room UIKit asks interactive content to keep from [bounds].
  final EdgeInsets margins;

  /// Whether the division is in force right now. An inactive one is no fold.
  final bool isActive;

  /// The fold in what the native side sends: a map of numbers and a bool,
  /// or null for no fold. Anything else is no fold.
  static NativeFold? fromEvent(Object? event) {
    if (event is! Map) return null;
    double? number(String key) {
      final value = event[key];
      return value is num && value.isFinite ? value.toDouble() : null;
    }

    final left = number('left');
    final top = number('top');
    final width = number('width');
    final height = number('height');
    final active = event['active'];
    if (left == null ||
        top == null ||
        width == null ||
        height == null ||
        width < 0 ||
        height < 0 ||
        active is! bool) {
      return null;
    }
    return NativeFold(
      bounds: Rect.fromLTWH(left, top, width, height),
      margins: EdgeInsets.fromLTRB(
        number('marginLeft') ?? 0,
        number('marginTop') ?? 0,
        number('marginRight') ?? 0,
        number('marginBottom') ?? 0,
      ),
      isActive: active,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NativeFold &&
      other.bounds == bounds &&
      other.margins == margins &&
      other.isActive == isActive;

  @override
  int get hashCode => Object.hash(bounds, margins, isActive);

  @override
  String toString() =>
      'NativeFold($bounds, margins $margins, active $isActive)';
}

/// [features] with [fold] added as a half-opened fold, for a window of
/// [window].
///
/// - No fold, or an inactive one, leaves [features] as they are.
/// - A fold or hinge already in [features] wins: the engine reported it
///   itself, so nothing is added twice.
/// - The fold runs across the window along its long side. A division taller
///   than it is wide becomes a top to bottom line through the window, and a
///   wider one a left to right line, so `AppFold` reads it as book or
///   tabletop even when UIKit leaves a few points off its ends.
List<DisplayFeature> displayFeaturesWithFold(
  List<DisplayFeature> features,
  NativeFold? fold,
  Size window,
) {
  if (fold == null || !fold.isActive) return features;
  final hasFold = features.any(
    (f) =>
        f.type == DisplayFeatureType.fold || f.type == DisplayFeatureType.hinge,
  );
  if (hasFold) return features;
  final b = fold.bounds;
  final Rect bounds;
  if (b.height >= b.width) {
    bounds = Rect.fromLTRB(b.left, 0, b.right, window.height);
  } else {
    bounds = Rect.fromLTRB(0, b.top, window.width, b.bottom);
  }
  return [
    ...features,
    DisplayFeature(
      bounds: bounds,
      type: DisplayFeatureType.fold,
      state: DisplayFeatureState.postureHalfOpened,
    ),
  ];
}

/// Where the fold comes from. An interface so a test hands in its own.
// One member: a stream is the whole job.
// ignore: one_member_abstracts
abstract interface class NativeFoldSource {
  /// The fold now, then again each time it changes. Null is no fold.
  Stream<NativeFold?> folds();
}

/// The fold from `ios/Runner/DisplayFoldChannel.swift`.
///
/// `app.critalarm/display/fold` sends the fold on listen and on every change.
/// A platform with no native side for it (Android, web, a test) gives an
/// empty stream: Android already fills `MediaQuery.displayFeatures` itself.
final class NativeFoldChannel implements NativeFoldSource {
  const NativeFoldChannel({EventChannel? events})
    : _events = events ?? const EventChannel(eventsName);

  static const String methodsName = 'app.critalarm/display';
  static const String eventsName = 'app.critalarm/display/fold';

  final EventChannel _events;

  @override
  Stream<NativeFold?> folds() => _events
      .receiveBroadcastStream()
      .map(NativeFold.fromEvent)
      .handleError((Object _) {}, test: (e) => e is MissingPluginException);
}

/// Adds the native fold to the `MediaQuery` under it, so `AppFold` and every
/// book and tabletop layout run on a folding iPhone the way they do on an
/// Android foldable.
///
/// Place it once, inside the `MaterialApp` builder, above the router. With
/// no [source] it adds nothing and builds [child] as it is. With one it
/// always wraps [child] in a `MediaQuery`, fold or not, so the tree keeps its
/// shape (and its state) when the phone folds.
class NativeFoldScope extends StatefulWidget {
  const NativeFoldScope({required this.child, this.source, super.key});

  final NativeFoldSource? source;
  final Widget child;

  @override
  State<NativeFoldScope> createState() => _NativeFoldScopeState();
}

class _NativeFoldScopeState extends State<NativeFoldScope> {
  StreamSubscription<NativeFold?>? _subscription;
  NativeFold? _fold;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(NativeFoldScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      unawaited(_subscription?.cancel());
      _fold = null;
      _listen();
    }
  }

  void _listen() {
    _subscription = widget.source?.folds().listen((fold) {
      if (!mounted || fold == _fold) return;
      setState(() => _fold = fold);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.source == null) return widget.child;
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        displayFeatures: displayFeaturesWithFold(
          media.displayFeatures,
          _fold,
          media.size,
        ),
      ),
      child: widget.child,
    );
  }
}

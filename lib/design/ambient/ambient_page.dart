import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/design/motion.dart';
import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const double _kBackGestureWidth = 20;
const double _kMinFlingVelocity = 1;
const Duration _kDroppedSwipePageAnimationDuration = Duration(
  milliseconds: 300,
);

/// Builds synchronized slide and fade transitions for routes over an ambient
/// canvas.
Widget buildAmbientTransitions({
  required BuildContext context,
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
  bool isPopGestureInProgress = false,
}) {
  if (context.reduceMotion) {
    return child;
  }

  final primaryCurve = isPopGestureInProgress
      ? Curves.linear
      : AppCurves.easeOut;
  final primaryFadeCurve = isPopGestureInProgress
      ? Curves.linear
      : Curves.easeOut;
  final secondaryCurve = isPopGestureInProgress
      ? Curves.linear
      : AppCurves.easeOut;
  final secondaryFadeCurve = isPopGestureInProgress
      ? Curves.linear
      : Curves.easeOut;

  final primarySlide = animation.drive(
    Tween<Offset>(
      begin: isPopGestureInProgress
          ? const Offset(1, 0)
          : const Offset(0.12, 0),
      end: Offset.zero,
    ).chain(CurveTween(curve: primaryCurve)),
  );
  final primaryFade = animation.drive(
    Tween<double>(
      begin: isPopGestureInProgress ? 1.0 : 0.0,
      end: 1,
    ).chain(CurveTween(curve: primaryFadeCurve)),
  );

  final secondarySlide = secondaryAnimation.drive(
    Tween<Offset>(
      begin: Offset.zero,
      end: isPopGestureInProgress
          ? const Offset(-0.25, 0)
          : const Offset(-0.08, 0),
    ).chain(CurveTween(curve: secondaryCurve)),
  );
  final secondaryFade = secondaryAnimation.drive(
    Tween<double>(
      begin: 1,
      end: 0,
    ).chain(CurveTween(curve: secondaryFadeCurve)),
  );

  return SlideTransition(
    position: secondarySlide,
    child: FadeTransition(
      opacity: secondaryFade,
      child: SlideTransition(
        position: primarySlide,
        child: FadeTransition(
          opacity: primaryFade,
          child: child,
        ),
      ),
    ),
  );
}

/// A mixin on [PageRoute] providing iOS-style interactive edge-swipe pop
/// gesture support while preserving the ambient transition styling.
mixin AmbientRoutePopGestureMixin<T> on PageRoute<T> {
  /// Starts tracking an edge-swipe gesture to pop this route.
  AmbientBackGestureController<T> startPopGesture() {
    assert(popGestureEnabled, 'Route pop gesture was started when disabled');
    return AmbientBackGestureController<T>(
      navigator: navigator!,
      getIsCurrent: () => isCurrent,
      getIsActive: () => isActive,
      controller: controller!,
    );
  }

  /// Builds route transitions with an iOS edge-swipe gesture detector when
  /// running on iOS.
  Widget buildAmbientRouteTransitions({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final canSwipeBack = isIos && !fullscreenDialog;

    final pageChild = canSwipeBack
        ? _AmbientBackGestureDetector<T>(
            enabledCallback: () => popGestureEnabled,
            onStartPopGesture: startPopGesture,
            child: child,
          )
        : child;

    return buildAmbientTransitions(
      context: context,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: pageChild,
      isPopGestureInProgress: popGestureInProgress,
    );
  }
}

/// [full], or [Duration.zero] when the OS asks to reduce motion.
///
/// [buildAmbientTransitions] already skips the slide under reduce motion, but
/// the route still ran for [full], which kept Hero flights moving. A zero
/// duration cuts both. Reads MediaQuery without depending on it, since a
/// route's durations are read outside build.
Duration _motionFor(NavigatorState? navigator, Duration full) {
  final query = navigator?.context.getInheritedWidgetOfExactType<MediaQuery>();
  return (query?.data.disableAnimations ?? false) ? Duration.zero : full;
}

/// A transparent, flicker-free [CustomTransitionPage] designed for [GoRoute],
/// equipped with iOS back-swipe navigation.
class AmbientPage<T> extends CustomTransitionPage<T> {
  AmbientPage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
    super.fullscreenDialog,
    super.opaque = false,
    super.transitionDuration = AppDurations.slow,
    super.reverseTransitionDuration = AppDurations.slow,
  }) : super(
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           return buildAmbientTransitions(
             context: context,
             animation: animation,
             secondaryAnimation: secondaryAnimation,
             child: child,
           );
         },
       );

  @override
  Route<T> createRoute(BuildContext context) =>
      _AmbientPageRoute<T>(page: this);
}

class _AmbientPageRoute<T> extends PageRoute<T>
    with AmbientRoutePopGestureMixin<T> {
  _AmbientPageRoute({required this.page}) : super(settings: page);

  final AmbientPage<T> page;

  @override
  Duration get transitionDuration =>
      _motionFor(navigator, page.transitionDuration);

  @override
  Duration get reverseTransitionDuration =>
      _motionFor(navigator, page.reverseTransitionDuration);

  @override
  bool get opaque => page.opaque;

  @override
  bool get barrierDismissible => page.barrierDismissible;

  @override
  Color? get barrierColor => page.barrierColor;

  @override
  String? get barrierLabel => page.barrierLabel;

  @override
  bool get maintainState => page.maintainState;

  @override
  bool get fullscreenDialog => page.fullscreenDialog;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: page.child,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return buildAmbientRouteTransitions(
      context: context,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// A transparent [PageRoute] for standard [Navigator] pushes, equipped with
/// iOS back-swipe navigation.
class AmbientPageRoute<T> extends PageRoute<T>
    with AmbientRoutePopGestureMixin<T> {
  AmbientPageRoute({
    required this.builder,
    super.settings,
    super.fullscreenDialog,
  });

  final WidgetBuilder builder;

  @override
  Duration get transitionDuration => _motionFor(navigator, AppDurations.slow);

  @override
  Duration get reverseTransitionDuration =>
      _motionFor(navigator, AppDurations.slow);

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return buildAmbientRouteTransitions(
      context: context,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// Drives route controller animation during an iOS edge swipe drag.
class AmbientBackGestureController<T> {
  AmbientBackGestureController({
    required this.navigator,
    required this.controller,
    required this.getIsActive,
    required this.getIsCurrent,
  }) {
    navigator.didStartUserGesture();
  }

  final AnimationController controller;
  final NavigatorState navigator;
  final ValueGetter<bool> getIsActive;
  final ValueGetter<bool> getIsCurrent;

  /// Updates animation progress based on gesture delta.
  void dragUpdate(double delta) {
    controller.value -= delta;
  }

  /// Ends the gesture and flings the route forward to dismiss or back to keep.
  void dragEnd(double velocity) {
    const animationCurve = Curves.fastEaseInToSlowEaseOut;
    final isCurrent = getIsCurrent();
    final bool animateForward;

    if (!isCurrent) {
      animateForward = getIsActive();
    } else if (velocity.abs() >= _kMinFlingVelocity) {
      animateForward = velocity <= 0;
    } else {
      animateForward = controller.value > 0.5;
    }

    if (animateForward) {
      unawaited(
        controller.animateTo(
          1,
          duration: _kDroppedSwipePageAnimationDuration,
          curve: animationCurve,
        ),
      );
    } else {
      if (isCurrent) {
        navigator.pop();
      }

      if (controller.isAnimating) {
        unawaited(
          controller.animateBack(
            0,
            duration: _kDroppedSwipePageAnimationDuration,
            curve: animationCurve,
          ),
        );
      }
    }

    if (controller.isAnimating) {
      late final AnimationStatusListener animationStatusCallback;
      animationStatusCallback = (status) {
        navigator.didStopUserGesture();
        controller.removeStatusListener(animationStatusCallback);
      };
      controller.addStatusListener(animationStatusCallback);
    } else {
      navigator.didStopUserGesture();
    }
  }
}

/// A gesture detector detecting iOS back-swipe drags from the start edge.
class _AmbientBackGestureDetector<T> extends StatefulWidget {
  const _AmbientBackGestureDetector({
    required this.enabledCallback,
    required this.onStartPopGesture,
    required this.child,
    super.key,
  });

  final Widget child;
  final ValueGetter<bool> enabledCallback;
  final ValueGetter<AmbientBackGestureController<T>> onStartPopGesture;

  @override
  State<_AmbientBackGestureDetector<T>> createState() =>
      _AmbientBackGestureDetectorState<T>();
}

class _AmbientBackGestureDetectorState<T>
    extends State<_AmbientBackGestureDetector<T>> {
  AmbientBackGestureController<T>? _backGestureController;
  late HorizontalDragGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = HorizontalDragGestureRecognizer(debugOwner: this)
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd
      ..onCancel = _handleDragCancel;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    if (_backGestureController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_backGestureController?.navigator.mounted ?? false) {
          _backGestureController?.navigator.didStopUserGesture();
        }
        _backGestureController = null;
      });
    }
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    assert(mounted, 'Gesture detector must be mounted when drag starts');
    assert(
      _backGestureController == null,
      'Drag controller must be null at drag start',
    );
    _backGestureController = widget.onStartPopGesture();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    assert(mounted, 'Gesture detector must be mounted when drag updates');
    assert(
      _backGestureController != null,
      'Drag controller must exist during drag update',
    );
    final width = context.size?.width ?? 1.0;
    _backGestureController!.dragUpdate(
      _convertToLogical((details.primaryDelta ?? 0.0) / width),
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    assert(mounted, 'Gesture detector must be mounted when drag ends');
    assert(
      _backGestureController != null,
      'Drag controller must exist when drag ends',
    );
    final width = context.size?.width ?? 1.0;
    _backGestureController!.dragEnd(
      _convertToLogical(details.velocity.pixelsPerSecond.dx / width),
    );
    _backGestureController = null;
  }

  void _handleDragCancel() {
    assert(mounted, 'Gesture detector must be mounted when drag cancels');
    _backGestureController?.dragEnd(0);
    _backGestureController = null;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.enabledCallback()) {
      _recognizer.addPointer(event);
    }
  }

  double _convertToLogical(double value) {
    return switch (Directionality.of(context)) {
      TextDirection.rtl => -value,
      TextDirection.ltr => value,
    };
  }

  @override
  Widget build(BuildContext context) {
    assert(
      debugCheckHasDirectionality(context),
      'Context must have text directionality',
    );
    final dragAreaWidth = switch (Directionality.of(context)) {
      TextDirection.rtl => MediaQuery.paddingOf(context).right,
      TextDirection.ltr => MediaQuery.paddingOf(context).left,
    };
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.child,
        PositionedDirectional(
          start: 0,
          width: math.max(dragAreaWidth, _kBackGestureWidth),
          top: 0,
          bottom: 0,
          child: Listener(
            onPointerDown: _handlePointerDown,
            behavior: HitTestBehavior.translucent,
          ),
        ),
      ],
    );
  }
}

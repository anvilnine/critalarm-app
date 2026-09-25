import 'dart:async';

import 'package:critalarm/design/faces/face_shape.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/faces/idle_face.dart';
import 'package:critalarm/design/faces/refresh_face_controller.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:critalarm/design_system/motion.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Hands a screen's refresh controller down to the face on its stage.
class RefreshFaceScope extends InheritedWidget {
  /// Shares [controller] with everything under [child].
  const RefreshFaceScope({
    required this.controller,
    required super.child,
    super.key,
  });

  /// The screen's refresh sequence.
  final RefreshFaceController controller;

  /// The nearest controller, or null when the screen uses the spinner.
  static RefreshFaceController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<RefreshFaceScope>()
      ?.controller;

  @override
  bool updateShouldNotify(RefreshFaceScope oldWidget) =>
      controller != oldWidget.controller;
}

/// The face a stage shows: the refresh face when the screen has one, the
/// plain face otherwise.
///
/// Pass true for [idleWhenCalm] on a screen where a calm face has nothing to
/// say, and it plays the small idle expressions instead of standing still.
/// It stops the moment the refresh takes the face over.
Widget stageFace(
  BuildContext context, {
  required FaceState state,
  required double size,
  required bool isLive,
  bool idleWhenCalm = false,
}) {
  final controller = RefreshFaceScope.maybeOf(context);
  if (controller == null) {
    if (idleWhenCalm && state == FaceState.calm) {
      return IdleFace(size: size);
    }
    return FaceWidget(state: state, size: size, isLive: isLive);
  }
  return RefreshFace(
    controller: controller,
    state: state,
    size: size,
    isLive: isLive,
    idleWhenCalm: idleWhenCalm,
  );
}

/// Owns the refresh controller for one screen, feeds it how far the list is
/// pulled past its top, and buzzes the phone at the moments that matter.
///
/// Wrap the list and anything that shows the refresh, such as the top bar.
/// Needs bouncing scroll physics, which `AppScreenScaffold` uses by default:
/// the pull is read from the list going past its top edge.
class RefreshFaceHost extends StatefulWidget {
  /// Watches the scroll view inside [child] and refreshes with [onRefresh].
  const RefreshFaceHost({
    required this.onRefresh,
    required this.child,
    super.key,
  });

  /// The refresh. True when it worked.
  final Future<bool> Function() onRefresh;

  /// Holds the scroll view.
  final Widget child;

  @override
  State<RefreshFaceHost> createState() => _RefreshFaceHostState();
}

class _RefreshFaceHostState extends State<RefreshFaceHost> {
  late final RefreshFaceController _controller = RefreshFaceController(
    onRefresh: widget.onRefresh,
  );

  /// True while a finger is on the list. The drag ending is the release.
  bool _dragging = false;

  bool _wasArmed = false;
  RefreshFacePhase _lastPhase = RefreshFacePhase.idle;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_buzz);
  }

  /// A tick when letting go would refresh, a thud when the refresh ends.
  void _buzz() {
    final armed = _controller.isArmed;
    if (armed && !_wasArmed) AppHaptics.selection();
    _wasArmed = armed;

    final phase = _controller.phase;
    if (phase == _lastPhase) return;
    _lastPhase = phase;
    if (phase == RefreshFacePhase.success) AppHaptics.done();
    if (phase == RefreshFacePhase.failed) AppHaptics.failed();
  }

  @override
  void didUpdateWidget(covariant RefreshFaceHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.onRefresh = widget.onRefresh;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final distance = n.metrics.minScrollExtent - n.metrics.pixels;

    if (n is ScrollUpdateNotification) {
      if (n.dragDetails != null) {
        _dragging = true;
        _controller.pull(distance);
      } else {
        // With bouncing physics the drag hands straight over to the spring
        // back, so the first update without a finger is the release.
        _release();
        if (_controller.phase == RefreshFacePhase.pulling) {
          _controller.pull(distance);
        }
      }
    } else if (n is ScrollEndNotification) {
      _release();
    }
    return false;
  }

  void _release() {
    if (!_dragging) return;
    _dragging = false;
    unawaited(_controller.release());
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: RefreshFaceScope(controller: _controller, child: widget.child),
    );
  }
}

/// A small spinner for the top bar that shows while the refresh is running.
/// Shows nothing on a screen without a refresh face.
class RefreshActivityIndicator extends StatelessWidget {
  /// Reads the controller from the nearest [RefreshFaceScope].
  const RefreshActivityIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = RefreshFaceScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final color = context.appColors.onCanvas;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final on = controller.phase == RefreshFacePhase.working;
        return AnimatedOpacity(
          opacity: on ? 1 : 0,
          duration: context.motion(AppDurations.quick),
          child: AnimatedScale(
            scale: on ? 1 : 0.6,
            duration: context.motion(AppDurations.quick),
            curve: Curves.easeOutBack,
            child: SizedBox.square(
              dimension: 18,
              // Standing still while hidden, so it does not keep a ticker
              // running for nothing.
              child: CircularProgressIndicator(
                semanticsLabel: on ? LocaleKeys.common_loading.tr() : null,
                value: on ? null : 0.75,
                strokeWidth: 2.5,
                strokeCap: StrokeCap.round,
                color: color,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A face that acts out the refresh held by [controller], and shows [state]
/// the rest of the time.
class RefreshFace extends StatefulWidget {
  /// Follows [controller]; [state], [size] and [isLive] are the face the
  /// screen would show without a refresh.
  const RefreshFace({
    required this.controller,
    required this.state,
    required this.size,
    this.isLive = false,
    this.idleWhenCalm = false,
    super.key,
  });

  /// The screen's refresh sequence.
  final RefreshFaceController controller;

  /// The face the screen shows when nothing is refreshing.
  final FaceState state;

  /// Width and height.
  final double size;

  /// Passed through to the plain face.
  final bool isLive;

  /// True lets a calm face play the small idle expressions between refreshes.
  final bool idleWhenCalm;

  @override
  State<RefreshFace> createState() => _RefreshFaceState();
}

class _RefreshFaceState extends State<RefreshFace>
    with TickerProviderStateMixin {
  late final AnimationController _morph = AnimationController(vsync: this);

  late RefreshFacePhase _phase = widget.controller.phase;
  RefreshFacePhase _previous = RefreshFacePhase.idle;

  /// Drives the side to side rock while a finger is pulling the list. It is
  /// its own ticker rather than a repeating controller because the speed
  /// changes with the pull, and restarting a controller to change its
  /// duration would jump the head back to centre every time.
  Ticker? _wobble;
  double _turns = 0;
  Duration _lastTick = Duration.zero;

  static final FaceShape _calm = faceFor(FaceState.calm);
  static final FaceShape _working = faceFor(FaceState.working);
  static final FaceShape _success = faceFor(FaceState.success);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(covariant RefreshFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _wobble?.dispose();
    _morph.dispose();
    super.dispose();
  }

  void _onChange() {
    final phase = widget.controller.phase;
    if (phase != _phase) {
      _previous = _phase;
      _phase = phase;

      final morph = switch (phase) {
        RefreshFacePhase.success => AppDurations.medium,
        RefreshFacePhase.failed => AppDurations.enter,
        RefreshFacePhase.settling => AppDurations.base,
        _ => null,
      };
      if (morph != null) {
        _morph.duration = morph;
        unawaited(_morph.forward(from: 0));
      }

      // The rock carries on through the refresh at the speed the apex
      // earned, so letting go does not drop the head into a slower shake.
      _setWobble(
        on:
            phase == RefreshFacePhase.pulling ||
            phase == RefreshFacePhase.working,
      );
    }
    // Progress moves without the phase changing, so always rebuild.
    setState(() {});
  }

  /// Runs the rock only while the list is being pulled, and only on a phone
  /// that allows animations.
  void _setWobble({required bool on}) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (on && !reduceMotion) {
      if (_wobble != null) return;
      _turns = 0;
      _lastTick = Duration.zero;
      final ticker = _wobble = createTicker(_onTick);
      unawaited(ticker.start());
      return;
    }
    _wobble?.dispose();
    _wobble = null;
    _turns = 0;
  }

  /// Moves the rock on by however long the frame took, at the speed the pull
  /// has earned.
  void _onTick(Duration elapsed) {
    final seconds = (elapsed - _lastTick).inMicroseconds / 1000000;
    _lastTick = elapsed;
    _turns += seconds * pullWobbleHz(widget.controller.progress);
    setState(() {});
  }

  /// The face between refreshes. A calm one on a screen that asked for idle
  /// expressions plays them, and stops as soon as a pull starts.
  Widget _plain(FaceState state, {bool live = false}) {
    if (widget.idleWhenCalm && state == FaceState.calm) {
      return IdleFace(
        size: widget.size,
        isEnabled: _phase == RefreshFacePhase.idle,
      );
    }
    return FaceWidget(state: state, size: widget.size, isLive: live);
  }

  Widget _shaped(FaceShape shape) =>
      FaceWidget(state: FaceState.calm, shape: shape, size: widget.size);

  Widget _fade(Widget from, Widget to, double t) => Stack(
    alignment: Alignment.center,
    children: [
      Opacity(opacity: 1 - t, child: from),
      Opacity(opacity: t, child: to),
    ],
  );

  Widget _face({required bool reduceMotion}) {
    final t = reduceMotion ? 1.0 : Curves.easeOutCubic.transform(_morph.value);
    final baseIsCalm = widget.state == FaceState.calm;

    switch (_phase) {
      case RefreshFacePhase.idle:
        return _plain(widget.state, live: widget.isLive);

      case RefreshFacePhase.pulling:
        final p = widget.controller.progress;
        var pulled = _shaped(FaceShape.lerp(_calm, _working, p));
        // The head rocks side to side as it is dragged down, slow at the top
        // and quick once the pull is far enough to refresh, so letting go at
        // the right moment is something you can see as well as feel.
        if (!reduceMotion) {
          pulled = Transform.rotate(
            angle: pullWobbleAngle(progress: p, turns: _turns),
            alignment: const FractionalOffset(0.5, 0.6),
            child: pulled,
          );
        }
        if (baseIsCalm) return pulled;
        // Not calm, so there is no shape to blend from. Fade across over the
        // first fifth of the pull.
        return _fade(_plain(widget.state), pulled, (p / 0.2).clamp(0.0, 1.0));

      case RefreshFacePhase.working:
        final shaped = _shaped(_working);
        if (reduceMotion) return shaped;
        return Transform.rotate(
          angle: pullWobbleAngle(progress: 1, turns: _turns),
          alignment: const FractionalOffset(0.5, 0.6),
          child: shaped,
        );

      case RefreshFacePhase.success:
        return _shaped(FaceShape.lerp(_working, _success, t));

      case RefreshFacePhase.failed:
        return _fade(_shaped(_working), _plain(FaceState.worried), t);

      case RefreshFacePhase.settling:
        final fromSuccess = _previous == RefreshFacePhase.success;
        if (fromSuccess && baseIsCalm) {
          return _shaped(FaceShape.lerp(_success, _calm, t));
        }
        return _fade(
          fromSuccess ? _shaped(_success) : _plain(FaceState.worried),
          _plain(widget.state, live: widget.isLive),
          t,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedBuilder(
      animation: _morph,
      builder: (context, _) => _face(reduceMotion: reduceMotion),
    );
  }
}

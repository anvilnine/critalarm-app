import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/design/faces/face_shape.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/faces/refresh_face_controller.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:flutter/material.dart';

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
Widget stageFace(
  BuildContext context, {
  required FaceState state,
  required double size,
  required bool isLive,
}) {
  final controller = RefreshFaceScope.maybeOf(context);
  if (controller == null) {
    return FaceWidget(state: state, size: size, isLive: isLive);
  }
  return RefreshFace(
    controller: controller,
    state: state,
    size: size,
    isLive: isLive,
  );
}

/// Owns the refresh controller for one scroll view and feeds it how far the
/// list is pulled past its top.
///
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

  @override
  State<RefreshFace> createState() => _RefreshFaceState();
}

class _RefreshFaceState extends State<RefreshFace>
    with TickerProviderStateMixin {
  late final AnimationController _morph = AnimationController(vsync: this);
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: AppDurations.shake,
  );

  late RefreshFacePhase _phase = widget.controller.phase;
  RefreshFacePhase _previous = RefreshFacePhase.idle;

  static final FaceShape _calm = FaceShape.of(FaceState.calm)!;
  static final FaceShape _working = FaceShape.of(FaceState.working)!;
  static final FaceShape _success = FaceShape.of(FaceState.success)!;

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
    _morph.dispose();
    _shake.dispose();
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

      if (phase == RefreshFacePhase.working) {
        unawaited(_shake.repeat(reverse: true));
      } else {
        _shake.stop();
      }
    }
    // Progress moves without the phase changing, so always rebuild.
    setState(() {});
  }

  Widget _plain(FaceState state, {bool live = false}) =>
      FaceWidget(state: state, size: widget.size, isLive: live);

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
        final pulled = _shaped(FaceShape.lerp(_calm, _working, p));
        if (baseIsCalm) return pulled;
        // Not calm, so there is no shape to blend from. Fade across over the
        // first fifth of the pull.
        return _fade(_plain(widget.state), pulled, (p / 0.2).clamp(0.0, 1.0));

      case RefreshFacePhase.working:
        final angle = reduceMotion
            ? 0.0
            : (-2 + 4 * _shake.value) * math.pi / 180;
        return Transform.rotate(
          angle: angle,
          alignment: const FractionalOffset(0.5, 0.6),
          child: _shaped(_working),
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
      animation: Listenable.merge([_morph, _shake]),
      builder: (context, _) => _face(reduceMotion: reduceMotion),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;
import 'package:critalarm/design/faces/face_painter.dart';
import 'package:critalarm/design/faces/face_shape.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:flutter/material.dart';

/// Flutter widget that renders the Crit Alarm face character at any size,
/// with support for live animations (alarmed shake, watching look drift).
class FaceWidget extends StatefulWidget {
  const FaceWidget({
    required this.state,
    this.size = 120.0,
    this.isLive = false,
    this.overrideFillColor,
    this.overrideStrokeColor,
    this.overrideInkColor,
    this.overrideTongueColor,
    this.tiltAngle,
    this.shape,
    super.key,
  });

  final FaceState state;
  final double size;
  final bool isLive;
  final Color? overrideFillColor;
  final Color? overrideStrokeColor;
  final Color? overrideInkColor;
  final Color? overrideTongueColor;

  /// Optional tilt angle in radians.
  /// If omitted, uses [FaceStatePresentation.defaultTilt] (-8 deg for
  /// [FaceState.confused], 0 for others).
  final double? tiltAngle;

  /// Draws this shape instead of [state]'s own eyes and mouth, standing
  /// still. The head colours still follow [state].
  final FaceShape? shape;

  @override
  State<FaceWidget> createState() => _FaceWidgetState();
}

class _FaceWidgetState extends State<FaceWidget> with TickerProviderStateMixin {
  AnimationController? _shakeController;
  AnimationController? _lookController;
  AnimationController? _dizzyController;
  AnimationController? _bounceController;
  AnimationController? _tiltSwayController;

  @override
  void initState() {
    super.initState();
    _updateControllers();
  }

  @override
  void didUpdateWidget(covariant FaceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state || oldWidget.isLive != widget.isLive) {
      _updateControllers();
    }
  }

  void _disposeControllers() {
    _shakeController?.dispose();
    _shakeController = null;
    _lookController?.dispose();
    _lookController = null;
    _dizzyController?.dispose();
    _dizzyController = null;
    _bounceController?.dispose();
    _bounceController = null;
    _tiltSwayController?.dispose();
    _tiltSwayController = null;
  }

  void _updateControllers() {
    _disposeControllers();

    if (!widget.isLive) {
      return;
    }

    switch (widget.state) {
      case FaceState.alarmed:
        _shakeController = AnimationController(
          vsync: this,
          duration: AppDurations.shake,
        );
        unawaited(_shakeController!.repeat(reverse: true));

      case FaceState.shocked:
        _shakeController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 80),
        );
        unawaited(_shakeController!.repeat(reverse: true));

      case FaceState.watching:
        _lookController = AnimationController(
          vsync: this,
          duration: AppDurations.look,
        );
        unawaited(_lookController!.repeat());

      case FaceState.dizzy:
        _dizzyController = AnimationController(
          vsync: this,
          duration: const Duration(seconds: 4),
        );
        unawaited(_dizzyController!.repeat());

      case FaceState.laughing:
        _bounceController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 350),
        );
        unawaited(_bounceController!.repeat(reverse: true));

      case FaceState.confused:
        _tiltSwayController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2200),
        );
        unawaited(_tiltSwayController!.repeat(reverse: true));

      case FaceState.calm:
      case FaceState.worried:
      case FaceState.acked:
      case FaceState.working:
      case FaceState.success:
      case FaceState.surprised:
      case FaceState.skeptical:
      case FaceState.determined:
      case FaceState.sad:
        break;
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    // Resolve default colors based on state
    final fill = widget.overrideFillColor ?? colors.faceFill;
    final stroke =
        widget.overrideStrokeColor ??
        switch (widget.state) {
          FaceState.worried => colors.high,
          FaceState.alarmed => colors.crit,
          FaceState.acked => colors.cobalt,
          _ => colors.faceStroke,
        };
    final ink = widget.overrideInkColor ?? colors.faceInk;
    final tongue = widget.overrideTongueColor;

    final baseTilt = widget.tiltAngle ?? widget.state.defaultTilt;

    Widget buildPaintedFace({
      double lookDx = 0.0,
      double spiralRotation = 0.0,
    }) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(
          size: Size(widget.size, widget.size),
          painter: FacePainter(
            state: widget.state,
            fillColor: fill,
            strokeColor: stroke,
            inkColor: ink,
            lookDx: lookDx,
            spiralRotation: spiralRotation,
            tongueColor: tongue,
            shape: widget.shape,
          ),
        ),
      );
    }

    Widget applyTilt(Widget child, double tilt) {
      if (tilt == 0.0) return child;
      return Transform.rotate(
        angle: tilt,
        alignment: FractionalOffset.center,
        child: child,
      );
    }

    if (reduceMotion || !widget.isLive || widget.shape != null) {
      return applyTilt(buildPaintedFace(), baseTilt);
    }

    // Alarmed: shake -3deg to +3deg
    if (widget.state == FaceState.alarmed && _shakeController != null) {
      return AnimatedBuilder(
        animation: _shakeController!,
        builder: (context, child) {
          final progress = _shakeController!.value;
          final angle = baseTilt + (-3.0 + progress * 6.0) * math.pi / 180.0;
          return Transform.rotate(
            angle: angle,
            alignment: const FractionalOffset(0.5, 0.6),
            child: buildPaintedFace(),
          );
        },
      );
    }

    // Shocked: rapid jitter shake
    if (widget.state == FaceState.shocked && _shakeController != null) {
      return AnimatedBuilder(
        animation: _shakeController!,
        builder: (context, child) {
          final progress = _shakeController!.value;
          final angle = baseTilt + (-2.0 + progress * 4.0) * math.pi / 180.0;
          final dy = -1.0 + progress * 2.0;
          return Transform.translate(
            offset: Offset(0, dy),
            child: Transform.rotate(
              angle: angle,
              alignment: FractionalOffset.center,
              child: buildPaintedFace(),
            ),
          );
        },
      );
    }

    // Watching: horizontal pupil drift
    if (widget.state == FaceState.watching && _lookController != null) {
      return AnimatedBuilder(
        animation: _lookController!,
        builder: (context, child) {
          final t = _lookController!.value;
          final double dx;
          if (t < 0.4) {
            dx = 0;
          } else if (t < 0.5) {
            final sub = (t - 0.4) / 0.1;
            dx = -18.0 * Curves.easeInOut.transform(sub);
          } else if (t < 0.9) {
            dx = -18;
          } else {
            final sub = (t - 0.9) / 0.1;
            dx = -18.0 * (1 - Curves.easeInOut.transform(sub));
          }

          return applyTilt(buildPaintedFace(lookDx: dx), baseTilt);
        },
      );
    }

    // Dizzy: continuous eye spiral spin + subtle head sway
    if (widget.state == FaceState.dizzy && _dizzyController != null) {
      return AnimatedBuilder(
        animation: _dizzyController!,
        builder: (context, child) {
          final t = _dizzyController!.value;
          final spiralAngle = t * 2 * math.pi;
          final swayAngle =
              baseTilt + math.sin(t * 4 * math.pi) * (3.0 * math.pi / 180.0);
          return Transform.rotate(
            angle: swayAngle,
            alignment: FractionalOffset.center,
            child: buildPaintedFace(spiralRotation: spiralAngle),
          );
        },
      );
    }

    // Laughing: giggle bounce
    if (widget.state == FaceState.laughing && _bounceController != null) {
      return AnimatedBuilder(
        animation: _bounceController!,
        builder: (context, child) {
          final progress = Curves.easeInOut.transform(_bounceController!.value);
          final dy = -5.0 * progress;
          return Transform.translate(
            offset: Offset(0, dy),
            child: applyTilt(buildPaintedFace(), baseTilt),
          );
        },
      );
    }

    // Confused: subtle thoughtful head cock
    if (widget.state == FaceState.confused && _tiltSwayController != null) {
      return AnimatedBuilder(
        animation: _tiltSwayController!,
        builder: (context, child) {
          final progress = Curves.easeInOut.transform(
            _tiltSwayController!.value,
          );
          // Sway between -6deg and -11deg
          final angle = (-6.0 - progress * 5.0) * math.pi / 180.0;
          return Transform.rotate(
            angle: widget.tiltAngle ?? angle,
            alignment: FractionalOffset.center,
            child: buildPaintedFace(),
          );
        },
      );
    }

    return applyTilt(buildPaintedFace(), baseTilt);
  }
}

/// Standard Hero flight shuttle builder for [FaceWidget] ensuring smooth
/// scaling across size changes during route transitions without clipping.
Widget faceFlightShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final toHero = toHeroContext.widget as Hero;
  return FittedBox(
    child: toHero.child,
  );
}

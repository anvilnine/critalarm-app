import 'dart:async';
import 'dart:math' as math;
import 'package:critalarm/design/faces/face_painter.dart';
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
    super.key,
  });

  final FaceState state;
  final double size;
  final bool isLive;
  final Color? overrideFillColor;
  final Color? overrideStrokeColor;
  final Color? overrideInkColor;

  @override
  State<FaceWidget> createState() => _FaceWidgetState();
}

class _FaceWidgetState extends State<FaceWidget> with TickerProviderStateMixin {
  AnimationController? _shakeController;
  AnimationController? _lookController;

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

  void _updateControllers() {
    if (!widget.isLive) {
      _shakeController?.stop();
      _shakeController?.dispose();
      _shakeController = null;

      _lookController?.stop();
      _lookController?.dispose();
      _lookController = null;
      return;
    }

    if (widget.state == FaceState.alarmed) {
      _lookController?.stop();
      _lookController?.dispose();
      _lookController = null;

      _shakeController ??= AnimationController(
        vsync: this,
        duration: AppDurations.shake,
      );
      unawaited(_shakeController!.repeat(reverse: true));
    } else if (widget.state == FaceState.watching) {
      _shakeController?.stop();
      _shakeController?.dispose();
      _shakeController = null;

      _lookController ??= AnimationController(
        vsync: this,
        duration: AppDurations.look,
      );
      unawaited(_lookController!.repeat());
    } else {
      _shakeController?.stop();
      _shakeController?.dispose();
      _shakeController = null;

      _lookController?.stop();
      _lookController?.dispose();
      _lookController = null;
    }
  }

  @override
  void dispose() {
    _shakeController?.dispose();
    _lookController?.dispose();
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

    if (reduceMotion || !widget.isLive) {
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
          ),
        ),
      );
    }

    if (widget.state == FaceState.alarmed && _shakeController != null) {
      return AnimatedBuilder(
        animation: _shakeController!,
        builder: (context, child) {
          // Shake from -3deg to +3deg (-0.052 to +0.052 rad)
          final progress = _shakeController!.value; // 0 to 1
          final angle = (-3.0 + progress * 6.0) * math.pi / 180.0;

          return Transform.rotate(
            angle: angle,
            alignment: const FractionalOffset(0.5, 0.6),
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                size: Size(widget.size, widget.size),
                painter: FacePainter(
                  state: widget.state,
                  fillColor: fill,
                  strokeColor: stroke,
                  inkColor: ink,
                ),
              ),
            ),
          );
        },
      );
    }

    if (widget.state == FaceState.watching && _lookController != null) {
      return AnimatedBuilder(
        animation: _lookController!,
        builder: (context, child) {
          // CSS look keyframe:
          // 0% to 40%: dx = 0
          // 40% to 50%: transition 0 to -18px
          // 50% to 90%: dx = -18px
          // 90% to 100%: transition -18px to 0
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
                lookDx: dx,
              ),
            ),
          );
        },
      );
    }

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
        ),
      ),
    );
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

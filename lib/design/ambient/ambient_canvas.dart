import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/design/ambient/ambient_profile.dart';
import 'package:critalarm/design/ambient/ambient_transition.dart';
import 'package:critalarm/design/tokens/durations.dart';
import 'package:flutter/material.dart';

/// Renders a persistent, animated ambient canvas with smoothly morphing shapes.
class AmbientCanvas extends StatefulWidget {
  const AmbientCanvas({
    required this.profile,
    required this.variant,
    required this.direction,
    required this.reduceMotion,
    super.key,
  });

  final AmbientProfile profile;
  final AmbientMotionVariant variant;
  final AmbientDirection direction;
  final bool reduceMotion;

  @override
  State<AmbientCanvas> createState() => _AmbientCanvasState();
}

class _AmbientCanvasState extends State<AmbientCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late AmbientProfile _from;
  late AmbientProfile _to;

  @override
  void initState() {
    super.initState();
    _from = widget.profile;
    _to = widget.profile;
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.slow,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(covariant AmbientCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);

    final targetChanged =
        widget.profile != oldWidget.profile ||
        widget.variant != oldWidget.variant ||
        widget.direction != oldWidget.direction;
    if (!targetChanged && widget.reduceMotion == oldWidget.reduceMotion) {
      return;
    }

    if (widget.reduceMotion) {
      _controller
        ..stop()
        ..value = 1;
      _from = widget.profile;
      _to = widget.profile;
      return;
    }

    if (!targetChanged) {
      return;
    }

    final currentProgress = resolveAmbientProgress(
      progress: _controller.value,
      reduceMotion: oldWidget.reduceMotion,
    );
    _from = AmbientProfile.lerp(_from, _to, currentProgress);
    _to = widget.profile;
    unawaited(_controller.forward(from: 0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _AmbientCanvasPainter(
                from: _from,
                to: _to,
                variant: widget.variant,
                direction: widget.direction,
                progress: resolveAmbientProgress(
                  progress: _controller.value,
                  reduceMotion: widget.reduceMotion,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AmbientCanvasPainter extends CustomPainter {
  const _AmbientCanvasPainter({
    required this.from,
    required this.to,
    required this.variant,
    required this.direction,
    required this.progress,
  });

  final AmbientProfile from;
  final AmbientProfile to;
  final AmbientMotionVariant variant;
  final AmbientDirection direction;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final profile = AmbientProfile.lerp(from, to, progress);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = profile.canvas,
    );

    for (var index = 0; index < profile.shapes.length; index++) {
      final shape = profile.shapes[index];
      final pose = resolveAmbientPose(
        shape: shape,
        variant: variant,
        direction: direction,
        progress: progress,
      );
      final center = Offset(
        (pose.anchor.x + 1) * size.width / 2,
        (pose.anchor.y + 1) * size.height / 2,
      );
      final extent = pose.scale * size.shortestSide;
      final paint = Paint()
        ..color = shape.color.withValues(alpha: shape.opacity);

      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(pose.turns * math.pi * 2);
      if (index.isEven) {
        canvas.drawCircle(Offset.zero, extent / 2, paint);
      } else {
        final height = extent * 0.58;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: extent * 1.4,
              height: height,
            ),
            Radius.circular(height / 2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientCanvasPainter oldDelegate) {
    return from != oldDelegate.from ||
        to != oldDelegate.to ||
        variant != oldDelegate.variant ||
        direction != oldDelegate.direction ||
        progress != oldDelegate.progress;
  }
}

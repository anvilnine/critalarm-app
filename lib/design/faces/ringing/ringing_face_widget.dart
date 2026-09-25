import 'dart:async';

import 'package:critalarm/design/faces/ringing/ringing_choreography.dart';
import 'package:critalarm/design/faces/ringing/ringing_face_painter.dart';
import 'package:critalarm/design/faces/ringing/ringing_style.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';

/// The face ringing in one of the [RingingStyle]s, looping.
///
/// [size] is the whole stage, not just the head: the head takes the middle
/// 200/280 of it and the rest is room for sweat, stars and steam. With
/// motion off (by [isLive] or the system setting) it holds still on the
/// style's most telling moment.
class RingingFaceWidget extends StatefulWidget {
  const RingingFaceWidget({
    required this.style,
    this.size = 160,
    this.isLive = true,
    this.speed = 1,
    this.fillColor,
    this.strokeColor,
    this.inkColor,
    this.accentColor,
    super.key,
  });

  /// Which animation.
  final RingingStyle style;

  /// Width and height of the stage.
  final double size;

  /// False holds the face still.
  final bool isLive;

  /// How fast the loop plays, 1 being its normal speed.
  final double speed;

  /// The head. Defaults to the face fill.
  final Color? fillColor;

  /// The head outline. Defaults to the alarm red.
  final Color? strokeColor;

  /// Brows, eyes and mouth. Defaults to the face ink.
  final Color? inkColor;

  /// The flush, the siren and the other red extras. Defaults to the alarm
  /// red.
  final Color? accentColor;

  @override
  State<RingingFaceWidget> createState() => _RingingFaceWidgetState();
}

class _RingingFaceWidgetState extends State<RingingFaceWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: _period,
  );
  bool _reduceMotion = false;

  Duration get _period {
    final ms = widget.style.period.inMilliseconds / widget.speed.clamp(0.1, 4);
    return Duration(milliseconds: ms.round());
  }

  bool get _animating => widget.isLive && !_reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _sync();
  }

  @override
  void didUpdateWidget(covariant RingingFaceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.style != widget.style || oldWidget.speed != widget.speed) {
      _loop.duration = _period;
      if (_loop.isAnimating) unawaited(_loop.repeat());
    }
    _sync();
  }

  void _sync() {
    if (_animating && !_loop.isAnimating) {
      unawaited(_loop.repeat());
    } else if (!_animating && _loop.isAnimating) {
      _loop.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final fill = widget.fillColor ?? colors.faceFill;
    final stroke = widget.strokeColor ?? colors.crit;
    final ink = widget.inkColor ?? colors.faceInk;
    final accent = widget.accentColor ?? colors.crit;

    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _loop,
          builder: (context, _) {
            final t = _animating ? _loop.value : widget.style.stillT;
            return CustomPaint(
              size: Size.square(widget.size),
              painter: RingingFacePainter(
                frame: ringingFrameFor(widget.style, t),
                fillColor: fill,
                strokeColor: stroke,
                inkColor: ink,
                accentColor: accent,
              ),
            );
          },
        ),
      ),
    );
  }
}

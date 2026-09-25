import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/design/faces/ringing/ringing_choreography.dart';
import 'package:critalarm/design/faces/ringing/ringing_face_painter.dart';
import 'package:critalarm/design/faces/ringing/ringing_face_widget.dart';
import 'package:critalarm/design/faces/ringing/ringing_frame.dart';
import 'package:critalarm/design/faces/ringing/ringing_style.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// The face on the ringing screen. It starts on a random [RingingStyle] and
/// every few seconds blends into another random one, for as long as the
/// alarm rings.
///
/// [size] is the whole stage, as with [RingingFaceWidget]: the head takes the
/// middle 200/280 of it. With motion off (by [isLive] or the system setting)
/// it holds one random style still on its most telling moment.
class ShufflingRingingFace extends StatefulWidget {
  const ShufflingRingingFace({
    this.size = 160,
    this.isLive = true,
    super.key,
  });

  /// Width and height of the stage.
  final double size;

  /// False holds the face still.
  final bool isLive;

  @override
  State<ShufflingRingingFace> createState() => _ShufflingRingingFaceState();
}

class _ShufflingRingingFaceState extends State<ShufflingRingingFace>
    with SingleTickerProviderStateMixin {
  /// How long one style shows before the next one starts blending in.
  static const _hold = Duration(seconds: 4);

  /// How long one style takes to turn into the next.
  static const _blend = Duration(milliseconds: 600);

  final _random = math.Random();
  late final Ticker _ticker = createTicker(_onTick);
  late RingingStyle _style =
      RingingStyle.values[_random.nextInt(RingingStyle.values.length)];
  Duration _styleStart = Duration.zero;
  RingingStyle? _next;
  Duration _nextStart = Duration.zero;
  Duration _now = Duration.zero;
  bool _reduceMotion = false;

  bool get _animating => widget.isLive && !_reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _sync();
  }

  @override
  void didUpdateWidget(covariant ShufflingRingingFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (_animating && !_ticker.isActive) {
      // A ticker counts from zero every time it starts.
      _now = Duration.zero;
      _styleStart = Duration.zero;
      _next = null;
      unawaited(_ticker.start());
    } else if (!_animating && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    setState(() {
      _now = elapsed;
      final next = _next;
      if (next == null) {
        if (_now - _styleStart >= _hold) {
          _next = nextRingingStyle(_style, _random);
          _nextStart = _now;
        }
      } else if (_now - _nextStart >= _blend) {
        _style = next;
        _styleStart = _nextStart;
        _next = null;
      }
    });
  }

  /// Where [style] is in its loop, having started at [start].
  RingingFrame _frameAt(RingingStyle style, Duration start) {
    final loops = (_now - start).inMicroseconds / style.period.inMicroseconds;
    return ringingFrameFor(style, loops % 1);
  }

  RingingFrame get _frame {
    if (!_animating) return ringingFrameFor(_style, _style.stillT);
    final current = _frameAt(_style, _styleStart);
    final next = _next;
    if (next == null) return current;
    final progress =
        ((_now - _nextStart).inMicroseconds / _blend.inMicroseconds).clamp(
          0.0,
          1.0,
        );
    return RingingFrame.lerp(
      current,
      _frameAt(next, _nextStart),
      Curves.easeInOut.transform(progress),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: RingingFacePainter(
          frame: _frame,
          fillColor: colors.faceFill,
          strokeColor: colors.crit,
          inkColor: colors.faceInk,
          accentColor: colors.crit,
        ),
      ),
    );
  }
}

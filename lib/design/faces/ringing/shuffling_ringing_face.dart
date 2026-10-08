import 'dart:async';
import 'dart:math' as math;

import 'package:critalarm/design/faces/ringing/ringing_choreography.dart';
import 'package:critalarm/design/faces/ringing/ringing_face_painter.dart';
import 'package:critalarm/design/faces/ringing/ringing_face_widget.dart';
import 'package:critalarm/design/faces/ringing/ringing_frame.dart';
import 'package:critalarm/design/faces/ringing/ringing_style.dart';
import 'package:critalarm/design/tokens/colors.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Whether the ringing faces under it keep the head's fill through a flush
/// and a flash (`ringingFaceColors`). With none above it a face tints its
/// head as it always has.
///
/// An alarm look whose face is always yellow sets this, so no style that
/// is shuffled in turns the head another colour.
class RingingFaceFill extends InheritedWidget {
  const RingingFaceFill({
    required this.keepsFill,
    required super.child,
    super.key,
  });

  final bool keepsFill;

  static bool keepsFillOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<RingingFaceFill>()
          ?.keepsFill ??
      false;

  @override
  bool updateShouldNotify(RingingFaceFill oldWidget) =>
      oldWidget.keepsFill != keepsFill;
}

/// Holds every shuffling face under it on one [style], with no shuffle.
///
/// For a row of small pictures of the alarm screen: with one expression
/// in all of them, what differs from picture to picture is the look and
/// nothing else. With none above it a face shuffles as it always has.
class RingingFacePin extends InheritedWidget {
  const RingingFacePin({
    required this.style,
    required super.child,
    super.key,
  });

  final RingingStyle style;

  static RingingStyle? styleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RingingFacePin>()?.style;

  @override
  bool updateShouldNotify(RingingFacePin oldWidget) => oldWidget.style != style;
}

/// The name of the one [RingingStyle] a capture holds the shuffling face
/// on, from `--dart-define=RINGING_FACE=rage`. Debug builds only: a
/// release build always shuffles.
const String _pinnedStyleName = String.fromEnvironment('RINGING_FACE');

/// The style a capture asked for, or null to pick one at random.
RingingStyle? pinnedRingingStyle({
  String name = _pinnedStyleName,
  bool isDebug = kDebugMode,
}) => isDebug ? RingingStyle.values.asNameMap()[name] : null;

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
      pinnedRingingStyle() ??
      RingingStyle.values[_random.nextInt(RingingStyle.values.length)];
  Duration _styleStart = Duration.zero;
  RingingStyle? _next;
  Duration _nextStart = Duration.zero;
  Duration _now = Duration.zero;
  bool _reduceMotion = false;

  /// The style a [RingingFacePin] above holds this face on, or null.
  RingingStyle? _pin;

  bool get _animating => widget.isLive && !_reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final pin = RingingFacePin.styleOf(context);
    if (pin != _pin) {
      _pin = pin;
      _next = null;
      if (pin != null) {
        _style = pin;
        _styleStart = _now;
      }
    }
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
      // A pinned face keeps its one style.
      if (_pin != null) return;
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
          keepsFill: RingingFaceFill.keepsFillOf(context),
        ),
      ),
    );
  }
}

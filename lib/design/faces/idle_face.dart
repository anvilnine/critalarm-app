import 'dart:async';

import 'package:critalarm/design/faces/face_shape.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/faces/idle_face_controller.dart';
import 'package:flutter/material.dart';

/// A calm face that plays a small expression every few seconds and settles
/// back to calm.
///
/// It runs only while it is on screen, switched on, and the phone allows
/// animations. Nothing keeps ticking once it is hidden or thrown away.
class IdleFace extends StatefulWidget {
  /// A face [size] wide and tall. Pass false to [isEnabled] for a plain calm
  /// face that never moves.
  const IdleFace({required this.size, this.isEnabled = true, super.key});

  /// Width and height.
  final double size;

  /// False keeps the face calm and runs nothing.
  final bool isEnabled;

  @override
  State<IdleFace> createState() => _IdleFaceState();
}

class _IdleFaceState extends State<IdleFace>
    with SingleTickerProviderStateMixin {
  final IdleFaceController _controller = IdleFaceController();
  late final AnimationController _morph = AnimationController(vsync: this);

  static final FaceShape _calm = FaceShape.of(FaceState.calm)!;

  /// The face this beat is blending to and from.
  FaceShape _beat = _calm;
  IdleFacePhase _phase = IdleFacePhase.resting;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant IdleFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isEnabled != widget.isEnabled) _sync();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChange)
      ..dispose();
    _morph.dispose();
    super.dispose();
  }

  /// Runs the loop only while the face is on screen, switched on and allowed
  /// to move. [TickerMode] is off for a screen that is covered or parked, so
  /// it also answers "is this face visible".
  void _sync() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final ticking = TickerMode.valuesOf(context).enabled;
    final on = widget.isEnabled && ticking && !reduceMotion;
    if (on) {
      unawaited(_controller.start());
    } else {
      _controller.stop();
    }
  }

  void _onChange() {
    final phase = _controller.phase;
    if (phase == _phase) return;
    _phase = phase;

    switch (phase) {
      case IdleFacePhase.entering:
        _beat = FaceShape.of(_controller.beat) ?? _calm;
        _morph.duration = IdleFaceController.enterBlend;
        unawaited(_morph.forward(from: 0));

      case IdleFacePhase.leaving:
        _morph.duration = IdleFaceController.leaveBlend;
        unawaited(_morph.forward(from: 0));

      case IdleFacePhase.holding:
        _morph.value = 1;

      // Stopping mid beat lands here, which drops the face back to calm at
      // once. That only happens off screen, so nobody watches it happen.
      case IdleFacePhase.resting:
        _morph.value = 0;
    }
    setState(() {});
  }

  /// Calm is drawn by the painter, so a resting face looks exactly like every
  /// other calm face on the screen. Only a beat goes through the shapes.
  Widget _face() {
    final t = Curves.easeInOut.transform(_morph.value);
    final shape = switch (_phase) {
      IdleFacePhase.resting => null,
      IdleFacePhase.entering => FaceShape.lerp(_calm, _beat, t),
      IdleFacePhase.holding => _beat,
      IdleFacePhase.leaving => FaceShape.lerp(_beat, _calm, t),
    };
    return FaceWidget(
      state: FaceState.calm,
      shape: shape,
      size: widget.size,
    );
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: _morph, builder: (context, _) => _face());
}

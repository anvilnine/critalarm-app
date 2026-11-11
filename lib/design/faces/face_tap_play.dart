import 'dart:async';

import 'package:critalarm/design/faces/face_shape.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/design/faces/face_tap_rules.dart';
import 'package:critalarm/design/faces/face_widget.dart';
import 'package:critalarm/design/faces/refresh_face.dart';
import 'package:critalarm/design/faces/refresh_face_controller.dart';
import 'package:critalarm/design/haptics.dart';
import 'package:flutter/material.dart';

/// Lets a hero face be tapped. Crit plays a short reaction (a boop, a
/// giggle, a startle, a look at the finger, a wink, a heart, dizzy after a
/// run of quick taps) and settles back to the screen's own face.
///
/// Wrap the face [child] drawn at [size] for a face resting at [state]. Give
/// [restShape] when the child draws a pose other than [state]'s own (the
/// hero's attentive calm eyes), so the way back lands on what the child
/// shows.
///
/// - The face is the hit target. A tap never wins against a scroll: the tap
///   recogniser gives up as soon as the finger moves.
/// - One light haptic per reaction. No sound.
/// - Reduce motion, or a face under [kFaceTapMoveMinSize], changes the
///   expression only and nothing moves.
/// - A pull to refresh owns the face. While one is on, taps do nothing.
/// - Decorative for a screen reader, like every other face on a screen.
///
/// The child stays in the tree while a reaction plays, so an idle or refresh
/// face under it keeps its state.
class FaceTapPlay extends StatefulWidget {
  const FaceTapPlay({
    required this.state,
    required this.size,
    required this.child,
    this.restShape,
    this.isEnabled = true,
    super.key,
  });

  /// The face the screen shows. Reactions come back to it.
  final FaceState state;

  /// The face's width and height.
  final double size;

  /// The face itself, drawn while no reaction plays.
  final Widget child;

  /// The pose [child] draws when it is not [state]'s own.
  final FaceShape? restShape;

  /// False passes taps through and never reacts.
  final bool isEnabled;

  @override
  State<FaceTapPlay> createState() => _FaceTapPlayState();
}

class _FaceTapPlayState extends State<FaceTapPlay>
    with SingleTickerProviderStateMixin {
  final FaceTapSequencer _sequencer = FaceTapSequencer();
  // Built in initState, never lazily: a lazy controller built first in
  // dispose looks up TickerMode on a deactivated element and throws.
  late final AnimationController _clock;

  FaceTapReaction? _reaction;

  /// Where the face starts the reaction from: the rest pose, or whatever was
  /// on the face when a tap cut a reaction short.
  FaceShape? _from;

  /// Where the finger landed, in the face's 200 unit box, for the peek.
  Offset _gaze = Offset.zero;

  /// -1 for a tap on the left half, 1 on the right.
  double _side = 1;

  FaceShape get _rest => widget.restShape ?? faceFor(widget.state);

  bool _isStill(BuildContext context) =>
      (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
      widget.size < kFaceTapMoveMinSize;

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _reaction = null);
    }
  }

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this)..addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(covariant FaceTapPlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The screen's face changed under a reaction (an alarm came in): the
    // reaction makes way at once.
    if (oldWidget.state != widget.state && _reaction != null) _stop();
    if (!widget.isEnabled && _reaction != null) _stop();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _stop() {
    _clock.stop();
    _reaction = null;
  }

  void _onTapUp(TapUpDetails details) {
    final reaction = _sequencer.tap(widget.state);
    if (reaction == null) return;
    final box = Size.square(widget.size);
    final current = _reaction == null ? null : _currentShape();
    setState(() {
      _from = current;
      _reaction = reaction;
      _gaze = faceTapGaze(details.localPosition, box);
      _side = details.localPosition.dx < widget.size / 2 ? -1 : 1;
    });
    _clock.duration = Duration(milliseconds: (reaction.seconds * 1000).round());
    unawaited(_clock.forward(from: 0));
    if (reaction == FaceTapReaction.notice) {
      AppHaptics.selection();
    } else {
      AppHaptics.lightTap();
    }
  }

  double get _t => _clock.value * (_reaction?.seconds ?? 0);

  /// The reaction's own face, with the peek's eyes on the finger.
  FaceShape _target(FaceTapReaction r) {
    final shape = faceFor(r.face);
    return r == FaceTapReaction.peek ? _look(shape, _gaze) : shape;
  }

  FaceShape _currentShape() {
    final r = _reaction!;
    final frame = faceTapFrame(r, _t, still: _isStill(context));
    final entering = _t < faceTapFaceTimes(r).enter;
    final from = entering ? (_from ?? _rest) : _rest;
    return FaceShape.lerp(from, _target(r), frame.mix);
  }

  Widget _reactionFace(BuildContext context, FaceTapReaction r) {
    final still = _isStill(context);
    final frame = faceTapFrame(r, _t, still: still, leanSign: _side);
    final size = widget.size;

    // Held dizzy plays the face's own spinning swirl eyes.
    final Widget face = r == FaceTapReaction.dizzy && frame.mix >= 1 && !still
        ? FaceWidget(state: r.face, size: size, isLive: true)
        : FaceWidget(
            state: frame.mix >= 0.5 ? r.face : widget.state,
            size: size,
            shape: _currentShape(),
          );

    if (still) return face;
    return Transform.translate(
      offset: Offset(frame.lean * size, -frame.lift * size),
      child: Transform.rotate(
        angle: frame.angle,
        child: Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.diagonal3Values(frame.scaleX, frame.scaleY, 1),
          child: face,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final refresh = RefreshFaceScope.maybeOf(context);
    return ExcludeSemantics(
      child: ListenableBuilder(
        listenable: refresh ?? _never,
        builder: (context, _) {
          final refreshing =
              refresh != null && refresh.phase != RefreshFacePhase.idle;
          final active = widget.isEnabled && !refreshing;
          final reaction = active ? _reaction : null;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: active ? _onTapUp : null,
            child: SizedBox.square(
              dimension: widget.size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Kept in the tree, so an idle or refresh face keeps its
                  // place, and hidden while the reaction is drawn over it.
                  Positioned.fill(
                    child: Opacity(
                      opacity: reaction == null ? 1 : 0,
                      child: widget.child,
                    ),
                  ),
                  if (reaction != null)
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _clock,
                        builder: (context, _) =>
                            _reactionFace(context, reaction),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

const Listenable _never = _NeverChanges();

class _NeverChanges implements Listenable {
  const _NeverChanges();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// [shape] with both pupils moved by [by], in the 200 unit box.
FaceShape _look(FaceShape shape, Offset by) {
  EyeShape look(EyeShape e) => EyeShape(
    centre: e.centre,
    ballRadius: e.ballRadius,
    ballSquash: e.ballSquash,
    ballWidth: e.ballWidth,
    ballIsHead: e.ballIsHead,
    pupilRadius: e.pupilRadius,
    pupilOffset: e.pupilOffset + by,
    shineRadius: e.shineRadius,
    shineOffset: e.shineOffset,
    spiral: e.spiral,
    lid: e.lid,
    lidPoints: e.lidPoints,
    lidWidth: e.lidWidth,
  );
  return FaceShape(
    leftEye: look(shape.leftEye),
    rightEye: look(shape.rightEye),
    mouth: shape.mouth,
    leftBrow: shape.leftBrow,
    rightBrow: shape.rightBrow,
    head: shape.head,
    props: shape.props,
    tilt: shape.tilt,
    nudge: shape.nudge,
  );
}

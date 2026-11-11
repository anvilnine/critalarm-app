import 'package:critalarm/design/tokens/curves.dart';
import 'package:flutter/widgets.dart';

/// How a page over the ambient canvas comes in, and how the page under it
/// leaves.
enum AmbientEntrance {
  /// The page slides in a little from the side while the one under drifts
  /// the other way. The default for a page deeper in the same place, such
  /// as a Topic under the Topics list.
  slide,

  /// The page lifts up from just below while the one under sinks back and
  /// fades. For a screen that starts something new over everything else,
  /// such as the new topic form. The canvas behind holds still and only
  /// morphs, so the hand off reads as one sheet replacing another.
  lift,
}

/// Where a page stands at one point of a lift: how far below its rest it
/// sits, how large it is and how much of it shows.
@immutable
class LiftPose {
  const LiftPose({
    required this.dy,
    required this.scale,
    required this.opacity,
  });

  /// Points below the resting place. Negative is above it.
  final double dy;
  final double scale;
  final double opacity;

  /// The resting frame: in place, full size, fully shown.
  static const LiftPose rest = LiftPose(dy: 0, scale: 1, opacity: 1);

  @override
  bool operator ==(Object other) =>
      other is LiftPose &&
      other.dy == dy &&
      other.scale == scale &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(dy, scale, opacity);

  @override
  String toString() => 'LiftPose(dy: $dy, scale: $scale, opacity: $opacity)';
}

/// How far below its rest the lifting page starts, in points.
const double kLiftRise = 28;

/// How far up the page underneath drifts as it sinks back, in points.
const double kLiftSinkRise = 10;

/// How small the page underneath gets as it sinks back.
const double kLiftSinkScale = 0.96;

/// The screen that leaves, whichever it is, is gone by this point of the
/// move.
const double _leaveFadeEnd = 0.35;

/// The screen that arrives starts to show at this point of the move, and is
/// fully shown by [_arriveFadeEnd]. The two fades never overlap: the leaving
/// screen is gone before the arriving one starts to show, and between them
/// the canvas shows on its own for a moment. No frame shows both screens.
const double _arriveFadeStart = 0.45;
const double _arriveFadeEnd = 0.85;

/// How far the leaving screen has faded at [u] of the move, 0 to 1.
double _leaveFade(double u) =>
    Curves.easeOut.transform((u / _leaveFadeEnd).clamp(0.0, 1.0));

/// How far the arriving screen has faded in at [u] of the move, 0 to 1.
double _arriveFade(double u) => Curves.easeOut.transform(
  ((u - _arriveFadeStart) / (_arriveFadeEnd - _arriveFadeStart)).clamp(
    0.0,
    1.0,
  ),
);

/// The pose of the page that lifts in, at [t] of its route animation.
///
/// [reverse] is a pop: the animation runs from 1 back to 0. Both ways are
/// one eased move with no overshoot that starts at once, so a tap on the
/// close cross answers in the first frame. On the way in the page rises and
/// fades in late; on the way out it drops back and fades out early.
LiftPose liftInPose(double t, {bool reverse = false}) {
  final p = t.clamp(0.0, 1.0);
  if (p >= 1) return LiftPose.rest;
  if (reverse) {
    final u = 1 - p;
    return LiftPose(
      dy: kLiftRise * AppCurves.easeOut.transform(u),
      scale: 1,
      opacity: 1 - _leaveFade(u),
    );
  }
  return LiftPose(
    dy: kLiftRise * (1 - AppCurves.easeOut.transform(p)),
    scale: 1,
    opacity: _arriveFade(p),
  );
}

/// The pose of the page under a lift, at [t] of the covering route's
/// animation: it sinks back, a little smaller and a little higher, and
/// fades out early. On a pop ([reverse]) it comes forward again and fades in
/// late, after the page above has mostly gone.
LiftPose liftCoveredPose(double t, {bool reverse = false}) {
  final p = t.clamp(0.0, 1.0);
  if (p <= 0) return LiftPose.rest;
  final double sunk;
  final double opacity;
  if (reverse) {
    final u = 1 - p;
    sunk = 1 - AppCurves.easeOut.transform(u);
    opacity = _arriveFade(u);
  } else {
    sunk = AppCurves.easeOut.transform(p);
    opacity = 1 - _leaveFade(p);
  }
  return LiftPose(
    dy: -kLiftSinkRise * sunk,
    scale: 1 - (1 - kLiftSinkScale) * sunk,
    opacity: opacity,
  );
}

/// Draws [child] at the pose [pose] works out from the animation.
class LiftTransition extends AnimatedWidget {
  const LiftTransition({
    required Animation<double> animation,
    required this.pose,
    required this.child,
    super.key,
  }) : super(listenable: animation);

  /// The pose at a value of the animation. `reverse` is true while the
  /// animation runs back towards 0.
  final LiftPose Function(double t, {bool reverse}) pose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    final at = pose(
      animation.value,
      reverse: animation.status == AnimationStatus.reverse,
    );
    // The same wrappers in every frame, the resting one included, so the
    // page under them is never rebuilt when the lift starts or ends.
    return Opacity(
      opacity: at.opacity,
      child: Transform.translate(
        offset: Offset(0, at.dy),
        child: Transform.scale(scale: at.scale, child: child),
      ),
    );
  }
}

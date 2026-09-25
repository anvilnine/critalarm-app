import 'dart:ui' show Offset, lerpDouble;

import 'package:critalarm/design/faces/face_rig.dart';

/// One extra drawn around a ringing face: a sweat drop, a tear, a puff of
/// steam, a bell. [FaceShape] props cover the calm faces; these are the
/// louder ones only a ringing face needs.
enum RingFxKind {
  /// Curved sound lines either side of the head.
  soundWaves,

  /// A falling drop of sweat.
  sweat,

  /// A tear running down.
  tear,

  /// A curl of steam blowing off the head.
  steam,

  /// The cross shaped vein of a cartoon temper.
  angerVein,

  /// A question mark.
  question,

  /// An exclamation mark.
  exclaim,

  /// A five point star, for a dizzy orbit or a hit.
  star,

  /// An alarm clock bell, mounted on the head.
  bell,

  /// The striker that swings between two bells.
  hammer,

  /// A zigzag bolt.
  bolt,

  /// A rotating siren dome.
  siren,

  /// Straight speed lines, for a jump or a dash.
  speedLines,

  /// A row of gritted teeth drawn over a filled mouth.
  teeth,

  /// A drip running down off the head.
  drip,

  /// A soft ring pulsing out from the head.
  pulseRing,

  /// Pink blush patches on the cheeks.
  blush,
}

/// One extra, placed in the face's 200 unit box. It may sit outside the
/// head: the stage leaves room around it.
class RingFx {
  /// A [kind] at [at], [scale] times its normal size, turned [rotation]
  /// radians, [alpha] visible.
  const RingFx(
    this.kind, {
    this.at = const Offset(100, 100),
    this.scale = 1,
    this.rotation = 0,
    this.alpha = 1,
    this.onHead = false,
    this.inFront = true,
    this.phase = 0,
    this.extent = Offset.zero,
  });

  /// Which extra this is.
  final RingFxKind kind;

  /// Where it sits, in the 200 unit box.
  final Offset at;

  /// How big, 1 being its normal size.
  final double scale;

  /// How far it is turned, in radians.
  final double rotation;

  /// How visible, 0 to 1.
  final double alpha;

  /// True moves it with the head's tilt, nudge and squash, as a sweat drop
  /// on the brow should. False leaves it where it is on the stage.
  final bool onHead;

  /// False draws it behind the head.
  final bool inFront;

  /// A free 0 to 1 value some extras animate by, such as the siren's sweep.
  final double phase;

  /// Width and height, for an extra that fills a box, such as teeth filling
  /// the mouth they are drawn over.
  final Offset extent;

  /// The same extra, [by] times as visible.
  RingFx faded(double by) => RingFx(
    kind,
    at: at,
    scale: scale,
    rotation: rotation,
    alpha: alpha * by,
    onHead: onHead,
    inFront: inFront,
    phase: phase,
    extent: extent,
  );
}

/// Everything about a ringing face at one moment of its loop.
class RingingFrame {
  /// The [face] at this moment, moved and tinted as the rest says.
  const RingingFrame({
    required this.face,
    this.tilt = 0,
    this.nudge = Offset.zero,
    this.scale = 1,
    this.flush = 0,
    this.flash = 0,
    this.spin = 0,
    this.fx = const [],
  });

  /// Blends [t] of the way from [a] to [b], so one ringing style can turn
  /// into another. The extras do not move between the two: [a]'s fade out
  /// while [b]'s fade in.
  factory RingingFrame.lerp(RingingFrame a, RingingFrame b, double t) =>
      RingingFrame(
        face: FaceShape.lerp(a.face, b.face, t),
        tilt: lerpDouble(a.tilt, b.tilt, t)!,
        nudge: Offset.lerp(a.nudge, b.nudge, t)!,
        scale: lerpDouble(a.scale, b.scale, t)!,
        flush: lerpDouble(a.flush, b.flush, t)!,
        flash: lerpDouble(a.flash, b.flash, t)!,
        spin: lerpDouble(a.spin, b.spin, t)!,
        fx: [
          for (final fx in a.fx) fx.faded(1 - t),
          for (final fx in b.fx) fx.faded(t),
        ],
      );

  /// The features, drawn by the ordinary face painter.
  final FaceShape face;

  /// How far the head is turned, in radians.
  final double tilt;

  /// How far the head is moved, in 200 unit box units.
  final Offset nudge;

  /// How big the head is against its normal size.
  final double scale;

  /// How far the head's fill has gone toward the alarm red, 0 to 1.
  final double flush;

  /// How far the fill and ink have swapped, 0 to 1. A shock flashes this.
  final double flash;

  /// How far a swirl eye is turned, in radians.
  final double spin;

  /// The extras around the head.
  final List<RingFx> fx;
}

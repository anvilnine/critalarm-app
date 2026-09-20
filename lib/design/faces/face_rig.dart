import 'dart:ui' show Color, Offset, lerpDouble;

/// The parts a face is built from, and how to blend one set of them into
/// another.
///
/// Every value here is a plain number, a point or a colour, so any two faces
/// can be mixed part by part. That is what lets the refresh face melt from
/// calm into working, and what lets the idle loop blink without cutting.
///
/// All coordinates are in the painter's 200 unit box. The head fills
/// 12..188 on both axes, so its middle is (100, 100).

/// A small extra drawn outside the face: the lines that pop above a win, the
/// Zzz over a sleeping head, the puff of a breath out.
enum PropKind {
  /// Three short lines fanned above the head.
  popLines,

  /// Three Z's climbing away from the head.
  zzz,

  /// A little cloud beside the mouth.
  puff,

  /// A heart above one corner.
  heart,

  /// Curved lines either side of the head, for a shake.
  motionArcs,
}

/// One extra, somewhere near the head.
class PropShape {
  /// A [kind] centred on [at], [scale] times its normal size, [alpha] visible.
  const PropShape(
    this.kind, {
    this.at = Offset.zero,
    this.scale = 1,
    this.alpha = 1,
  });

  /// Moves [a] toward [b], or fades one in or out when only one side has it.
  factory PropShape.lerp(PropShape a, PropShape b, double t) => PropShape(
    a.kind,
    at: Offset.lerp(a.at, b.at, t)!,
    scale: lerpDouble(a.scale, b.scale, t)!,
    alpha: lerpDouble(a.alpha, b.alpha, t)!,
  );

  /// Which extra this is. Two props only blend when their kinds match.
  final PropKind kind;

  /// Where it sits, in the 200 unit box.
  final Offset at;

  /// How big, 1 being its normal size.
  final double scale;

  /// How visible, 0 to 1. A prop the other face does not have fades from 0.
  final double alpha;

  /// The same prop with nothing showing, to blend in or out against. It is
  /// shrunk as well as faded, so an extra grows in rather than popping.
  PropShape get hidden => PropShape(kind, at: at, scale: 0, alpha: 0);
}

/// One eye.
///
/// It is drawn in three layers, and a face uses only the ones it needs:
///
/// 1. a white ball, when [ballRadius] is above zero,
/// 2. a pupil, offset from the middle of the ball so the eye can look around
///    without the ball moving,
/// 3. a lid, drawn as a stroke through [lidPoints]. At [lid] 1 the lid is all
///    you see, which is how a blink, a squeezed `> <` and a sleepy droop are
///    all the same part with different numbers.
///
/// A plain dark dot, which most of the older faces use, is a pupil with no
/// ball and no lid.
class EyeShape {
  /// An eye centred on [centre]. See the class notes for the layers.
  const EyeShape({
    required this.centre,
    this.ballRadius = 0,
    this.ballSquash = 1,
    this.ballWidth = 7,
    this.ballIsHead = false,
    this.pupilRadius = 11,
    this.pupilOffset = Offset.zero,
    this.shineRadius = 0,
    this.shineOffset = Offset.zero,
    this.spiral = 0,
    this.lid = 0,
    this.lidPoints = const [Offset.zero, Offset.zero, Offset.zero],
    this.lidWidth = 10,
  });

  /// A plain dark dot of radius 11 at [centre], what most faces use.
  const EyeShape.dot(Offset centre, {double radius = 11})
    : this(centre: centre, pupilRadius: radius);

  /// Moves every part of the eye [t] of the way from [a] to [b].
  factory EyeShape.lerp(EyeShape a, EyeShape b, double t) => EyeShape(
    centre: Offset.lerp(a.centre, b.centre, t)!,
    // The white is measured from where it really starts, which on a plain
    // dot is the edge of the pupil. Growing it from nothing would inflate a
    // white blob out of the middle of the eye instead of opening it.
    ballRadius: lerpDouble(a.ball, b.ball, t)!,
    ballSquash: lerpDouble(a.ballSquash, b.ballSquash, t)!,
    ballWidth: lerpDouble(a.ballWidth, b.ballWidth, t)!,
    // Which colour fills the ball cannot be halfway, so it flips at the
    // halfway point. Only one face wears the head colour, so no blend that
    // anybody watches crosses this.
    ballIsHead: t < 0.5 ? a.ballIsHead : b.ballIsHead,
    pupilRadius: lerpDouble(a.pupilRadius, b.pupilRadius, t)!,
    pupilOffset: Offset.lerp(a.pupilOffset, b.pupilOffset, t)!,
    shineRadius: lerpDouble(a.shineRadius, b.shineRadius, t)!,
    shineOffset: Offset.lerp(a.shineOffset, b.shineOffset, t)!,
    spiral: lerpDouble(a.spiral, b.spiral, t)!,
    lid: lerpDouble(a.lid, b.lid, t)!,
    // A face with no lid shape of its own still has three points to blend
    // from, so they are laid flat across the eye rather than left at zero.
    lidPoints: lerpPoints(a.resolvedLidPoints, b.resolvedLidPoints, t),
    lidWidth: lerpDouble(a.lidWidth, b.lidWidth, t)!,
  );

  /// The middle of the eye.
  final Offset centre;

  /// The white ball behind the pupil. Zero means the eye is a plain dot, and
  /// the white starts at the edge of the pupil. Read it through [ball].
  final double ballRadius;

  /// How squashed the ball is from top to bottom. 1 is round.
  final double ballSquash;

  /// Pen width for the ring around the ball.
  final double ballWidth;

  /// True leaves the head colour showing inside the ring instead of white,
  /// which is the wide ringed eye an alarm wears.
  final bool ballIsHead;

  /// The dark middle of the eye.
  final double pupilRadius;

  /// How far the pupil sits from [centre], which is how the eye looks around.
  final Offset pupilOffset;

  /// A white dot on the pupil. Zero draws none.
  final double shineRadius;

  /// Where the shine sits, measured from the pupil.
  final Offset shineOffset;

  /// How much of a swirl is drawn instead of a plain pupil, 0 to 1.
  final double spiral;

  /// How shut the eye is. 0 shows the ball and pupil, 1 shows only the lid.
  final double lid;

  /// The lid, as three points: left end, middle of the curve, right end.
  final List<Offset> lidPoints;

  /// Pen width for the lid.
  final double lidWidth;

  /// How far out the white goes. A plain dot has none, so it counts as
  /// starting right at the pupil's edge, and an eye opening wide is the white
  /// growing out from behind the pupil rather than appearing on top of it.
  double get ball => ballRadius > 0 ? ballRadius : pupilRadius;

  /// How much white is actually showing, 0 to 1. It fades in over the first
  /// few units so a dot does not get a ring drawn tight around it.
  double get whiteShowing => ((ball - pupilRadius) / 5).clamp(0.0, 1.0);

  /// True when this eye is a plain dot, which the painter draws as a circle
  /// rather than a stroke so the shape does not depend on how the pen caps.
  bool get isFlatLid =>
      lidPoints[0] == Offset.zero &&
      lidPoints[1] == Offset.zero &&
      lidPoints[2] == Offset.zero;

  /// The lid to use when blending. An eye with no lid of its own gets a flat
  /// one across the middle, so closing it reads as a lid coming down.
  List<Offset> get resolvedLidPoints => isFlatLid
      ? [
          centre + const Offset(-16, 0),
          centre,
          centre + const Offset(16, 0),
        ]
      : lidPoints;
}

/// One eyebrow, drawn as a curve through three points: the left end, the
/// middle of the curve, and the right end.
///
/// [alpha] lets a face without a brow keep one to blend from, so a calm face
/// grows a brow instead of popping one in.
class BrowShape {
  /// A brow through [points] (always three) drawn with a pen [width] wide,
  /// [alpha] visible.
  const BrowShape(this.points, {this.width = 10, this.alpha = 1});

  /// Moves every point, the pen width and the alpha [t] of the way from [a]
  /// to [b].
  factory BrowShape.lerp(BrowShape a, BrowShape b, double t) => BrowShape(
    lerpPoints(a.points, b.points, t),
    width: lerpDouble(a.width, b.width, t)!,
    alpha: lerpDouble(a.alpha, b.alpha, t)!,
  );

  /// The brow a face rests with: flat above the left eye, invisible.
  static const BrowShape restingLeft = BrowShape(
    [Offset(56, 70), Offset(71, 70), Offset(86, 70)],
    alpha: 0,
  );

  /// The same brow above the right eye.
  static const BrowShape restingRight = BrowShape(
    [Offset(114, 70), Offset(129, 70), Offset(144, 70)],
    alpha: 0,
  );

  /// Three points, in the painter's 200 unit box.
  final List<Offset> points;

  /// Pen width in 200 unit box units.
  final double width;

  /// How visible the brow is, 0 to 1.
  final double alpha;
}

/// The mouth, drawn as a smooth curve through [pointCount] points.
///
/// [fill] paints the inside, which is what makes an open mouth read as open:
/// a yawn, a laugh, the small `v` of a win. A stroked line with no fill is
/// every closed mouth.
class MouthShape {
  /// A mouth through [points] (always [pointCount]).
  const MouthShape(
    this.points, {
    this.width = 10,
    this.fill = 0,
    this.fillColor,
    this.fillsWithInk = false,
  });

  /// Moves every point, the pen width, the fill and its colour.
  factory MouthShape.lerp(MouthShape a, MouthShape b, double t) => MouthShape(
    lerpPoints(a.points, b.points, t),
    width: lerpDouble(a.width, b.width, t)!,
    fill: lerpDouble(a.fill, b.fill, t)!,
    fillColor: Color.lerp(a.fillColor, b.fillColor, t),
    // A dark mouth and a coral one cannot be halfway, so this flips at the
    // halfway point rather than trying to mix the two.
    fillsWithInk: t < 0.5 ? a.fillsWithInk : b.fillsWithInk,
  );

  /// Every mouth has this many points, so any two can be blended.
  static const int pointCount = 13;

  /// Points in the painter's 200 unit box, left to right.
  final List<Offset> points;

  /// Pen width in 200 unit box units.
  final double width;

  /// How solidly the inside is painted, 0 to 1. Above zero the ends are
  /// joined so there is an inside to paint.
  final double fill;

  /// What the inside is painted with. Null leaves it to [fillsWithInk]: the
  /// face's ink when that is true, and the coral tongue colour otherwise.
  final Color? fillColor;

  /// True paints the inside with the face's ink, so a dark open mouth stays
  /// dark against a light head and light against a dark one. A fixed colour
  /// would only be right in one theme.
  final bool fillsWithInk;
}

/// The head itself.
class HeadShape {
  /// A head [squashX] wide and [squashY] tall against its normal size, drawn
  /// with a [strokeWidth] pen.
  const HeadShape({this.squashX = 1, this.squashY = 1, this.strokeWidth = 10});

  /// Moves every number [t] of the way from [a] to [b].
  factory HeadShape.lerp(HeadShape a, HeadShape b, double t) => HeadShape(
    squashX: lerpDouble(a.squashX, b.squashX, t)!,
    squashY: lerpDouble(a.squashY, b.squashY, t)!,
    strokeWidth: lerpDouble(a.strokeWidth, b.strokeWidth, t)!,
  );

  /// How wide the head is against its normal size.
  final double squashX;

  /// How tall the head is against its normal size.
  final double squashY;

  /// Pen width for the outline.
  final double strokeWidth;
}

/// A whole face: a head, two brows, two eyes, a mouth and any extras.
class FaceShape {
  /// Builds a face out of its parts. Everything but the eyes and the mouth
  /// has a resting value, so a plain face is short to write.
  const FaceShape({
    required this.leftEye,
    required this.rightEye,
    required this.mouth,
    this.leftBrow = BrowShape.restingLeft,
    this.rightBrow = BrowShape.restingRight,
    this.head = const HeadShape(),
    this.props = const [],
    this.tilt = 0,
    this.nudge = Offset.zero,
  });

  /// Blends every part [t] of the way from [a] to [b].
  factory FaceShape.lerp(FaceShape a, FaceShape b, double t) => FaceShape(
    leftEye: EyeShape.lerp(a.leftEye, b.leftEye, t),
    rightEye: EyeShape.lerp(a.rightEye, b.rightEye, t),
    mouth: MouthShape.lerp(a.mouth, b.mouth, t),
    leftBrow: BrowShape.lerp(a.leftBrow, b.leftBrow, t),
    rightBrow: BrowShape.lerp(a.rightBrow, b.rightBrow, t),
    head: HeadShape.lerp(a.head, b.head, t),
    props: _lerpProps(a.props, b.props, t),
    tilt: lerpDouble(a.tilt, b.tilt, t)!,
    nudge: Offset.lerp(a.nudge, b.nudge, t)!,
  );

  /// The eye on the left of the screen.
  final EyeShape leftEye;

  /// The eye on the right of the screen.
  final EyeShape rightEye;

  /// The mouth.
  final MouthShape mouth;

  /// The brow above [leftEye]. Invisible on a face that has no brow.
  final BrowShape leftBrow;

  /// The brow above [rightEye]. Invisible on a face that has no brow.
  final BrowShape rightBrow;

  /// The head.
  final HeadShape head;

  /// Anything drawn outside the head.
  final List<PropShape> props;

  /// How far the whole head is turned, in radians. The widget applies this,
  /// not the painter, so the head and everything on it turn together.
  final double tilt;

  /// How far the whole head is moved, in 200 unit box units. Applied by the
  /// widget alongside [tilt].
  final Offset nudge;

  /// The same face with everything about the eyes swapped for a shut lid,
  /// which is all a blink is.
  FaceShape get blinking => FaceShape(
    leftEye: EyeShape.lerp(leftEye, _shut(leftEye), 1),
    rightEye: EyeShape.lerp(rightEye, _shut(rightEye), 1),
    mouth: mouth,
    leftBrow: leftBrow,
    rightBrow: rightBrow,
    head: head,
    props: props,
    tilt: tilt,
    nudge: nudge,
  );

  static EyeShape _shut(EyeShape eye) => EyeShape(
    centre: eye.centre,
    ballRadius: eye.ballRadius,
    ballSquash: eye.ballSquash,
    pupilRadius: eye.pupilRadius,
    pupilOffset: eye.pupilOffset,
    lid: 1,
    lidPoints: eye.resolvedLidPoints,
    lidWidth: eye.lidWidth,
  );
}

/// Pairs the props of two faces by kind so each one fades in, fades out, or
/// moves. A prop only one side has blends against itself with nothing
/// showing, which is why a Zzz drifts in rather than appearing.
List<PropShape> _lerpProps(List<PropShape> a, List<PropShape> b, double t) {
  final out = <PropShape>[];
  for (final from in a) {
    PropShape? to;
    for (final candidate in b) {
      if (candidate.kind == from.kind) {
        to = candidate;
        break;
      }
    }
    out.add(PropShape.lerp(from, to ?? from.hidden, t));
  }
  for (final to in b) {
    if (a.any((p) => p.kind == to.kind)) continue;
    out.add(PropShape.lerp(to.hidden, to, t));
  }
  return out;
}

/// Moves every point in [a] toward the matching point in [b].
List<Offset> lerpPoints(List<Offset> a, List<Offset> b, double t) => [
  for (var i = 0; i < a.length; i++) Offset.lerp(a[i], b[i], t)!,
];

import 'dart:math' as math;
import 'dart:ui' show Color, Offset;

import 'package:critalarm/design/faces/face_shape.dart';
import 'package:critalarm/design/faces/ringing/ringing_frame.dart';
import 'package:critalarm/design/faces/ringing/ringing_style.dart';

/// Where each ringing face is at moment [t] of its loop.
///
/// [t] runs 0 to 1 over one [RingingStylePresentation.period] and wraps, so
/// every style is written to land back where it started: anything periodic
/// turns a whole number of times per loop, and anything that happens once
/// (a jump, a melt) is back at rest by the end.
///
/// This is pure: the same [style] and [t] always give the same frame, which
/// is what lets the tests walk every loop.
RingingFrame ringingFrameFor(RingingStyle style, double t) {
  final at = _frac(t);
  return switch (style) {
    RingingStyle.classic => _classic(at),
    RingingStyle.panic => _panic(at),
    RingingStyle.rage => _rage(at),
    RingingStyle.confused => _confused(at),
    RingingStyle.dizzy => _dizzy(at),
    RingingStyle.sobbing => _sobbing(at),
    RingingStyle.scream => _scream(at),
    RingingStyle.bellHead => _bellHead(at),
    RingingStyle.eyesPop => _eyesPop(at),
    RingingStyle.annoyed => _annoyed(at),
    RingingStyle.startled => _startled(at),
    RingingStyle.hyperventilating => _hyperventilating(at),
    RingingStyle.zapped => _zapped(at),
    RingingStyle.bouncing => _bouncing(at),
    RingingStyle.terrified => _terrified(at),
    RingingStyle.siren => _siren(at),
    RingingStyle.meltdown => _meltdown(at),
    RingingStyle.spinOut => _spinOut(at),
  };
}

// ---------------------------------------------------------------------------
// Timing helpers. Everything is a plain function of t.
// ---------------------------------------------------------------------------

const double _tau = 2 * math.pi;

double _frac(double x) => x - x.floorToDouble();

/// A sine that turns [cycles] whole times per loop, -1 to 1.
double _wave(double t, int cycles, [double phase = 0]) =>
    math.sin(_tau * (t * cycles + phase));

/// The same as [_wave], moved to 0 to 1.
double _pulse(double t, int cycles, [double phase = 0]) =>
    0.5 + 0.5 * _wave(t, cycles, phase);

/// How far [t] is between [a] and [b], held at 0 before and 1 after.
double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0, 1);

/// Ease in and out.
double _ease(double x) =>
    x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3) / 2;

/// Overshoots and settles, for anything that springs into place.
double _elastic(double x) {
  if (x <= 0) return 0;
  if (x >= 1) return 1;
  return math.pow(2, -10 * x) * math.sin((x - 0.075) * _tau / 0.3) + 1;
}

/// Up and back down over 0 to 1.
double _bump(double x) => math.sin(math.pi * x.clamp(0, 1));

/// Squares a wave off so a glance snaps rather than slides.
double _snap(double v, [double k = 4]) {
  final e = math.exp(2 * k * v);
  return (e - 1) / (e + 1);
}

double _deg(double d) => d * math.pi / 180;

// ---------------------------------------------------------------------------
// Part helpers.
// ---------------------------------------------------------------------------

EyeShape _eye(
  Offset centre, {
  double ball = 0,
  double pupil = 11,
  Offset look = Offset.zero,
  bool hollow = false,
  double shine = 0,
  double squash = 1,
  double spiral = 0,
  double lid = 0,
  List<Offset>? lidPoints,
  double width = 10,
}) => EyeShape(
  centre: centre,
  ballRadius: ball,
  ballSquash: squash,
  ballWidth: width,
  ballIsHead: hollow,
  pupilRadius: pupil,
  pupilOffset: look,
  shineRadius: shine,
  shineOffset: const Offset(-4, -4),
  spiral: spiral,
  lid: lid,
  lidPoints: lidPoints ?? restingLid(centre),
  lidWidth: width,
);

/// A brow through three points, moved by [by].
BrowShape _brow(
  Offset a,
  Offset b,
  Offset c, {
  Offset by = Offset.zero,
  double width = 11,
  double alpha = 1,
}) => BrowShape([a + by, b + by, c + by], width: width, alpha: alpha);

/// A pair of brows mirrored across the middle of the face. [a], [b] and [c]
/// describe the left one, outer end first.
(BrowShape, BrowShape) _brows(
  Offset a,
  Offset b,
  Offset c, {
  Offset by = Offset.zero,
  double width = 11,
  double alpha = 1,
}) {
  Offset m(Offset p) => Offset(200 - p.dx, p.dy);
  return (
    _brow(a, b, c, by: by, width: width, alpha: alpha),
    _brow(m(c), m(b), m(a), by: by, width: width, alpha: alpha),
  );
}

/// Brows slammed down toward the nose, the way the alarm has always worn
/// them.
(BrowShape, BrowShape) _alarmBrows({double lift = 0, double width = 11}) =>
    _brows(
      const Offset(50, 58),
      const Offset(67, 63),
      const Offset(84, 68),
      by: Offset(0, -lift),
      width: width,
    );

/// Brows pulled up in the middle, for fear and sorrow.
(BrowShape, BrowShape) _worriedBrows({double lift = 0, double width = 11}) =>
    _brows(
      const Offset(48, 74),
      const Offset(65, 63),
      const Offset(86, 56),
      by: Offset(0, -lift),
      width: width,
    );

/// A boxy open mouth [w] by [h] around [centre], for gritted teeth. [bend]
/// pulls the corners down (positive) or up (negative).
List<Offset> _gritMouth(Offset centre, double w, double h, {double bend = 0}) {
  Offset at(double u, double y) => Offset(
    centre.dx - w / 2 + w * u,
    y + bend * 4 * (u - 0.5) * (u - 0.5),
  );
  return lipsMouth(
    (u) => at(u, centre.dy + h / 2),
    (u) => at(u, centre.dy - h / 2),
  );
}

/// An open mouth whose lips ripple. [shift] slides the ripple along.
List<Offset> _wavyOpen(
  Offset centre,
  double w,
  double h,
  double amp,
  double shift, {
  double waves = 2,
}) {
  double env(double u) => math.sqrt(math.sin(math.pi * u).clamp(0, 1));
  double ripple(double u, double off) =>
      amp * math.sin(_tau * (waves * u + shift) + off);
  return lipsMouth(
    (u) => Offset(
      centre.dx - w / 2 + w * u,
      centre.dy + env(u) * h / 2 + ripple(u, 0),
    ),
    (u) => Offset(
      centre.dx - w / 2 + w * u,
      centre.dy - env(u) * h / 2 + ripple(u, 1.3),
    ),
  );
}

/// A shut mouth along a wave, for dazed and melting faces.
List<Offset> _wavyLine(
  Offset centre,
  double w,
  double amp,
  double shift, {
  double waves = 1.5,
  double frown = 0,
}) => sampleMouth(
  (u) => Offset(
    centre.dx - w / 2 + w * u,
    centre.dy + amp * math.sin(_tau * (waves * u + shift)) - frown * _bump(u),
  ),
);

MouthShape _inkMouth(List<Offset> points, {double width = 11}) =>
    MouthShape(points, width: width, fill: 1, fillsWithInk: true);

const Color _teethWhite = Color(0xFFFFFFFF);

MouthShape _teethMouth(List<Offset> points) =>
    MouthShape(points, fill: 1, fillColor: _teethWhite);

RingFx _teeth(Offset centre, double w, double h, {double bend = 0}) => RingFx(
  RingFxKind.teeth,
  at: centre,
  extent: Offset(w, h),
  phase: bend,
  onHead: true,
);

/// Rebuilds [face] with a different head, props, or both.
FaceShape _with(FaceShape face, {HeadShape? head, List<PropShape>? props}) =>
    FaceShape(
      leftEye: face.leftEye,
      rightEye: face.rightEye,
      mouth: face.mouth,
      leftBrow: face.leftBrow,
      rightBrow: face.rightBrow,
      head: head ?? face.head,
      props: props ?? face.props,
      tilt: face.tilt,
      nudge: face.nudge,
    );

/// A drop flung along an arc from [from], [p] of the way through its flight.
/// It points back the way it came, so it reads as flying.
RingFx _flung(
  RingFxKind kind,
  Offset from,
  Offset velocity,
  double gravity,
  double p, {
  double scale = 1,
  double alpha = 1,
}) {
  final at = from + velocity * p + Offset(0, gravity * p * p);
  final vx = velocity.dx;
  final vy = velocity.dy + 2 * gravity * p;
  return RingFx(
    kind,
    at: at,
    scale: scale,
    rotation: math.atan2(-vy, -vx) + math.pi / 2,
    alpha: alpha * (1 - _seg(p, 0.7, 1)) * _seg(p, 0, 0.08),
  );
}

// ---------------------------------------------------------------------------
// The styles.
// ---------------------------------------------------------------------------

RingingFrame _classic(double t) {
  final shout = _pulse(t, 3);
  final jitter = Offset(_wave(t, 12) * 1.2, _wave(t, 9, 0.25));
  final (lb, rb) = _alarmBrows(lift: 4 * shout);
  return RingingFrame(
    face: FaceShape(
      leftEye: _eye(
        const Offset(70, 94),
        ball: 17 + 2 * shout,
        pupil: 6,
        hollow: true,
        width: 11,
        look: jitter,
      ),
      rightEye: _eye(
        const Offset(130, 94),
        ball: 17 + 2 * shout,
        pupil: 6,
        hollow: true,
        width: 11,
        look: jitter,
      ),
      leftBrow: lb,
      rightBrow: rb,
      mouth: _inkMouth(
        ovalMouth(const Offset(100, 142), 14 + 5 * shout, 14 + 10 * shout),
      ),
      head: const HeadShape(strokeWidth: 12),
    ),
    tilt: _deg(4) * _wave(t, 6),
    scale: 1 + 0.03 * shout,
    fx: [RingFx(RingFxKind.soundWaves, phase: _frac(t * 2))],
  );
}

RingingFrame _panic(double t) {
  final dart = _snap(_wave(t, 4));
  final look = Offset(dart * 9, 2 * _wave(t, 8));
  final scream = _pulse(t, 4);
  final (lb, rb) = _worriedBrows(lift: 3 * _pulse(t, 8));
  return RingingFrame(
    face: FaceShape(
      leftEye: _eye(
        const Offset(68, 96),
        ball: 21,
        pupil: 8,
        shine: 3,
        look: look,
      ),
      rightEye: _eye(
        const Offset(132, 96),
        ball: 21,
        pupil: 8,
        shine: 3,
        look: look,
      ),
      leftBrow: lb,
      rightBrow: rb,
      mouth: _inkMouth(
        _wavyOpen(
          const Offset(100, 147),
          56,
          18 + 6 * scream,
          2.5,
          t * 3,
        ),
        width: 10,
      ),
      head: const HeadShape(strokeWidth: 11),
    ),
    tilt: _deg(2.5) * _wave(t, 5),
    nudge: Offset(_wave(t, 10) * 2.5, _wave(t, 7, 0.3) * 1.5),
    fx: [
      for (var i = 0; i < 4; i++)
        _flung(
          RingFxKind.sweat,
          Offset(i.isEven ? 34 : 166, 58 + (i ~/ 2) * 14),
          Offset(i.isEven ? -46 : 46, -40),
          110,
          _frac(t * 2 + i / 4),
          scale: 0.9,
        ),
      RingFx(
        RingFxKind.exclaim,
        at: const Offset(100, -14),
        scale: 0.9 + 0.2 * _pulse(t, 4),
        rotation: _deg(10) * _wave(t, 2),
      ),
    ],
  );
}

RingingFrame _rage(double t) {
  final throb = _pulse(t, 4);
  final (lb, rb) = _brows(
    const Offset(46, 68),
    const Offset(66, 77),
    const Offset(88, 88),
    by: Offset(0, 2 * throb),
    width: 13,
  );
  const mouthAt = Offset(100, 147);
  return RingingFrame(
    face: FaceShape(
      leftEye: _eye(
        const Offset(70, 100),
        ball: 15,
        squash: 0.72,
        pupil: 8,
        look: const Offset(4, 0),
      ),
      rightEye: _eye(
        const Offset(130, 100),
        ball: 15,
        squash: 0.72,
        pupil: 8,
        look: const Offset(-4, 0),
      ),
      leftBrow: lb,
      rightBrow: rb,
      mouth: _teethMouth(_gritMouth(mouthAt, 60, 20, bend: 6)),
      head: const HeadShape(strokeWidth: 13),
    ),
    nudge: Offset(_wave(t, 14) * 2.2, _wave(t, 11, 0.2) * 0.8),
    scale: 1 + 0.025 * throb,
    flush: 0.45 + 0.4 * throb,
    fx: [
      _teeth(mouthAt, 60, 20, bend: 6),
      RingFx(
        RingFxKind.angerVein,
        at: const Offset(150, 42),
        scale: 0.75 + 0.35 * throb,
        onHead: true,
      ),
      for (final side in const [-1.0, 1.0])
        for (var i = 0; i < 2; i++)
          () {
            final p = _frac(t * 2 + i / 2 + (side > 0 ? 0.25 : 0));
            return RingFx(
              RingFxKind.steam,
              at: Offset(100 + side * (86 + 34 * p), 52 - 44 * p),
              scale: 0.5 + 0.9 * p,
              alpha: (1 - p) * _seg(p, 0, 0.1),
            );
          }(),
    ],
  );
}

RingingFrame _confused(double t) {
  final sway = _wave(t, 1);
  final k = 0.5 + 0.5 * sway;
  final leftHigh = [
    const Offset(48, 64),
    const Offset(66, 50),
    const Offset(86, 58),
  ];
  final leftLow = [
    const Offset(50, 72),
    const Offset(68, 72),
    const Offset(86, 74),
  ];
  final rightHigh = [
    const Offset(114, 58),
    const Offset(134, 50),
    const Offset(152, 64),
  ];
  final rightLow = [
    const Offset(114, 74),
    const Offset(132, 72),
    const Offset(150, 72),
  ];
  final look = Offset(sway * 5, -6);
  return RingingFrame(
    face: FaceShape(
      leftEye: _eye(
        const Offset(68, 96),
        ball: 16 + 5 * k,
        pupil: 7 + 2 * k,
        shine: 3,
        look: look,
      ),
      rightEye: _eye(
        const Offset(132, 97),
        ball: 21 - 5 * k,
        pupil: 9 - 2 * k,
        shine: 3,
        look: look,
      ),
      leftBrow: BrowShape(lerpPoints(leftLow, leftHigh, k)),
      rightBrow: BrowShape(lerpPoints(rightHigh, rightLow, k)),
      mouth: MouthShape(
        sampleMouth(
          (u) => Offset(
            80 + 42 * u,
            143 + 5 * math.sin(_tau * (1.5 * u + t)) + 8 * (u - 0.5) * sway,
          ),
        ),
      ),
    ),
    tilt: _deg(12) * sway,
    nudge: Offset(sway * 6, 0),
    fx: [
      for (var i = 0; i < 3; i++)
        () {
          final p = _frac(t + i / 3);
          const spots = [Offset(34, 0), Offset(166, -6), Offset(100, -26)];
          return RingFx(
            RingFxKind.question,
            at: spots[i] + Offset(0, -12 * p),
            scale: _elastic(_seg(p, 0, 0.3)) * (1 - _seg(p, 0.8, 1)),
            rotation: _deg(14) * math.sin(_tau * (t * 2 + i / 3)),
          );
        }(),
    ],
  );
}

RingingFrame _dizzy(double t) {
  final (lb, rb) = _worriedBrows(
    lift: -4 + 3 * _wave(t, 2),
    width: 10,
  );
  return RingingFrame(
    face: FaceShape(
      leftEye: _eye(const Offset(70, 94), pupil: 17, spiral: 1),
      rightEye: _eye(const Offset(130, 94), pupil: 17, spiral: 1),
      leftBrow: lb,
      rightBrow: rb,
      mouth: MouthShape(
        _wavyOpen(const Offset(100, 146), 50, 12, 3.5, t * 2, waves: 1.5),
        width: 9,
        fill: 1,
      ),
    ),
    spin: -_tau * t * 2,
    tilt: _deg(9) * _wave(t, 1, 0.25),
    nudge: Offset(math.cos(_tau * t) * 7, math.sin(_tau * t) * 4),
    fx: [
      for (var i = 0; i < 3; i++)
        () {
          final a = _tau * (t * 2 + i / 3);
          return RingFx(
            RingFxKind.star,
            at: Offset(100 + 76 * math.cos(a), 6 + 16 * math.sin(a)),
            scale: 0.75 + 0.25 * math.sin(a),
            rotation: a * 2,
            inFront: math.sin(a) > 0,
            onHead: true,
          );
        }(),
    ],
  );
}

RingingFrame _sobbing(double t) {
  final sob = math.pow(_pulse(t, 3), 2).toDouble();
  final (lb, rb) = _worriedBrows(lift: 3 * sob);
  return RingingFrame(
    face: FaceShape(
      leftEye: _eye(
        const Offset(70, 92),
        lid: 1,
        lidPoints: const [Offset(54, 90), Offset(70, 97), Offset(86, 88)],
      ),
      rightEye: _eye(
        const Offset(130, 92),
        lid: 1,
        lidPoints: const [Offset(114, 88), Offset(130, 97), Offset(146, 90)],
      ),
      leftBrow: lb,
      rightBrow: rb,
      mouth: _inkMouth(
        lipsMouth(
          (u) => quadAt(
            const Offset(68, 158),
            Offset(100, 166 + 4 * sob),
            const Offset(132, 158),
            u,
          ),
          (u) => quadAt(
            const Offset(68, 158),
            Offset(100, 124 - 8 * sob),
            const Offset(132, 158),
            u,
          ),
        ),
        width: 10,
      ),
      head: HeadShape(squashX: 1 + 0.03 * sob, squashY: 1 - 0.04 * sob),
    ),
    nudge: Offset(0, 4 * sob),
    fx: [
      for (final side in const [-1.0, 1.0])
        for (var i = 0; i < 4; i++)
          _flung(
            RingFxKind.tear,
            Offset(100 + side * 44, 92),
            Offset(side * 56, -34),
            130,
            _frac(t * 2 + i / 4 + (side > 0 ? 0.125 : 0)),
            scale: 0.8,
          ),
      for (final side in const [-1.0, 1.0])
        () {
          final p = _frac(t * 3 + (side > 0 ? 0.5 : 0));
          return RingFx(
            RingFxKind.tear,
            at: Offset(100 + side * 34, 104 + 42 * p),
            scale: 0.6,
            alpha: (1 - p) * _seg(p, 0, 0.1),
            onHead: true,
          );
        }(),
    ],
  );
}

RingingFrame _scream(double t) {
  final shriek = _pulse(t, 2);
  final tremble = Offset(_wave(t, 16) * 1.6, _wave(t, 13, 0.3) * 1.2);
  final (lb, rb) = _brows(
    const Offset(48, 56),
    const Offset(68, 44),
    const Offset(88, 52),
    by: Offset(0, -3 * shriek),
  );
  return RingingFrame(
    face: FaceShape(
      leftEye: _eye(
        const Offset(70, 88),
        ball: 22,
        pupil: 3.5,
        width: 9,
        look: tremble * 0.8,
      ),
      rightEye: _eye(
        const Offset(130, 88),
        ball: 22,
        pupil: 3.5,
        width: 9,
        look: tremble * 0.8,
      ),
      leftBrow: lb,
      rightBrow: rb,
      mouth: _inkMouth(
        ovalMouth(const Offset(100, 147), 16 + 2 * shriek, 28 + 6 * shriek),
        width: 10,
      ),
      head: HeadShape(
        squashX: 0.9,
        squashY: 1.1 + 0.03 * shriek,
        strokeWidth: 12,
      ),
    ),
    tilt: _deg(1.5) * _wave(t, 10),
    nudge: tremble,
    fx: [
      for (var i = 0; i < 2; i++)
        () {
          final p = _frac(t * 2 + i / 2);
          return RingFx(
            RingFxKind.pulseRing,
            scale: 1 + 0.45 * p,
            alpha: (1 - p) * _seg(p, 0, 0.15) * 0.6,
            inFront: false,
          );
        }(),
      RingFx(RingFxKind.soundWaves, phase: _frac(t * 3)),
      RingFx(
        RingFxKind.exclaim,
        at: const Offset(154, -12),
        scale: 0.8 + 0.2 * shriek,
        rotation: _deg(12),
      ),
      RingFx(
        RingFxKind.exclaim,
        at: const Offset(178, 2),
        scale: 0.7 + 0.2 * (1 - shriek),
        rotation: _deg(24),
      ),
    ],
  );
}

RingingFrame _bellHead(double t) {
  final swing = _wave(t, 2);
  final hit = math.pow(swing.abs(), 6).toDouble();
  final side = swing.sign;
  final open = ovalMouth(const Offset(100, 144), 16, 20);
  final grit = _gritMouth(const Offset(100, 144), 50, 16, bend: 4);
  final (lb, rb) = _alarmBrows(lift: -4 * hit);
  EyeShape wince(Offset c, {required bool struck}) => _eye(
    c,
    ball: 17,
    pupil: 6,
    hollow: true,
    width: 11,
    lid: hit * (struck ? 0.9 : 0.3),
    lidPoints: [c + const Offset(-14, 2), c, c + const Offset(14, 2)],
  );
  return RingingFrame(
    face: FaceShape(
      leftEye: wince(const Offset(70, 96), struck: side < 0),
      rightEye: wince(const Offset(130, 96), struck: side > 0),
      leftBrow: lb,
      rightBrow: rb,
      mouth: MouthShape.lerp(
        _inkMouth(open),
        _teethMouth(grit),
        hit,
      ),
      head: const HeadShape(strokeWidth: 12),
    ),
    tilt: -side * _deg(5) * hit,
    nudge: Offset(-side * 3 * hit, 3 * hit),
    fx: [
      RingFx(
        RingFxKind.bell,
        at: const Offset(56, 2),
        rotation: _deg(-28) + (side < 0 ? _deg(-10) * hit : 0),
        onHead: true,
        inFront: false,
      ),
      RingFx(
        RingFxKind.bell,
        at: const Offset(144, 2),
        rotation: _deg(28) + (side > 0 ? _deg(10) * hit : 0),
        onHead: true,
        inFront: false,
      ),
      RingFx(
        RingFxKind.hammer,
        at: const Offset(100, 14),
        rotation: _deg(45) * swing,
        onHead: true,
        inFront: false,
      ),
      _teeth(const Offset(100, 144), 50, 16, bend: 4).faded(hit),
      RingFx(
        RingFxKind.star,
        at: Offset(100 + side * 70, -26),
        scale: 0.9 * hit,
        alpha: hit,
        rotation: t * _tau,
      ),
      RingFx(
        RingFxKind.soundWaves,
        phase: _frac(t * 2),
        alpha: 0.4 + 0.6 * hit,
      ),
    ],
  );
}

RingingFrame _eyesPop(double t) {
  final pop = _elastic(_seg(t, 0.06, 0.4)) * (1 - _ease(_seg(t, 0.72, 0.94)));
  final brace = _bump(_seg(t, 0, 0.06));
  final (lb, rb) = _brows(
    const Offset(52, 70),
    const Offset(68, 64),
    const Offset(84, 68),
    by: Offset(0, -28 * pop + 4 * brace),
    alpha: 1 - 0.3 * pop.clamp(0, 1),
  );
  return RingingFrame(
    face: FaceShape(
      leftEye: _eye(
        Offset(70 - 8 * pop, 94 - 8 * pop),
        ball: 16 + 16 * pop,
        pupil: math.max(3, 9 - 5 * pop),
        shine: 3,
        width: 9,
      ),
      rightEye: _eye(
        Offset(130 + 8 * pop, 94 - 8 * pop),
        ball: 16 + 16 * pop,
        pupil: math.max(3, 9 - 5 * pop),
        shine: 3,
        width: 9,
      ),
      leftBrow: lb,
      rightBrow: rb,
      mouth: _inkMouth(
        ovalMouth(
          Offset(100, 142 + 20 * pop),
          12 + 7 * pop,
          math.max(4, 5 + 30 * pop),
        ),
        width: 10,
      ),
      head: HeadShape(
        squashX: 1 - 0.05 * pop - 0.03 * brace,
        squashY: 1 + 0.12 * pop - 0.05 * brace,
      ),
      props: [
        PropShape(
          PropKind.popLines,
          at: const Offset(100, 100),
          scale: pop.clamp(0, 1.2),
          alpha: pop.clamp(0, 1),
        ),
      ],
    ),
    tilt: _deg(3) * _wave(t, 6) * pop,
    fx: [
      RingFx(
        RingFxKind.exclaim,
        at: const Offset(100, -34),
        scale: pop.clamp(0, 1.3),
        alpha: pop.clamp(0, 1),
      ),
    ],
  );
}

RingingFrame _annoyed(double t) {
  final env = _bump(_seg(t, 0.08, 0.62));
  final a = math.pi + math.pi * _ease(_seg(t, 0.12, 0.56));
  final look = Offset(math.cos(a), math.sin(a)) * 9 * env;
  final sigh = _bump(_seg(t, 0.6, 0.94));
  final (lb, rb) = _brows(
    const Offset(52, 82),
    const Offset(70, 81),
    const Offset(88, 83),
    width: 12,
  );
  return RingingFrame(
    face: FaceShape(
      leftEye: _eye(
        const Offset(70, 98),
        ball: 17,
        squash: 0.55,
        pupil: 8,
        look: look,
      ),
      rightEye: _eye(
        const Offset(130, 98),
        ball: 17,
        squash: 0.55,
        pupil: 8,
        look: look,
      ),
      leftBrow: lb,
      rightBrow: BrowShape.lerp(
        rb,
        _brow(
          const Offset(112, 70),
          const Offset(130, 62),
          const Offset(148, 68),
          width: 12,
        ),
        env,
      ),
      mouth: MouthShape.lerp(
        MouthShape(lineMouth(const Offset(84, 142), const Offset(118, 138))),
        _inkMouth(ovalMouth(const Offset(110, 142), 7, 6), width: 9),
        sigh,
      ),
      head: HeadShape(squashY: 1 - 0.04 * sigh, squashX: 1 + 0.02 * sigh),
      props: [
        PropShape(
          PropKind.puff,
          at: Offset(144 + 22 * _seg(t, 0.6, 0.94), 150),
          scale: sigh * 1.2,
          alpha: sigh,
        ),
      ],
    ),
    tilt: -_deg(7) * env,
    nudge: Offset(0, -2 * env + 3 * sigh),
    fx: [
      RingFx(
        RingFxKind.soundWaves,
        phase: _frac(t * 3),
        alpha: 0.45,
      ),
    ],
  );
}

RingingFrame _startled(double t) {
  final awake = _ease(_seg(t, 0.4, 0.45)) * (1 - _ease(_seg(t, 0.8, 0.98)));
  final air = _seg(t, 0.42, 0.72);
  final height = 4 * air * (1 - air);
  final land = _bump(_seg(t, 0.72, 0.8));
  final breathe = _wave(t, 2) * (1 - awake);
  final squashY = 1 - 0.12 * land + 0.06 * height + 0.015 * breathe;
  final blended = FaceShape.lerp(dozingFace, shockedFace, awake);
  final zzz = PropShape(
    PropKind.zzz,
    at: Offset(150 + 4 * _wave(t, 2), 34 - 6 * _pulse(t, 2)),
    alpha: 1 - awake,
    scale: (1 - awake) * (0.9 + 0.1 * _pulse(t, 2)),
  );
  return RingingFrame(
    face: _with(
      blended,
      head: HeadShape(
        squashX: 1 + 0.1 * land - 0.03 * height,
        squashY: squashY,
        strokeWidth: 10 + 2 * awake,
      ),
      props: [zzz],
    ),
    tilt: _deg(4) * _wave(t, 20) * height + 0.06 * (1 - awake),
    nudge: Offset(0, -48 * height + 88 * (1 - squashY)),
    fx: [
      RingFx(
        RingFxKind.exclaim,
        at: const Offset(100, -30),
        scale: _elastic(_seg(t, 0.44, 0.56)) * 1.1 * (1 - _seg(t, 0.72, 0.8)),
        alpha: _seg(t, 0.44, 0.46) * (1 - _seg(t, 0.72, 0.8)),
        onHead: true,
      ),
      RingFx(
        RingFxKind.speedLines,
        at: Offset(100, 214 - 48 * height),
        alpha: _seg(t, 0.43, 0.47) * (1 - _seg(t, 0.52, 0.57)),
      ),
      RingFx(
        RingFxKind.soundWaves,
        phase: _frac(t * 4),
        alpha: awake,
      ),
      for (final side in const [-1.0, 1.0])
        RingFx(
          RingFxKind.steam,
          at: Offset(100 + side * (70 + 26 * land), 188),
          scale: 0.4 + 0.4 * land,
          alpha: land,
        ),
    ],
  );
}

RingingFrame _hyperventilating(double t) {
  final breath = _pulse(t, 3);
  final out = 1 - breath;
  final (lb, rb) = _worriedBrows(lift: 3 * breath);
  final look = Offset(_wave(t, 9) * 1.5, 0);
  return RingingFrame(
    face: FaceShape(
      leftEye: _eye(
        const Offset(70, 94),
        ball: 20,
        pupil: 6,
        shine: 2.5,
        look: look,
      ),
      rightEye: _eye(
        const Offset(130, 94),
        ball: 20,
        pupil: 6,
        shine: 2.5,
        look: look,
      ),
      leftBrow: lb,
      rightBrow: rb,
      mouth: MouthShape.lerp(
        _inkMouth(ovalMouth(const Offset(106, 146), 5, 4), width: 9),
        _inkMouth(ovalMouth(const Offset(100, 146), 10, 12), width: 9),
        breath,
      ),
      head: HeadShape(squashX: 1 + 0.07 * out, squashY: 1 + 0.03 * breath),
      props: [
        PropShape(
          PropKind.puff,
          at: Offset(142 + 16 * out, 152),
          scale: out,
          alpha: out * out,
        ),
      ],
    ),
    nudge: Offset(0, -2.5 * breath),
    fx: [
      const RingFx(RingFxKind.blush, alpha: 0.55, onHead: true),
      for (var i = 0; i < 2; i++)
        () {
          final p = _frac(t * 2 + i / 2);
          return RingFx(
            RingFxKind.sweat,
            at: Offset(i == 0 ? 156 : 44, 46 + 34 * p),
            scale: 0.75,
            alpha: (1 - p) * _seg(p, 0, 0.1),
            onHead: true,
          );
        }(),
    ],
  );
}

RingingFrame _zapped(double t) {
  final zap = _seg(t, 0, 0.04) * (1 - _seg(t, 0.52, 0.6));
  final flicker = _wave(t, 18) > 0 ? 1.0 : 0.0;
  final jolt = Offset(_wave(t, 23) * 3, _wave(t, 19, 0.3) * 3) * zap;
  const mouthAt = Offset(100, 146);

  final shocked = FaceShape(
    leftEye: _eye(
      const Offset(68, 94),
      ball: 22,
      pupil: 3,
      width: 9,
      look: jolt * 0.6,
    ),
    rightEye: _eye(
      const Offset(132, 94),
      ball: 22,
      pupil: 3,
      width: 9,
      look: jolt * 0.6,
    ),
    leftBrow: _brow(
      const Offset(46, 58),
      const Offset(66, 46),
      const Offset(88, 56),
    ),
    rightBrow: _brow(
      const Offset(112, 56),
      const Offset(134, 46),
      const Offset(154, 58),
    ),
    mouth: _teethMouth(_gritMouth(mouthAt, 66, 22, bend: -5)),
    head: const HeadShape(strokeWidth: 13),
  );
  final dazed = FaceShape(
    leftEye: _eye(
      const Offset(70, 96),
      ball: 15,
      squash: 0.6,
      pupil: 7,
      look: const Offset(5, 1),
    ),
    rightEye: _eye(
      const Offset(130, 96),
      ball: 15,
      squash: 0.6,
      pupil: 7,
      look: const Offset(-5, -1),
    ),
    leftBrow: _brow(
      const Offset(54, 78),
      const Offset(70, 76),
      const Offset(86, 78),
    ),
    rightBrow: _brow(
      const Offset(114, 78),
      const Offset(130, 76),
      const Offset(146, 78),
    ),
    mouth: MouthShape(_wavyLine(const Offset(100, 144), 44, 4, t * 2)),
  );
  const bolts = [
    (Offset(14, 30), -0.5),
    (Offset(186, 24), 0.6),
    (Offset(4, 150), -2.2),
    (Offset(196, 146), 2.4),
    (Offset(100, -22), 0.1),
  ];
  return RingingFrame(
    face: FaceShape.lerp(dazed, shocked, zap),
    nudge: jolt,
    tilt: _deg(3) * _wave(t, 13) * zap,
    flash: 0.9 * flicker * zap,
    fx: [
      _teeth(mouthAt, 66, 22, bend: -5).faded(zap),
      for (var i = 0; i < bolts.length; i++)
        RingFx(
          RingFxKind.bolt,
          at: bolts[i].$1,
          rotation: bolts[i].$2,
          scale: 0.9 + 0.2 * _pulse(t, 7, i / 5),
          alpha: zap * (_wave(t, 12, i / 5) > -0.2 ? 1 : 0),
        ),
      for (var i = 0; i < 3; i++)
        () {
          final p = _frac(t * 2 + i / 3);
          return RingFx(
            RingFxKind.steam,
            at: Offset(70 + i * 30 + 10 * math.sin(_tau * p), 8 - 40 * p),
            scale: 0.5 + 0.7 * p,
            alpha: (1 - zap) * (1 - p) * _seg(p, 0, 0.15) * 0.9,
          );
        }(),
    ],
  );
}

RingingFrame _bouncing(double t) {
  final height = 4 * t * (1 - t);
  final ground = math.min(t, 1 - t);
  final land = math.pow(1 - (ground / 0.12).clamp(0, 1), 2).toDouble();
  final squashY = 1 + 0.06 * height * (1 - land) - 0.16 * land;
  final squashX = 1 - 0.04 * height + 0.14 * land;
  final (lb, rb) = _alarmBrows(lift: 8 * height);
  // Looking up on the way up and at the floor on the way down.
  final look = Offset(0, -4 * _wave(t, 1, 0.25));
  return RingingFrame(
    face: FaceShape(
      leftEye: _eye(
        const Offset(70, 94),
        ball: 17,
        pupil: 6,
        hollow: true,
        width: 11,
        look: look,
      ),
      rightEye: _eye(
        const Offset(130, 94),
        ball: 17,
        pupil: 6,
        hollow: true,
        width: 11,
        look: look,
      ),
      leftBrow: lb,
      rightBrow: rb,
      mouth: _inkMouth(
        ovalMouth(const Offset(100, 144), 13 + 5 * height, 6 + 16 * height),
      ),
      head: HeadShape(squashX: squashX, squashY: squashY, strokeWidth: 12),
    ),
    nudge: Offset(0, -40 * height + 88 * (1 - squashY)),
    tilt: _deg(4) * _wave(t, 1),
    fx: [
      RingFx(
        RingFxKind.speedLines,
        at: Offset(100, 212 - 40 * height),
        alpha: _seg(t, 0.06, 0.14) * (1 - _seg(t, 0.3, 0.45)),
      ),
      for (final side in const [-1.0, 1.0])
        RingFx(
          RingFxKind.steam,
          at: Offset(100 + side * (78 + 16 * land), 186),
          scale: 0.35 + 0.35 * land,
          alpha: land,
        ),
      const RingFx(RingFxKind.soundWaves, alpha: 0.7),
    ],
  );
}

RingingFrame _terrified(double t) {
  final tremble = Offset(_wave(t, 15) * 2.4, _wave(t, 17, 0.2) * 1.4);
  final chatter = _pulse(t, 10);
  final look = Offset(_snap(_wave(t, 2), 3) * 7, -5) + tremble * 0.5;
  final (lb, rb) = _brows(
    const Offset(46, 78),
    const Offset(63, 64),
    const Offset(84, 54),
    width: 10,
  );
  final mouthH = 6 + 9 * chatter;
  const mouthAt = Offset(100, 147);
  return RingingFrame(
    face: FaceShape(
      leftEye: _eye(
        const Offset(68, 96),
        ball: 20,
        pupil: 7,
        shine: 3,
        look: look,
      ),
      rightEye: _eye(
        const Offset(132, 96),
        ball: 20,
        pupil: 7,
        shine: 3,
        look: look,
      ),
      leftBrow: lb,
      rightBrow: rb,
      mouth: _teethMouth(_gritMouth(mouthAt, 50, mouthH, bend: 4)),
    ),
    scale: 0.86,
    nudge: tremble + const Offset(0, 8),
    tilt: _deg(2) * _wave(t, 11),
    fx: [
      _teeth(mouthAt, 50, mouthH, bend: 4),
      for (var i = 0; i < 2; i++)
        () {
          final p = _frac(t + i / 2);
          return RingFx(
            RingFxKind.sweat,
            at: Offset(i == 0 ? 40 : 160, 54 + 30 * p),
            scale: 0.8,
            alpha: (1 - p) * _seg(p, 0, 0.1),
            onHead: true,
          );
        }(),
    ],
  );
}

RingingFrame _siren(double t) {
  final wee = _pulse(t, 2);
  final (lb, rb) = _brows(
    const Offset(52, 62),
    const Offset(68, 56),
    const Offset(86, 60),
    by: Offset(0, -7 * wee),
  );
  final look = Offset(0, -3 * wee);
  return RingingFrame(
    face: FaceShape(
      leftEye: _eye(
        const Offset(70, 96),
        ball: 17,
        pupil: 6,
        hollow: true,
        width: 11,
        look: look,
      ),
      rightEye: _eye(
        const Offset(130, 96),
        ball: 17,
        pupil: 6,
        hollow: true,
        width: 11,
        look: look,
      ),
      leftBrow: lb,
      rightBrow: rb,
      mouth: MouthShape.lerp(
        _inkMouth(ovalMouth(const Offset(100, 146), 11, 17)),
        _inkMouth(ovalMouth(const Offset(100, 143), 27, 9)),
        wee,
      ),
      head: const HeadShape(strokeWidth: 12),
    ),
    scale: 1 + 0.04 * wee,
    flush: 0.35 * wee,
    fx: [
      RingFx(
        RingFxKind.pulseRing,
        scale: 1.05 + 0.25 * wee,
        alpha: 0.5 * wee,
        inFront: false,
      ),
      RingFx(
        RingFxKind.siren,
        at: const Offset(100, 4),
        phase: _frac(t * 2),
        onHead: true,
        inFront: false,
      ),
      RingFx(RingFxKind.soundWaves, phase: _frac(t * 2)),
    ],
  );
}

RingingFrame _meltdown(double t) {
  final down = _ease(_seg(t, 0.05, 0.6));
  final back = _elastic(_seg(t, 0.76, 1));
  final m = down * (1 - back);
  final squashY = 1 - 0.3 * m;
  final squashX = 1 + 0.2 * m;
  final (lb, rb) = _brows(
    const Offset(52, 66),
    const Offset(68, 62),
    const Offset(86, 60),
    by: Offset(0, 12 * m),
  );
  final drips = <RingFx>[];
  const dripXs = [48.0, 86.0, 124.0, 158.0];
  for (var i = 0; i < dripXs.length; i++) {
    final p = _frac(t * 2 + i * 0.27);
    drips.add(
      RingFx(
        RingFxKind.drip,
        at: Offset(100 + (dripXs[i] - 100) * squashX, 184 + 34 * p * p),
        scale: 0.7 + 0.4 * m,
        alpha: _seg(m, 0.15, 0.5) * (1 - p),
      ),
    );
  }
  return RingingFrame(
    face: FaceShape(
      leftEye: _eye(
        Offset(66 - 6 * m, 94 + 10 * m),
        ball: 17,
        squash: 1 - 0.4 * m,
        pupil: 7,
        shine: 2.5,
        look: Offset(0, 5 * m),
      ),
      rightEye: _eye(
        Offset(134 + 6 * m, 94 + 10 * m),
        ball: 17,
        squash: 1 - 0.4 * m,
        pupil: 7,
        shine: 2.5,
        look: Offset(0, 5 * m),
      ),
      leftBrow: lb,
      rightBrow: rb,
      mouth: MouthShape(
        _wavyLine(
          Offset(100, 144 + 8 * m),
          48 + 12 * m,
          3 * m,
          t * 4,
          waves: 2,
          frown: 8,
        ),
      ),
      head: HeadShape(squashX: squashX, squashY: squashY),
    ),
    nudge: Offset(0, 88 * (1 - squashY)),
    tilt: _deg(2) * _wave(t, 6) * m,
    flush: 0.5 * m.clamp(0, 1),
    fx: [
      ...drips,
      RingFx(
        RingFxKind.sweat,
        at: Offset(150, 44 + 20 * _frac(t * 2)),
        scale: 0.8,
        alpha: m.clamp(0, 1) * (1 - _frac(t * 2)),
        onHead: true,
      ),
    ],
  );
}

RingingFrame _spinOut(double t) {
  final spinP = _ease(_seg(t, 0, 0.45));
  final w = _seg(t, 0.45, 1);
  final wobble = math.sin(_tau * 3 * w) * (1 - w);
  final swirl = _seg(t, 0, 0.1) * (1 - _seg(t, 0.72, 0.95));
  final (lb, rb) = _alarmBrows(lift: -2 * swirl);
  EyeShape eye(Offset c) => _eye(
    c,
    ball: 17,
    pupil: 6 + 10 * swirl,
    hollow: true,
    width: 11,
    spiral: swirl,
  );
  final stars = _seg(t, 0.4, 0.5) * (1 - _seg(t, 0.85, 1));
  return RingingFrame(
    face: FaceShape(
      leftEye: eye(const Offset(70, 94)),
      rightEye: eye(const Offset(130, 94)),
      leftBrow: lb,
      rightBrow: rb,
      mouth: _inkMouth(
        _wavyOpen(const Offset(100, 145), 34, 10 + 10 * swirl, 2, t * 3),
        width: 10,
      ),
      head: const HeadShape(strokeWidth: 12),
    ),
    spin: _tau * t * 3,
    tilt: _tau * spinP + _deg(14) * wobble,
    nudge: Offset(6 * wobble, 0),
    fx: [
      RingFx(
        RingFxKind.speedLines,
        at: const Offset(-6, 100),
        rotation: math.pi / 2,
        alpha: _bump(_seg(t, 0.05, 0.42)),
      ),
      RingFx(
        RingFxKind.speedLines,
        at: const Offset(206, 100),
        rotation: -math.pi / 2,
        alpha: _bump(_seg(t, 0.05, 0.42)),
      ),
      for (var i = 0; i < 3; i++)
        () {
          final a = _tau * (t * 2 + i / 3);
          return RingFx(
            RingFxKind.star,
            at: Offset(100 + 70 * math.cos(a), 4 + 14 * math.sin(a)),
            scale: (0.7 + 0.2 * math.sin(a)) * stars,
            alpha: stars,
            rotation: a,
            inFront: math.sin(a) > 0,
          );
        }(),
    ],
  );
}

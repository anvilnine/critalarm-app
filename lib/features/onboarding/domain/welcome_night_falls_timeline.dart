import 'dart:math' as math;

import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/features/onboarding/domain/welcome_timeline_math.dart';
import 'package:flutter/animation.dart';

// A first welcome page: the day ends, the sun sets, the face sleeps in the
// dark, and at 03:12 the alarm rings. A red burst grows from the middle, the
// face wakes shouting, and the day comes back.
//
// Everything here is a pure function of the clock. The widget only paints the
// frame. Positions are fractions of the picture, so the widget can scale them
// to the room it has.

/// How long one pass of the story takes, in seconds. It starts over after.
const double welcomeNightFallsLoopSeconds = 10;

/// The loop fractions the story turns on. Every table below reads them.
///
/// Day until [welcomeNightFallsDuskFrom]. The sun sets and the sky darkens
/// until [welcomeNightFallsNightAt]. The face has gone to sleep by
/// [welcomeNightFallsSleepsBy]. The burst starts at
/// [welcomeNightFallsBurstFrom], the face shouts from
/// [welcomeNightFallsShoutsFrom] and the burst is full at
/// [welcomeNightFallsBurstFullAt]. The ringing ends from
/// [welcomeNightFallsRingingEndsFrom], the face is awake and calm again by
/// [welcomeNightFallsAwakeBy] and the burst is gone at
/// [welcomeNightFallsBurstGoneAt].
const double welcomeNightFallsDuskFrom = 0.14;
const double welcomeNightFallsNightAt = 0.28;
const double welcomeNightFallsSleepsFrom = 0.22;
const double welcomeNightFallsSleepsBy = 0.26;
const double welcomeNightFallsBurstFrom = 0.54;
const double welcomeNightFallsShoutsFrom = 0.55;
const double welcomeNightFallsShoutsBy = 0.57;
const double welcomeNightFallsBurstFullAt = 0.62;
const double welcomeNightFallsRingingEndsFrom = 0.84;
const double welcomeNightFallsRingingEndsBy = 0.90;
const double welcomeNightFallsAwakeFrom = 0.88;
const double welcomeNightFallsAwakeBy = 0.92;
const double welcomeNightFallsBurstGoneAt = 0.94;

/// The loop fractions the small clock changes its text at: the evening, the
/// silent night and the ringing.
const double welcomeNightFallsEveningAt = 0.18;
const double welcomeNightFallsSilentAt = 0.30;
const double welcomeNightFallsRingingAt = 0.56;
const double welcomeNightFallsNextDayAt = 0.90;

/// The ink turns light as the sky darkens, from the first to the second, and
/// dark again from the third to the fourth.
const double welcomeNightFallsInkLightFrom = 0.18;
const double welcomeNightFallsInkLightBy = 0.28;
const double welcomeNightFallsInkDarkFrom = 0.54;
const double welcomeNightFallsInkDarkBy = 0.58;

/// When the burst lands, on the story's clock. The one haptic plays here.
const double welcomeNightFallsBurstLandsAt =
    welcomeNightFallsShoutsBy * welcomeNightFallsLoopSeconds;

/// How far the sun falls while it sets, in sun widths.
const double welcomeNightFallsSunFall = 0.8;

/// The face pops to this scale as the alarm rings, then shakes this many
/// degrees to each side.
const double welcomeNightFallsFacePop = 1.18;
const double welcomeNightFallsFaceShakeDegrees = 3;

/// How many rings pulse out from behind the face while it rings.
const int welcomeNightFallsRingCount = 3;

/// How long one ring takes to grow and fade, and how much later each starts
/// than the one before it.
const double welcomeNightFallsRingSeconds = 1.4;
const double welcomeNightFallsRingStaggerSeconds = 0.45;

/// How long one twinkle of a star takes, and how much later each star
/// starts than the one before it, in seconds.
const double welcomeNightFallsTwinkleSeconds = 2;
const List<double> welcomeNightFallsStarDelays = [0, 0.6, 1.1, 1.5];

/// Where the stars sit, as fractions of the picture's width and height.
const List<(double, double)> welcomeNightFallsStarPlaces = [
  (0.12, 0.40),
  (0.86, 0.44),
  (0.70, 0.88),
  (0.10, 0.80),
];

/// How far the burst reaches in the settled frame: a share of the way to the
/// farthest corner of the picture. The loop's burst covers all of it.
const double welcomeNightFallsSettledReach = 0.4;

/// The type size of the title at its full width, in points.
const double welcomeNightFallsMaxTitleSize = 46;

/// The type size of the title for a picture whose text column is
/// [textWidth] points wide: a fixed share of it, so "Welcome to" fits on one
/// line down to a 320 point wide phone, and 46 at most. It never goes below
/// [welcomeNightFallsMinTitleSize].
double welcomeNightFallsTitleSize(double textWidth) => math.max(
  welcomeNightFallsMinTitleSize,
  math.min(welcomeNightFallsMaxTitleSize, textWidth * 0.17),
);

const double welcomeNightFallsMinTitleSize = 24;

/// What the small clock in the corner reads.
enum WelcomeNightClock {
  /// 17:40, the day.
  day,

  /// 22:05, the sun is down.
  evening,

  /// 03:12, silent.
  silent,

  /// 03:12, ringing.
  ringing,
}

/// One ring behind the face.
class WelcomeNightFallsRing {
  const WelcomeNightFallsRing({required this.scale, required this.opacity});

  /// 1 is the size of the ring at rest.
  final double scale;
  final double opacity;
}

/// Everything in the picture at one moment.
class WelcomeNightFallsFrame {
  const WelcomeNightFallsFrame({
    required this.nightOpacity,
    required this.sunFall,
    required this.sunOpacity,
    required this.ink,
    required this.burstReach,
    required this.burstOpacity,
    required this.rings,
    required this.starOpacities,
    required this.dayFaceOpacity,
    required this.sleepFaceOpacity,
    required this.shoutFaceOpacity,
    required this.faceScale,
    required this.faceTurn,
    required this.clock,
  });

  /// How much of the night sky covers the day, 0 to 1.
  final double nightOpacity;

  /// How far the sun has fallen, 0 (up) to 1 (all the way, in sun widths
  /// times [welcomeNightFallsSunFall]).
  final double sunFall;
  final double sunOpacity;

  /// 0 is the dark ink of the day and 1 the light ink of the night.
  final double ink;

  /// How far the red burst has grown, 0 to 1 of the way to the farthest
  /// corner of the picture.
  final double burstReach;
  final double burstOpacity;

  /// The rings, oldest first.
  final List<WelcomeNightFallsRing> rings;

  /// How bright each star is, 0 to 1. They only show against the night.
  final List<double> starOpacities;

  /// The three faces stack and cross-fade: the one that smiles in the day,
  /// the sleeping one and the one that shouts.
  final double dayFaceOpacity;
  final double sleepFaceOpacity;
  final double shoutFaceOpacity;

  /// 1 is the face's own size.
  final double faceScale;

  /// Clockwise is positive, in radians.
  final double faceTurn;

  final WelcomeNightClock clock;
}

/// The picture under reduced motion, which is the same at every time: the
/// night is down, the clock reads 03:12 ringing, and the face is awake and
/// shouting inside a red burst. Nothing moves, so the burst stops short of
/// the edges and the night and the stars still show around it.
const WelcomeNightFallsFrame _settled = WelcomeNightFallsFrame(
  nightOpacity: 1,
  sunFall: 1,
  sunOpacity: 0,
  ink: 1,
  burstReach: welcomeNightFallsSettledReach,
  burstOpacity: 1,
  rings: [
    WelcomeNightFallsRing(scale: 1, opacity: 0),
    WelcomeNightFallsRing(scale: 1, opacity: 0),
    WelcomeNightFallsRing(scale: 1, opacity: 0),
  ],
  starOpacities: [0.8, 0.8, 0.8, 0.8],
  dayFaceOpacity: 0,
  sleepFaceOpacity: 0,
  shoutFaceOpacity: 1,
  faceScale: 1,
  faceTurn: 0,
  clock: WelcomeNightClock.ringing,
);

/// The settled frame, for tests and for a held picture.
const WelcomeNightFallsFrame welcomeNightFallsSettled = _settled;

/// How hot the page is, 0 to 1: the rings and the shouting face are here
/// while the burst is up.
double _heatAt(double p) => welcomeThrough(p, const [
  (0, 0),
  (welcomeNightFallsShoutsFrom, 0),
  (welcomeNightFallsShoutsBy, 1),
  (welcomeNightFallsRingingEndsFrom, 1),
  (welcomeNightFallsRingingEndsBy, 0),
  (1, 0),
]);

/// The sky going dark and the sun setting share one table.
double _duskAt(double p) => welcomeThrough(
  p,
  const [
    (0, 0),
    (welcomeNightFallsDuskFrom, 0),
    (welcomeNightFallsNightAt, 1),
    (welcomeNightFallsBurstFrom, 1),
    (welcomeNightFallsInkDarkBy, 0),
    (1, 0),
  ],
  curve: Curves.easeInOut,
);

WelcomeNightClock _clockAt(double p) {
  if (p < welcomeNightFallsEveningAt) return WelcomeNightClock.day;
  if (p < welcomeNightFallsSilentAt) return WelcomeNightClock.evening;
  if (p < welcomeNightFallsRingingAt) return WelcomeNightClock.silent;
  if (p < welcomeNightFallsNextDayAt) return WelcomeNightClock.ringing;
  return WelcomeNightClock.day;
}

/// The face's scale and turn: it pops as the alarm rings and then shakes
/// from side to side. The two share a list of stops. Each stop is a loop
/// fraction, the scale and the turn in degrees.
const List<(double, double, double)> _faceStops = [
  (0.55, 1, 0),
  (0.59, welcomeNightFallsFacePop, 0),
  (0.63, 1, -welcomeNightFallsFaceShakeDegrees),
  (0.67, 1, welcomeNightFallsFaceShakeDegrees),
  (0.71, 1, -welcomeNightFallsFaceShakeDegrees),
  (0.75, 1, welcomeNightFallsFaceShakeDegrees),
  (0.79, 1, -welcomeNightFallsFaceShakeDegrees),
  (0.83, 1, welcomeNightFallsFaceShakeDegrees),
  (0.90, 1, 0),
];

/// How far ring [index] has grown at [loopTime] seconds, 0 to 1. The first
/// ring starts when the face starts to shout.
double _ringProgress(double loopTime, int index) {
  final start =
      welcomeNightFallsShoutsFrom * welcomeNightFallsLoopSeconds +
      index * welcomeNightFallsRingStaggerSeconds;
  if (loopTime < start) return 0;
  return ((loopTime - start) % welcomeNightFallsRingSeconds) /
      welcomeNightFallsRingSeconds;
}

/// How bright star [index] is at [loopTime] seconds: it brightens and dims
/// once every [welcomeNightFallsTwinkleSeconds].
double _starAt(double loopTime, int index) {
  final local =
      ((loopTime - welcomeNightFallsStarDelays[index]) %
          welcomeNightFallsTwinkleSeconds) /
      welcomeNightFallsTwinkleSeconds;
  final half = local < 0.5 ? local * 2 : (1 - local) * 2;
  return 0.3 + 0.7 * Curves.easeInOut.transform(half);
}

/// Where everything is [seconds] into the story.
///
/// With [reducedMotion] it is the settled picture at every time.
WelcomeNightFallsFrame welcomeNightFallsFrameAt(
  double seconds, {
  required bool reducedMotion,
}) {
  if (reducedMotion) return _settled;
  final loopTime = math.max<double>(0, seconds) % welcomeNightFallsLoopSeconds;
  final p = loopTime / welcomeNightFallsLoopSeconds;

  final dusk = _duskAt(p);
  final heat = _heatAt(p);

  // The face: one table for the scale and one for the turn.
  final scale = welcomeThrough(p, [
    for (final (at, s, _) in _faceStops) (at, s),
  ], curve: AppCurves.easeBack);
  final turn = welcomeThrough(p, [
    for (final (at, _, t) in _faceStops) (at, t),
  ], curve: AppCurves.easeBack);

  return WelcomeNightFallsFrame(
    nightOpacity: dusk,
    sunFall: dusk,
    sunOpacity: 1 - dusk,
    ink: welcomeThrough(p, const [
      (0, 0),
      (welcomeNightFallsInkLightFrom, 0),
      (welcomeNightFallsInkLightBy, 1),
      (welcomeNightFallsInkDarkFrom, 1),
      (welcomeNightFallsInkDarkBy, 0),
      (1, 0),
    ]),
    burstReach: welcomeThrough(
      p,
      const [
        (0, 0),
        (welcomeNightFallsBurstFrom, 0),
        (welcomeNightFallsBurstFullAt, 1),
        (1, 1),
      ],
      curve: const Cubic(0.2, 0.8, 0.2, 1),
    ),
    burstOpacity: welcomeThrough(
      p,
      const [
        (0, 1),
        (welcomeNightFallsRingingEndsFrom, 1),
        (welcomeNightFallsBurstGoneAt, 0),
        (1, 0),
      ],
      curve: const Cubic(0.2, 0.8, 0.2, 1),
    ),
    rings: [
      for (var i = 0; i < welcomeNightFallsRingCount; i++)
        () {
          final eased = Curves.easeOut.transform(_ringProgress(loopTime, i));
          return WelcomeNightFallsRing(
            scale: 0.9 + (2.2 - 0.9) * eased,
            opacity: 0.5 * (1 - eased) * heat,
          );
        }(),
    ],
    starOpacities: [
      for (var i = 0; i < welcomeNightFallsStarDelays.length; i++)
        _starAt(loopTime, i),
    ],
    dayFaceOpacity: welcomeThrough(p, const [
      (0, 1),
      (welcomeNightFallsSleepsFrom, 1),
      (welcomeNightFallsSleepsBy, 0),
      (welcomeNightFallsAwakeFrom, 0),
      (welcomeNightFallsAwakeBy, 1),
      (1, 1),
    ]),
    sleepFaceOpacity: welcomeThrough(p, const [
      (0, 0),
      (welcomeNightFallsSleepsFrom, 0),
      (welcomeNightFallsSleepsBy, 1),
      (welcomeNightFallsShoutsFrom, 1),
      (welcomeNightFallsShoutsBy, 0),
      (1, 0),
    ]),
    shoutFaceOpacity: heat,
    faceScale: scale,
    faceTurn: turn * math.pi / 180,
    clock: _clockAt(p),
  );
}

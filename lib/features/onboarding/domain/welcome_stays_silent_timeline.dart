import 'dart:math' as math;

import 'package:critalarm/design/tokens/curves.dart';
import 'package:critalarm/features/onboarding/domain/welcome_timeline_math.dart';
import 'package:flutter/animation.dart';

// A first welcome page: it is 3:12 at night and the phone is silent. Three
// ordinary notifications queue up muted. Then one alarm slams in, the others
// are pushed aside and dimmed, and the alarm is the only thing that rings.
//
// Everything here is a pure function of the clock. The widget only paints the
// frame. Lengths are in "design units": points at the size the picture is
// drawn for, [welcomeStaysSilentDesignWidth] by
// [welcomeStaysSilentDesignHeight]. The widget scales them to the room it has.

/// How long one pass of the story takes, in seconds. It starts over after.
const double welcomeStaysSilentLoopSeconds = 8;

/// The size the picture is drawn for, in design units.
const double welcomeStaysSilentDesignWidth = 350;
const double welcomeStaysSilentDesignHeight = 432;

/// How many muted notifications queue up.
const int welcomeStaysSilentRowCount = 3;

/// The loop fractions each muted row starts to slide in at, and is in place
/// by. Row 0 is the top one.
const List<double> welcomeStaysSilentRowFrom = [0.04, 0.16, 0.28];
const List<double> welcomeStaysSilentRowBy = [0.10, 0.22, 0.34];

/// The loop fraction the rows are still until. They then give way to the
/// alarm, and are done giving way at [welcomeStaysSilentRowsAsideBy].
const double welcomeStaysSilentRowsHoldUntil = 0.50;
const double welcomeStaysSilentRowsAsideBy = 0.56;

/// The loop fraction the rows fade out at before the story starts over, so
/// the next pass begins from an empty queue.
const double welcomeStaysSilentRowsLeaveFrom = 0.94;

/// How far a row starts above its place, in design units.
const double welcomeStaysSilentRowDrop = 30;

/// Where each row ends up while the alarm rings: how far it has moved
/// (negative is up), in design units. The first row goes up out of the
/// alarm's way and the others go down behind it.
const List<double> welcomeStaysSilentRowAside = [-70, 90, 100];

/// The scale and the opacity a row has once it has given way.
const double welcomeStaysSilentRowAsideScale = 0.92;
const double welcomeStaysSilentRowAsideOpacity = 0.35;

/// The alarm card: it is unseen until [welcomeStaysSilentAlarmFrom], is in
/// by [welcomeStaysSilentAlarmBy], holds, and leaves from
/// [welcomeStaysSilentAlarmLeavesFrom] to the end of the loop. It starts and
/// ends at [welcomeStaysSilentAlarmFromScale].
const double welcomeStaysSilentAlarmFrom = 0.50;
const double welcomeStaysSilentAlarmBy = 0.58;
const double welcomeStaysSilentAlarmLeavesFrom = 0.94;
const double welcomeStaysSilentAlarmFromScale = 0.2;

/// The picture shakes sideways while the alarm lands: the loop fractions
/// it moves at and how far, in design units.
const List<(double, double)> welcomeStaysSilentJolt = [
  (0, 0),
  (0.52, 0),
  (0.54, -7),
  (0.56, 7),
  (0.58, -4),
  (0.60, 4),
  (0.62, 0),
  (1, 0),
];

/// How long the ring around the alarm card takes to spread and fade, and how
/// far it spreads, in design units.
const double welcomeStaysSilentGlowSeconds = 1.2;
const double welcomeStaysSilentGlowSpread = 26;
const double welcomeStaysSilentGlowOpacity = 0.7;

/// How long the face on the card takes to turn from one side to the other
/// and back, and how far it turns each way, in degrees.
const double welcomeStaysSilentShiverSeconds = 0.45;
const double welcomeStaysSilentShiverDegrees = 3;

/// When the alarm lands, on the story's clock. The one haptic plays here.
const double welcomeStaysSilentAlarmLandsAt =
    welcomeStaysSilentAlarmBy * welcomeStaysSilentLoopSeconds;

/// The height the picture is drawn for when the room is too short for the
/// muted rows: the status line and the alarm card, nothing else.
const double welcomeStaysSilentCompactDesignHeight = 247;

/// Whether a picture [width] by [height] points is too short to draw the
/// muted rows beside the alarm at a readable size. It then draws the status
/// line and the alarm alone.
bool welcomeStaysSilentIsCompact(double width, double height) =>
    math.min(
      width / welcomeStaysSilentDesignWidth,
      height / welcomeStaysSilentDesignHeight,
    ) <
    welcomeStaysSilentMinUnit;

/// The size of a design unit for a picture [width] by [height] points, 1 at
/// the full design size and smaller where the room is. With the rows it never
/// goes below [welcomeStaysSilentMinUnit], so text stays readable: a picture
/// too short for that is [welcomeStaysSilentIsCompact] and is sized by the
/// compact design height instead.
double welcomeStaysSilentUnit(double width, double height) {
  final byWidth = width / welcomeStaysSilentDesignWidth;
  if (welcomeStaysSilentIsCompact(width, height)) {
    return math.min(
      1,
      math.min(byWidth, height / welcomeStaysSilentCompactDesignHeight),
    );
  }
  return math.min(
    1,
    math.min(byWidth, height / welcomeStaysSilentDesignHeight),
  );
}

/// The smallest a design unit gets while the rows are drawn.
const double welcomeStaysSilentMinUnit = 0.6;

/// One muted notification.
class WelcomeStaysSilentRow {
  const WelcomeStaysSilentRow({
    required this.offset,
    required this.scale,
    required this.opacity,
  });

  /// How far the row is below its place in design units. Up is negative.
  final double offset;

  /// 1 is the size of the row at rest.
  final double scale;
  final double opacity;
}

/// The alarm card.
class WelcomeStaysSilentAlarm {
  const WelcomeStaysSilentAlarm({
    required this.scale,
    required this.opacity,
    required this.glow,
    required this.shiver,
  });

  /// 1 is the size of the card at rest.
  final double scale;
  final double opacity;

  /// How far the ring around the card has spread, 0 to 1. The ring fades as
  /// it spreads.
  final double glow;

  /// The turn of the face on the card, clockwise is positive, in radians.
  final double shiver;
}

/// Everything in the picture at one moment.
class WelcomeStaysSilentFrame {
  const WelcomeStaysSilentFrame({
    required this.rows,
    required this.alarm,
    required this.jolt,
  });

  /// The muted rows, top to bottom.
  final List<WelcomeStaysSilentRow> rows;
  final WelcomeStaysSilentAlarm alarm;

  /// How far the whole picture is shaken sideways, in design units.
  final double jolt;
}

/// The picture under reduced motion, which is the same at every time: the
/// alarm is in front at its size, ringing, and the muted rows are pushed
/// aside and dimmed. Nothing shakes or spreads.
const WelcomeStaysSilentFrame _settled = WelcomeStaysSilentFrame(
  rows: [
    WelcomeStaysSilentRow(
      offset: -70,
      scale: welcomeStaysSilentRowAsideScale,
      opacity: welcomeStaysSilentRowAsideOpacity,
    ),
    WelcomeStaysSilentRow(
      offset: 90,
      scale: welcomeStaysSilentRowAsideScale,
      opacity: welcomeStaysSilentRowAsideOpacity,
    ),
    WelcomeStaysSilentRow(
      offset: 100,
      scale: welcomeStaysSilentRowAsideScale,
      opacity: welcomeStaysSilentRowAsideOpacity,
    ),
  ],
  alarm: WelcomeStaysSilentAlarm(scale: 1, opacity: 1, glow: 1, shiver: 0),
  jolt: 0,
);

/// The settled frame, for tests and for a held picture.
const WelcomeStaysSilentFrame welcomeStaysSilentSettled = _settled;

WelcomeStaysSilentRow _rowAt(double p, int index) {
  final from = welcomeStaysSilentRowFrom[index];
  final by = welcomeStaysSilentRowBy[index];
  final aside = welcomeStaysSilentRowAside[index];
  double through(List<(double, double)> stops) =>
      welcomeThrough(p, stops, curve: Curves.easeOut);
  return WelcomeStaysSilentRow(
    offset: through([
      (0, -welcomeStaysSilentRowDrop),
      (from, -welcomeStaysSilentRowDrop),
      (by, 0),
      (welcomeStaysSilentRowsHoldUntil, 0),
      (welcomeStaysSilentRowsAsideBy, aside),
      (1, aside),
    ]),
    scale: through([
      (0, 1),
      (welcomeStaysSilentRowsHoldUntil, 1),
      (welcomeStaysSilentRowsAsideBy, welcomeStaysSilentRowAsideScale),
      (1, welcomeStaysSilentRowAsideScale),
    ]),
    opacity: through([
      (0, 0),
      (from, 0),
      (by, 1),
      (welcomeStaysSilentRowsHoldUntil, 1),
      (welcomeStaysSilentRowsAsideBy, welcomeStaysSilentRowAsideOpacity),
      (welcomeStaysSilentRowsLeaveFrom, welcomeStaysSilentRowAsideOpacity),
      (1, 0),
    ]),
  );
}

/// Where everything is [seconds] into the story.
///
/// With [reducedMotion] it is the settled picture at every time.
WelcomeStaysSilentFrame welcomeStaysSilentFrameAt(
  double seconds, {
  required bool reducedMotion,
}) {
  if (reducedMotion) return _settled;
  final loopTime = math.max<double>(0, seconds) % welcomeStaysSilentLoopSeconds;
  final p = loopTime / welcomeStaysSilentLoopSeconds;

  const slam = [
    (0.0, welcomeStaysSilentAlarmFromScale),
    (welcomeStaysSilentAlarmFrom, welcomeStaysSilentAlarmFromScale),
    (welcomeStaysSilentAlarmBy, 1.0),
    (welcomeStaysSilentAlarmLeavesFrom, 1.0),
    (1.0, welcomeStaysSilentAlarmFromScale),
  ];
  const appear = [
    (0.0, 0.0),
    (welcomeStaysSilentAlarmFrom, 0.0),
    (welcomeStaysSilentAlarmBy, 1.0),
    (welcomeStaysSilentAlarmLeavesFrom, 1.0),
    (1.0, 0.0),
  ];

  final glowPhase =
      (loopTime % welcomeStaysSilentGlowSeconds) /
      welcomeStaysSilentGlowSeconds;
  final shiverPhase =
      (loopTime % welcomeStaysSilentShiverSeconds) /
      welcomeStaysSilentShiverSeconds;
  final shiverHalf = shiverPhase < 0.5
      ? Curves.easeInOut.transform(shiverPhase * 2)
      : 1 - Curves.easeInOut.transform((shiverPhase - 0.5) * 2);

  return WelcomeStaysSilentFrame(
    rows: [
      for (var i = 0; i < welcomeStaysSilentRowCount; i++) _rowAt(p, i),
    ],
    alarm: WelcomeStaysSilentAlarm(
      scale: math.max<double>(
        0,
        welcomeThrough(p, slam, curve: AppCurves.easeBack),
      ),
      opacity: welcomeThrough(
        p,
        appear,
        curve: AppCurves.easeBack,
      ).clamp(0.0, 1.0),
      glow: Curves.easeOut.transform(glowPhase),
      shiver:
          (-1 + 2 * shiverHalf) *
          welcomeStaysSilentShiverDegrees *
          math.pi /
          180,
    ),
    jolt: welcomeThrough(p, welcomeStaysSilentJolt),
  );
}

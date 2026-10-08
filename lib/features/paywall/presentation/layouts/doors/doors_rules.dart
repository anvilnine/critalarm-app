import 'dart:math' as math;

import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_arrangement.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_motion.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_turns.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:flutter/animation.dart';

// The door as numbers: when it opens, how far it stands open for each
// benefit, where the doorway is on a stage, and what the headline says. No
// widget is in here, so each rule has a test.
//
// The timeline, in seconds since the layout appeared:
//
// | From | To   | What the stage shows                                    |
// |------|------|---------------------------------------------------------|
// | 0    | 0.14 | The app's own wall and one shut door                    |
// | 0.14 | 0.4  | The door gives a little, as if pushed, and falls back   |
// | 0.4  | 1.15 | It swings open: light and rays in the doorway           |
// | 0.4  | 1.4  | The mascot looks up over the foot, then comes all the   |
// |      |      | way up. The preview and the words follow it in          |
// | 1.4  |      | Rest: the door open, the first benefit in the doorway   |
//
// After that the door opens a little wider for each benefit and swings
// back to where it began when the loop comes round.

/// When the door opens, in seconds since the layout appeared.
abstract final class DoorsTimeline {
  /// The first push: the door gives a little and falls back.
  static const double nudgeStart = 0.14;
  static const double nudgeEnd = 0.4;

  /// How far the first push opens the door, as a share of its first rest.
  static const double nudgeReach = 0.2;

  /// The swing starts here. It is also the loop's prelude: the mascot and
  /// the words start their entrance as the door starts to open.
  static const double prelude = 0.4;
  static const double swingEnd = 1.15;

  /// The second every part has settled, and the frame nothing moves on.
  static const double restAt = prelude + heroEntranceSeconds;

  /// How far through its opening the door is at [t]: 0 shut, 1 standing
  /// open where it rests for the first benefit.
  static double open(double t) {
    if (t >= swingEnd) return 1;
    if (t >= prelude) {
      // Ease out: quick off the push, slow into the stop.
      final p = phase(t, prelude, swingEnd);
      return 1 - math.pow(1 - p, 3).toDouble();
    }
    final nudge = phase(t, nudgeStart, nudgeEnd);
    return nudgeReach * math.sin(math.pi * nudge);
  }
}

/// How the stage moves in the doorway: rays turn in the light behind the
/// preview, the mascot looks up over the foot of the stage before it comes
/// all the way, it leans toward the doorway every few seconds, and each
/// new preview turns over like a door.
const HeroMotion doorsMotion = HeroMotion(
  atmosphere: HeroAtmosphereStyle.rays,
  entrance: HeroEntranceStyle.peek,
  idle: HeroIdleStyle.lean,
  arrival: HeroCardArrival.flip,
);

/// How many seconds of the entrance are skipped when an intro has just
/// handed over: the door is already on its way open.
const double doorsIntroHeadStart = 0.5;

/// The head start of a layout that does or does not follow an intro.
double doorsLeadFor({required bool followsIntro}) =>
    followsIntro ? doorsIntroHeadStart : 0;

/// Whether a clock that read [before] and now reads [now] has just passed
/// the moment [at]. A cue is played on the frame this turns true, once.
bool doorsReached(double before, double now, double at) =>
    before < at && now >= at;

/// How far the open door lies out over the wall, as a share of its own
/// width, for the first benefit and for the last. Each benefit between
/// them opens it a step wider.
const double doorsFirstReach = 0.26;
const double doorsLastReach = 0.6;

/// How far round the door has swung when it rests for benefit [index] of
/// [count], in radians. Zero is shut, a quarter turn is edge on, and past
/// that it lies out over the wall on the far side of its hinge.
///
/// [maxReach] is the widest the wall has room for, as a share of the
/// door's width.
double doorsRestAngle(int index, int count, {double maxReach = 1}) {
  final step = count < 2 ? 0.0 : index.clamp(0, count - 1) / (count - 1);
  final reach = math.min(
    doorsFirstReach + (doorsLastReach - doorsFirstReach) * step,
    maxReach.clamp(0.0, 1.0),
  );
  return math.pi / 2 + math.asin(reach);
}

/// How far round the door is, in radians.
///
/// During the entrance it is [open] of the way to its first rest (see
/// [DoorsTimeline.open]). After that it rests where benefit [index] has
/// it. While the stage changes to that benefit from [previous] it swings
/// between the two, [enter] of the way, 0 to 1: wider for a later
/// benefit, back again when the loop comes round.
double doorsAngleAt({
  required double open,
  required int index,
  required int count,
  int? previous,
  double enter = 1,
  double maxReach = 1,
}) {
  final rest = doorsRestAngle(index, count, maxReach: maxReach);
  if (open < 1) {
    return open.clamp(0.0, 1.0) * doorsRestAngle(0, count, maxReach: maxReach);
  }
  if (previous == null || previous == index || enter >= 1) return rest;
  final from = doorsRestAngle(previous, count, maxReach: maxReach);
  final p = Curves.easeInOutCubic.transform(enter.clamp(0.0, 1.0));
  return from + (rest - from) * p;
}

/// How far through a swing the door is, 0 to 1, for the taper of its
/// free edge: 0 and 1 are a door at rest.
double doorsSwingAt({
  required double open,
  required int index,
  int? previous,
  double enter = 1,
}) {
  if (open < 1) return open.clamp(0.0, 1.0);
  if (previous == null || previous == index) return 1;
  return enter.clamp(0.0, 1.0);
}

/// The door leaf at one point of its swing, as the eye sees it from the
/// front.
class DoorsLeafShape {
  const DoorsLeafShape({required this.extent, required this.taper});

  /// How far the leaf reaches from its hinge, in points. Over zero it
  /// covers the doorway. Under zero it lies out over the wall.
  final double extent;

  /// How far its free edge is drawn in from the top and from the bottom.
  /// Zero whenever the door is at rest, so it is square.
  final double taper;
}

/// The thickness of a door seen edge on, in points.
const double doorsLeafEdge = 8;

/// The shape of a leaf [width] wide and [height] tall that has swung
/// [angle] radians round, [swing] of the way through its move.
DoorsLeafShape doorsLeafShapeFor({
  required double angle,
  required double width,
  required double height,
  double swing = 1,
}) {
  return DoorsLeafShape(
    extent: width * math.cos(angle),
    taper: height * 0.045 * math.sin(math.pi * swing.clamp(0.0, 1.0)),
  );
}

/// Where the doorway, the mascot and the preview stand on a stage.
class DoorsGeometry {
  const DoorsGeometry({required this.arrangement, required this.doorway});

  /// The mascot and the preview, as the approved stage places them: the
  /// mascot is as large here as it is there.
  final HeroArrangement arrangement;

  /// The open doorway, around the preview and up to the top of the stage.
  /// The leaf hinges on its left edge, behind the mascot.
  final Rect doorway;

  /// The widest the leaf may lie out over the wall, as a share of its
  /// width, so it stays on the screen.
  double get maxReach => doorway.width <= 0
      ? 0
      : ((doorway.left - doorsWallRoom) / doorway.width).clamp(0.0, 1.0);
}

/// Room between the doorway's left edge and the preview inside it.
const double doorsPad = 10;

/// Room right of the doorway and above it. The close cross sits inside
/// the doorway's top corner, clear of its frame.
const double doorsRightRoom = 6;
const double doorsTopRoom = 6;

/// Room kept between the open leaf and the left edge of the screen.
const double doorsWallRoom = 10;

/// Places the doorway on a stage of [stage] points, or null when the
/// stage is too small for the mascot and a preview together. The layout
/// then draws the approved stage with no door.
DoorsGeometry? doorsGeometryFor(Size stage) {
  final arrangement = heroArrangementFor(stage);
  if (arrangement.kind != HeroStageKind.pair) return null;
  return DoorsGeometry(
    arrangement: arrangement,
    doorway: Rect.fromLTRB(
      arrangement.card.left - doorsPad,
      doorsTopRoom,
      stage.width - doorsRightRoom,
      // Down to the floor: the foot of the stage.
      stage.height,
    ),
  );
}

/// What the headline says.
enum DoorsHeadline {
  /// The offer, for Hosted and for Pro.
  hosted,
  pro,

  /// Hosted for someone whose plan is about to end, or has ended.
  keepOpen,
  openAgain,
}

/// The headline for a product opened from [source]. A Hosted plan that is
/// ending or has ended is spoken to as a door. Pro never is.
DoorsHeadline doorsHeadlineFor({
  required bool isHosted,
  required PaywallSource source,
}) {
  if (!isHosted) return DoorsHeadline.pro;
  return switch (source) {
    PaywallSource.planSheetEnding => DoorsHeadline.keepOpen,
    PaywallSource.planSheetEnded => DoorsHeadline.openAgain,
    _ => DoorsHeadline.hosted,
  };
}

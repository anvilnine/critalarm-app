import 'dart:math' as math;
import 'dart:ui';

import 'package:critalarm/core/paywall/paywall_source.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_arrangement.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_turns.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';

// The two doors as numbers: when the right one opens, where both stand on
// a stage, and what the headline says. No widget is in here, so each rule
// has a test.

/// When the right door opens, in seconds since the layout appeared.
///
/// Both doors stand shut from the first frame. The right one gives a
/// little, as if pushed from inside, then swings open while the mascot
/// pops up in the doorway. The approved entrance plays behind the door as
/// it opens, so the stage and the words arrive with the light.
abstract final class DoorsTimeline {
  /// The first push: the door gives a few degrees and falls back.
  static const double nudgeStart = 0.14;
  static const double nudgeEnd = 0.4;

  /// How far the first push opens the door, as a share of fully open.
  static const double nudgeReach = 0.09;

  /// The swing starts here. It is also the loop's prelude: the mascot and
  /// the words start their entrance as the door starts to open.
  static const double prelude = 0.4;
  static const double swingEnd = 1.15;

  /// The second every part has settled, and the frame nothing moves on.
  static const double restAt = prelude + heroEntranceSeconds;

  /// How far open the right door is at [t]: 0 shut, 1 square to the wall.
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

/// The door leaf at one point of its swing, as the eye sees it.
class DoorsLeafShape {
  const DoorsLeafShape({required this.width, required this.taper});

  /// The leaf's width on screen, from the hinge.
  final double width;

  /// How far its free edge is drawn in from the top and from the bottom.
  /// Zero when shut and when fully open, so both are square.
  final double taper;
}

/// The thickness of a door seen edge on, in points.
const double doorsLeafEdge = 8;

/// The shape of a leaf [open] of the way open (0 to 1) across a doorway
/// [width] wide and [height] tall.
DoorsLeafShape doorsLeafShapeFor({
  required double open,
  required double width,
  required double height,
}) {
  final angle = open.clamp(0.0, 1.0) * math.pi / 2;
  return DoorsLeafShape(
    width: doorsLeafEdge + (width - doorsLeafEdge) * math.cos(angle),
    taper: height * 0.06 * math.sin(2 * angle),
  );
}

/// Where the doors, the mascot and the preview stand on a stage.
class DoorsGeometry {
  const DoorsGeometry({
    required this.arrangement,
    required this.doorway,
    required this.freeDoor,
  });

  /// The mascot and the preview, for the stage.
  final HeroArrangement arrangement;

  /// The open doorway. The preview is inside it and the mascot stands on
  /// its left edge. The leaf hinges on its right edge.
  final Rect doorway;

  /// The shut door at the left edge.
  final Rect freeDoor;
}

/// The shut door's width, and the room either side of it. Its left edge
/// is the left edge of the words under the stage.
const double doorsFreeWidth = 38;
const double doorsFreeLeft = 20;
const double doorsFreeGap = 4;

/// Room between the doorway and the preview inside it.
const double doorsPad = 12;

/// Room right of the doorway, and above it when it stands under the cross.
const double doorsRightRoom = 12;
const double doorsCrossRoom = 50;

/// Room under the doors, so a bob does not touch the pips.
const double doorsFloorRoom = 8;

/// The mascot's edge against the preview's, and how much of it lies over
/// the preview's corner.
const double doorsMascotShare = 0.7;
const double doorsOverlapX = 0.2;
const double doorsOverlapY = 0.3;

/// The smallest mascot the doors are drawn around.
const double doorsMascotMin = 72;

/// Places the doors on a stage of [stage] points, or null when the stage
/// is too small for a preview in a doorway. The layout then draws the
/// approved stage with no doors.
///
/// The doorway is tried two ways: under the close cross, as wide as the
/// stage allows, and beside the cross, as tall as the stage allows. The
/// one with the larger mascot wins. Everything stands on one floor.
DoorsGeometry? doorsGeometryFor(Size stage) {
  final under = _place(
    stage,
    top: doorsCrossRoom,
    right: stage.width - doorsRightRoom,
  );
  final beside = _place(
    stage,
    top: heroTopRoom,
    right: stage.width - doorsCrossRoom,
  );
  if (under == null) return beside;
  if (beside == null) return under;
  return beside.arrangement.mascot.width > under.arrangement.mascot.width
      ? beside
      : under;
}

DoorsGeometry? _place(
  Size stage, {
  required double top,
  required double right,
}) {
  final floor = stage.height - doorsFloorRoom;
  const left = doorsFreeLeft + doorsFreeWidth + doorsFreeGap;
  // What the mascot and the preview share, across and down.
  final across = right - left - doorsPad - doorsLeafEdge;
  final down = floor - top - doorsPad;

  var card = math.min(
    heroCardMax,
    math.min(
      across / (1 + doorsMascotShare * (1 - doorsOverlapX)),
      down / (1 + doorsMascotShare * (1 - doorsOverlapY)),
    ),
  );
  var mascot = card * doorsMascotShare;
  if (card < heroCardMin) {
    // The preview keeps its smallest edge and the mascot gives.
    card = heroCardMin;
    mascot = math.min(
      (across - card) / (1 - doorsOverlapX),
      (down - card) / (1 - doorsOverlapY),
    );
  }
  if (mascot < doorsMascotMin) return null;

  final cardRight = right - doorsLeafEdge - doorsPad;
  final cardLeft = cardRight - card;
  final mascotLeft = cardLeft + mascot * doorsOverlapX - mascot;
  final mascotTop = floor - mascot;
  final cardTop = mascotTop + mascot * doorsOverlapY - card;

  return DoorsGeometry(
    arrangement: HeroArrangement(
      kind: HeroStageKind.pair,
      mascot: Rect.fromLTWH(mascotLeft, mascotTop, mascot, mascot),
      card: Rect.fromLTWH(cardLeft, cardTop, card, card),
    ),
    doorway: Rect.fromLTRB(cardLeft - doorsPad, top, right, floor),
    freeDoor: Rect.fromLTRB(
      doorsFreeLeft,
      top,
      doorsFreeLeft + doorsFreeWidth,
      floor,
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

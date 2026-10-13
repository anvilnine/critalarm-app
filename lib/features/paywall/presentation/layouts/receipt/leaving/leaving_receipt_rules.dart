import 'dart:math' as math;
import 'dart:ui';

import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/domain/leaving_floors.dart';
import 'package:critalarm/features/paywall/domain/leaving_numbers.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_turns.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_cue_rules.dart';
import 'package:critalarm/features/paywall/presentation/layouts/receipt/receipt_rules.dart';
import 'package:flutter/foundation.dart';

// The leaving receipt as numbers. The print is the shipped receipt's
// (`ReceiptTimeline`: the feed, the ink, the stamp, the sway). Only Crit and
// the arrangement differ. No widget is in here, so every rule has a test.

/// The leaving receipt's timeline: only what Crit does.
abstract final class LeavingReceiptTimeline {
  /// The print is over and Crit turns from sad to calm: a little after the
  /// stamp landed.
  static const double restAt = ReceiptTimeline.stampLanded + 0.55;

  /// Crit at [t]: sad through the whole print, then calm. He never nods,
  /// never hops and never wears the face a purchase wears. [atRest] is the
  /// second open before the end date: he is calm from the first frame and
  /// there is no tear to fade.
  static ReceiptActor actor(double t, {bool atRest = false}) {
    if (atRest) {
      return const ReceiptActor(
        face: HeroFace.calm,
        fromFace: HeroFace.calm,
        faceBlend: 1,
        hop: 0,
        entrance: 1,
      );
    }
    final entrance = phase(t, 0, heroEntranceSeconds);
    if (t < restAt) {
      return ReceiptActor(
        face: HeroFace.sad,
        fromFace: HeroFace.sad,
        faceBlend: 1,
        hop: 0,
        entrance: entrance,
      );
    }
    return ReceiptActor(
      face: HeroFace.calm,
      fromFace: HeroFace.sad,
      faceBlend: phase(t, restAt, restAt + heroFaceBlend),
      hop: 0,
      entrance: 1,
    );
  }
}

/// The second the leaving slip's part [step] starts to print, which is as it
/// leaves the slot. Part 0 is the header, parts 1 to [rows] are the rows and
/// the foot is the part after them: there is no total, so the feed has two
/// parts besides the rows.
double leavingPrintsAt(int step, int rows) =>
    ReceiptTimeline.feedStart +
    (step + 0.2) /
        (rows + 2) *
        (ReceiptTimeline.feedEnd - ReceiptTimeline.feedStart);

/// What the print sounds like for a slip of [rows] rows: the shipped
/// receipt's line cue as each row leaves the slot, and its stamp. There is
/// no total and no preview coming out.
List<PaywallCueBeat> leavingReceiptCues(int rows) => [
  for (var step = 1; step <= rows; step++)
    PaywallCueBeat(leavingPrintsAt(step, rows), PaywallCue.line),
  const PaywallCueBeat(ReceiptTimeline.stampAt, PaywallCue.stamp),
];

/// The number of days the line under the headline names: the window when
/// the phone holds all of it, the days it holds when it holds fewer, and at
/// least one.
int leavingSpanDays(LeavingFacts facts) =>
    math.max(1, math.min(LeavingFloors.windowDays, facts.historyDaysHeld));

/// Where the slot, the slip and the face stand on the stage.
@immutable
class LeavingReceiptLayout {
  const LeavingReceiptLayout({
    required this.plan,
    required this.mascot,
    required this.isStacked,
  });

  /// The slot, the paper and the figures' room.
  final ReceiptPlan plan;
  final Rect mascot;

  /// Text scale above 1.3: a full width slip with the face below it.
  final bool isStacked;

  Rect get paper => plan.paper;
  Rect get slot => plan.slot;
}

/// Above this text scale the slip is full width and the face sits below it.
const double leavingReceiptStackedAbove = 1.3;

double _mascotFor(Rect paper) => math.min(
  ReceiptPlan.mascotMax,
  math.max(ReceiptPlan.mascotMin, paper.width * 0.62),
);

/// The arrangement for [rows] rows on a [stage].
///
/// Side by side, the face stands at the slip's bottom right corner, leaning
/// over its edge, so a slip of two rows composes the way a slip of four
/// does. Past [leavingReceiptStackedAbove] the slip takes the width and the
/// face stands under it at the right.
LeavingReceiptLayout leavingReceiptLayoutFor(
  Size stage, {
  required int rows,
  required double textScale,
}) {
  final isStacked = textScale > leavingReceiptStackedAbove;
  if (isStacked) {
    const below = ReceiptPlan.mascotMin + 4;
    final plan = ReceiptPlan.of(
      stage,
      count: rows,
      hasCard: false,
      hasTotal: false,
      fullWidth: true,
      reserveBelow: below,
    );
    const size = ReceiptPlan.mascotMin;
    return LeavingReceiptLayout(
      plan: plan,
      isStacked: true,
      mascot: Rect.fromLTWH(
        stage.width - ReceiptPlan.mascotRight - size,
        plan.paper.bottom + 4,
        size,
        size,
      ),
    );
  }
  final plan = ReceiptPlan.of(
    stage,
    count: rows,
    hasCard: false,
    hasTotal: false,
  );
  // The face leans over the slip's right edge by a little, so it covers no
  // row, and its foot stands on the slip's bottom edge.
  final left = plan.paper.right - ReceiptPlan.lean;
  final room = stage.width - ReceiptPlan.mascotRight - left;
  final size = math.min(
    _mascotFor(plan.paper),
    math.max(ReceiptPlan.mascotMin, room),
  );
  return LeavingReceiptLayout(
    plan: plan,
    isStacked: false,
    mascot: Rect.fromLTWH(
      math.min(left, stage.width - ReceiptPlan.mascotRight - size),
      math.max(0, plan.paper.bottom - size),
      size,
      size,
    ),
  );
}

/// The least stage height a slip of [rows] rows fits on.
double leavingReceiptMinHeight(int rows, {required double textScale}) {
  final slip = ReceiptPlan.minHeight(rows, hasTotal: false);
  return textScale > leavingReceiptStackedAbove
      ? slip + ReceiptPlan.mascotMin + 4
      : slip;
}

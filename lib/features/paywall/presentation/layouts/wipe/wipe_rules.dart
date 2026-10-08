import 'dart:math' as math;
import 'dart:ui';

import 'package:critalarm/design/design.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_arrangement.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_motion.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/history_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/pushes_preview.dart';
import 'package:critalarm/features/paywall/presentation/layouts/previews/topics_preview.dart';

// The numbers of the wipe: where the divider is at a second, where it
// settles, what the Free side of the stage draws. No widgets, so they
// have tests.
//
// The timeline, in seconds since the layout appeared:
//
// | From | To   | What the stage shows                                   |
// |------|------|--------------------------------------------------------|
// | 0    | 1    | The approved entrance, all of it on the Free side      |
// | 0.7  | 1.5  | The divider sweeps in from the right, colour behind it |
// | 1.5  |      | Rest: the divider on the mascot's middle               |
//
// After that the mascot leans toward the product every few seconds and
// the divider goes with it, so the line stays on the middle of its face.
// Bubbles rise on the product's side only.
//
// The divider's place is a share of the stage's width from the left. Free
// is left of it, the product right of it.

/// When the divider leaves the right edge and when it has settled.
const double wipeSweepStart = 0.7;
const double wipeSweepEnd = 1.5;

/// The second the layout rests on.
const double wipeRestSeconds = wipeSweepEnd;

/// The second the divider is on the mascot to the eye: the sweep eases
/// out, so it is home long before it stops. The landing's cue plays here.
const double wipeLandsAt = wipeSweepStart + 0.4;

/// How the product's side moves: the approved pop, bubbles rising behind,
/// and a lean every few seconds. The Free side takes [wipeFreeMotion]: the
/// same mascot, so the same entrance and the same lean, and no bubbles.
const HeroMotion wipeMotion = HeroMotion(
  atmosphere: HeroAtmosphereStyle.bubbles,
  idle: HeroIdleStyle.lean,
);
const HeroMotion wipeFreeMotion = HeroMotion(idle: HeroIdleStyle.lean);

/// How many seconds of the entrance are skipped when an intro has just
/// handed over. The intro ends on the mascot, so the stage is not shown
/// all Free for long: the sweep starts almost at once.
const double wipeIntroHeadStart = 0.6;

/// The head start of a layout that does or does not follow an intro.
double wipeLeadFor({required bool followsIntro}) =>
    followsIntro ? wipeIntroHeadStart : 0;

/// How far the middle of the mascot's face moves sideways in its lean, in
/// points, when its idle reads [seconds] and it is [mascot] points
/// square. The divider moves by this, so it stays on the face. Zero at
/// rest and between leans.
double wipeLeanShiftAt(double seconds, {required double mascot}) {
  final pose = heroIdlePose(
    HeroIdleStyle.lean,
    seconds: seconds,
    size: mascot,
  );
  // It leans about the middle of its foot, so its middle swings with it.
  return pose.dx + math.sin(pose.angle) * mascot / 2;
}

/// Whether a clock that read [before] and now reads [now] has just passed
/// the moment [at]. A cue is played on the frame this turns true, once.
bool wipeReached(double before, double now, double at) =>
    before < at && now >= at;

/// How near either edge a finger can take the divider.
const double wipeMin = 0.1;
const double wipeMax = 0.9;

/// Where the divider settles with no mascot to stand on.
const double wipeSettleAlone = 0.2;

/// How long the divider stays where a finger left it, and how long it
/// takes to go home after that.
const double wipeHoldSeconds = 4;
const double wipeReturnSeconds = 0.6;

/// Room kept above the mascot for the two tags.
const double wipeTagRoom = 10;

/// The approved arrangement, a little lower, so the tags have the top.
HeroArrangement wipeArrangementFor(Size size) {
  final inner = heroArrangementFor(
    Size(size.width, size.height - wipeTagRoom),
  );
  if (inner.kind == HeroStageKind.none) return inner;
  return HeroArrangement(
    kind: inner.kind,
    mascot: inner.mascot.translate(0, wipeTagRoom),
    card: inner.kind == HeroStageKind.pair
        ? inner.card.translate(0, wipeTagRoom)
        : inner.card,
  );
}

/// Where the divider settles: down the middle of the mascot, so one half
/// of its face is Free and the other is the product.
double wipeSettleFor(HeroArrangement arrangement, double width) {
  if (arrangement.kind == HeroStageKind.none || width <= 0) {
    return wipeSettleAlone;
  }
  return (arrangement.mascot.center.dx / width).clamp(0.16, 0.5);
}

/// How far down the stage the grip sits: under the mascot, clear of its
/// face.
double wipeGripCentreFor(HeroArrangement arrangement, Size size) =>
    switch (arrangement.kind) {
      HeroStageKind.pair =>
        (arrangement.mascot.bottom + arrangement.card.bottom) / 2,
      HeroStageKind.mascot || HeroStageKind.none => size.height - 24,
    };

/// What the hand did to the divider: where it put it, and when it let go.
class WipeGrip {
  const WipeGrip({required this.at, this.releasedAt});

  /// The divider's place under the finger.
  final double at;

  /// The clock second the finger lifted. Null while it is down.
  final double? releasedAt;

  /// The same grip moved [delta] of the stage's width.
  WipeGrip moved(double delta) =>
      WipeGrip(at: (at + delta).clamp(wipeMin, wipeMax));

  /// The same grip, let go at clock second [t].
  WipeGrip released(double t) => WipeGrip(at: at, releasedAt: t);
}

/// Where the divider is at clock second [t].
///
/// Untouched, it waits at the right edge, sweeps to [settle] and stays.
/// Under a finger it is where the finger has it. Let go, it holds for
/// [wipeHoldSeconds] and goes home. When nothing may move it is at
/// [settle], or where the hand last put it. [lead] is the head start of
/// the sweep: see [wipeLeadFor].
double wipeDividerAt(
  double t, {
  required double settle,
  WipeGrip? grip,
  bool isStill = false,
  double lead = 0,
}) {
  if (grip != null) {
    final released = grip.releasedAt;
    if (isStill || released == null) return grip.at;
    final home = released + wipeHoldSeconds;
    final back = AppCurves.easeOut.transform(
      phase(t, home, home + wipeReturnSeconds),
    );
    return grip.at + (settle - grip.at) * back;
  }
  if (isStill) return settle;
  final sweep = AppCurves.easeOut.transform(
    phase(t + lead, wipeSweepStart, wipeSweepEnd),
  );
  return 1 + (settle - 1) * sweep;
}

/// How much of a tag shows when its side of the stage is [room] points
/// wide and the tag needs [needed]: gone before it would be cut.
double wipeTagShow(double room, double needed) =>
    phase(room, needed, needed + 16);

/// How long after its part starts a preview shows what Free has: the
/// switch that was refused, the count stopped at the allowance, the list
/// stopped at the line. An extra that Free does not have at all holds its
/// first, default moment.
double wipeFreeOffsetFor(PaywallPreviewId? preview) => switch (preview) {
  PaywallPreviewId.topics =>
    // Just after the refusal, before the next tap is on its way.
    TopicsPreviewTimes.refused + 0.1 - TopicsPreviewTimes.reset,
  PaywallPreviewId.pushes =>
    (PushesPreviewTimes.stall + PushesPreviewTimes.run) / 2 -
        PushesPreviewTimes.drain,
  PaywallPreviewId.history =>
    (HistoryPreviewTimes.stop + HistoryPreviewTimes.lift) / 2 -
        HistoryPreviewTimes.rewind,
  PaywallPreviewId.appIcons => 0.6,
  PaywallPreviewId.customAlarmScreens => 0.75,
  PaywallPreviewId.widgets || PaywallPreviewId.wakeUpChallenges => 0.12,
  PaywallPreviewId.customSounds => 0.1,
  PaywallPreviewId.weeklyCheck || null => 0,
};

/// The second the Free side's clock stands on. It never moves.
const double wipeFrozenSecond = 100;

/// [frame] as the Free side draws it: the same turn in the same place,
/// its preview held on what Free has, the mascot doubtful and wearing
/// nothing. It hops, bobs and blinks with [frame], because it is the same
/// mascot.
HeroFrame wipeFreeFrame(HeroFrame frame) => HeroFrame(
  scene: frame.scene,
  previous: frame.previous,
  sceneSeconds: frame.sceneSeconds,
  cardEnter: frame.cardEnter,
  playFrom: wipeFrozenSecond - wipeFreeOffsetFor(frame.scene?.preview),
  previousPlayFrom: frame.previous == null
      ? null
      : wipeFrozenSecond - wipeFreeOffsetFor(frame.previous?.preview),
  turn: frame.turn,
  previousTurn: frame.previousTurn,
  fromFace: HeroFace.doubtful,
  face: HeroFace.doubtful,
  faceBlend: 1,
  props: const {},
  hop: frame.hop,
  blink: frame.blink,
  entrance: frame.entrance,
  bob: frame.bob,
  progress: frame.progress,
  isHeld: frame.isHeld,
  direction: frame.direction,
  pull: frame.pull,
);

/// A colour matrix that keeps [saturation] of every colour, 0 to 1. The
/// Free side is drawn through it, so it is the same picture with the
/// colour taken out.
List<double> wipeMutedMatrix(double saturation) {
  const r = 0.2126;
  const g = 0.7152;
  const b = 0.0722;
  final k = 1 - saturation;
  return [
    r * k + saturation, g * k, b * k, 0, 0, //
    r * k, g * k + saturation, b * k, 0, 0, //
    r * k, g * k, b * k + saturation, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// How much colour the Free side keeps.
const double wipeFreeSaturation = 0.12;

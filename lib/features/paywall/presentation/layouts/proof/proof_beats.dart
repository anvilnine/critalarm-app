import 'dart:math' as math;
import 'dart:ui';

import 'package:critalarm/core/ui_sound/paywall_cues.dart';
import 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_cues.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_loop.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_motion.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_cue_rules.dart';

// The Proof layout's turns, as numbers. Every benefit plays as two beats:
// first as it is on Free, then the lift. The preview, the face and the tag
// all change at the same second, and that second is written here once per
// preview. No widget is in here, so every row has a test.

/// How a benefit looks on Free.
enum ProofStart {
  /// The limit stops it: a switch refused, a count stalled, a list cut.
  refused,

  /// Nothing is refused. Free is the plain default and the lift adds to it.
  plain,

  /// Free does not have it at all. The preview waits behind a lock, grey,
  /// and the lift lets it play.
  locked,
}

/// One benefit's turn: where its preview starts, how long it waits there,
/// and the script the mascot follows.
class ProofTurn {
  const ProofTurn({
    required this.start,
    required this.from,
    required this.script,
    this.hold = 0,
  });

  final ProofStart start;

  /// How far into its own part the preview is when the turn starts.
  final double from;

  /// How long the preview holds that frame before it plays on: the beat
  /// the Free picture is held for.
  final double hold;

  /// The mascot's script. Its first hop is the lift. Its `lead` is
  /// [from] less [hold], which is what makes the preview wait.
  final HeroScript script;

  /// The second of the turn the lift lands.
  double get liftAt => proofLiftAt(script);
}

/// The second of [script] the lift lands: its first hop.
double proofLiftAt(HeroScript script) {
  for (final beat in script.beats) {
    if (beat.isReaction) return beat.at;
  }
  return script.beats.last.at;
}

/// The face the mascot holds through the Free beat.
HeroFace proofFreeFace(ProofStart start) => switch (start) {
  ProofStart.refused || ProofStart.locked => HeroFace.doubtful,
  ProofStart.plain => HeroFace.watching,
};

ProofTurn _turn(
  ProofStart start, {
  required double from,
  required double liftAt,
  required double seconds,
  required HeroFace liftFace,
  double hold = 0,
  HeroBeat? then,
  Map<HeroProp, double> props = const {},
  Map<HeroProp, double> propsOff = const {},
}) => ProofTurn(
  start: start,
  from: from,
  hold: hold,
  script: HeroScript(
    seconds: seconds,
    lead: from - hold,
    beats: [
      HeroBeat(0, proofFreeFace(start)),
      HeroBeat(liftAt, liftFace, isReaction: true),
      ?then,
    ],
    props: props,
    propsOff: propsOff,
  ),
);

/// The turn [preview] plays when it is one of [count] benefits.
///
/// The times follow what each preview does at that second of its loop. A
/// lone benefit plays the approved turn for one, whole, and counts as
/// lifted from its first hop.
ProofTurn proofTurnFor(PaywallPreviewId preview, {required int count}) {
  if (count == 1) {
    final solo = heroScriptFor(preview, count: 1);
    return ProofTurn(start: ProofStart.plain, from: solo.lead, script: solo);
  }
  return switch (preview) {
    // A third switch is tapped and refused. Tapped again, it goes on.
    PaywallPreviewId.topics => _turn(
      ProofStart.refused,
      from: 0.3,
      liftAt: 1.6,
      seconds: 2.5,
      liftFace: HeroFace.glad,
    ),
    // The count sits at the free allowance, then runs to the Hosted one.
    PaywallPreviewId.pushes => _turn(
      ProofStart.refused,
      from: 0.8,
      hold: 0.9,
      liftAt: 1.35,
      seconds: 3.3,
      liftFace: HeroFace.glad,
      then: const HeroBeat(2.8, HeroFace.winning),
    ),
    // The list scrolls to the free limit and stops. Then it goes on.
    PaywallPreviewId.history => _turn(
      ProofStart.refused,
      from: 0.3,
      liftAt: 1.35,
      seconds: 2.6,
      liftFace: HeroFace.glad,
    ),
    // The standard icon, then one with a crown, and the mascot's own.
    PaywallPreviewId.appIcons => _turn(
      ProofStart.plain,
      from: 2.3,
      hold: 0.5,
      liftAt: 1.2,
      seconds: 2.8,
      liftFace: HeroFace.keen,
      then: const HeroBeat(1.7, HeroFace.cool),
      props: const {HeroProp.crown: 1.2, HeroProp.shades: 1.7},
    ),
    // The widget rings behind the lock. Then its button is pressed.
    PaywallPreviewId.widgets => _turn(
      ProofStart.locked,
      from: 1.5,
      liftAt: 1.1,
      seconds: 2.4,
      liftFace: HeroFace.winking,
    ),
    // Earlier weeks behind the lock. Then this week's test push leaves,
    // lands, and is ticked.
    PaywallPreviewId.weeklyCheck => _turn(
      ProofStart.locked,
      from: 0.8,
      liftAt: 1.1,
      seconds: 3.4,
      liftFace: HeroFace.keen,
      then: const HeroBeat(2.4, HeroFace.winning),
    ),
    // The challenge waits behind the lock. Then the code is scanned and
    // the alarm stops.
    PaywallPreviewId.wakeUpChallenges => _turn(
      ProofStart.locked,
      from: 0.12,
      hold: 0.5,
      liftAt: 1.08,
      seconds: 3.5,
      liftFace: HeroFace.keen,
      then: const HeroBeat(2.88, HeroFace.relieved),
    ),
    // The recorder waits behind the lock. Then the take is recorded and
    // becomes a sound of its own.
    PaywallPreviewId.customSounds => _turn(
      ProofStart.locked,
      from: 0,
      hold: 0.6,
      liftAt: 1.2,
      seconds: 4,
      liftFace: HeroFace.listening,
      then: const HeroBeat(3.3, HeroFace.loving),
      props: const {HeroProp.headphones: 1.2},
    ),
    // The standard alarm screen, then the dark one, then the poster.
    PaywallPreviewId.customAlarmScreens => _turn(
      ProofStart.plain,
      from: 0.9,
      hold: 0.6,
      liftAt: 1.2,
      seconds: 3.6,
      liftFace: HeroFace.cool,
      then: const HeroBeat(2.7, HeroFace.proud),
      props: const {HeroProp.shades: 1.2, HeroProp.bowTie: 2.7},
      propsOff: const {HeroProp.shades: 2.4},
    ),
  };
}

/// How much of the entrance is already over when the layout opens after
/// an intro, in seconds. The intro ends on the mascot, so it is in its
/// place from the first frame and only the card and the words still come.
const double proofAfterIntroLead = 0.6;

/// The Proof loop for a product's [previews], in order. After an intro
/// ([followsIntro]) its entrance has a head start.
HeroLoop proofLoopFor(
  List<PaywallPreviewId> previews, {
  bool followsIntro = false,
}) => HeroLoop.turns([
  for (final preview in previews)
    HeroTurn(
      proofTurnFor(preview, count: previews.length).script,
      preview: preview,
    ),
], prelude: followsIntro ? -proofAfterIntroLead : 0);

/// How the Proof stage moves. The mascot is dropped in, leans toward the
/// preview as it watches, and the card turns over from one benefit to the
/// next, as the tag on its corner does. The air is rings.
const HeroMotion proofMotion = HeroMotion(
  atmosphere: HeroAtmosphereStyle.rings,
  entrance: HeroEntranceStyle.drop,
  idle: HeroIdleStyle.lean,
  arrival: HeroCardArrival.flip,
);

/// The refusal: the second of a turn the card shakes its head, how long
/// for, how far to each side in points, and how many times.
const double proofShakeAt = 0.42;
const double proofShakeSeconds = 0.44;
const double proofShakeReach = 6;
const int proofShakeTurns = 3;

/// The lift: how long the card's jump lasts, how high it goes in points,
/// and how much larger the tag is at the top of it.
const double proofPopSeconds = 0.36;
const double proofPopHeight = 10;
const double proofPopSwell = 0.2;

/// Whether [turn] has a refusal to shake at: Free stops it, or does not
/// have it. A plain default is not a refusal.
bool proofShakes(ProofTurn turn) =>
    turn.start != ProofStart.plain && turn.liftAt > proofShakeAt;

/// How far the card and its tag are off their place [seconds] into
/// [turn], in points.
///
/// At the refusal the card shakes sideways, less each time, and is back
/// in its place before the lift. At the lift it jumps and lands. Between
/// the two, and when the turn is over, it is at zero.
Offset proofNudgeAt(ProofTurn turn, double seconds) {
  if (seconds >= turn.liftAt) {
    final p = phase(seconds, turn.liftAt, turn.liftAt + proofPopSeconds);
    return Offset(0, -proofPopHeight * 4 * p * (1 - p));
  }
  if (!proofShakes(turn)) return Offset.zero;
  final end = math.min(proofShakeAt + proofShakeSeconds, turn.liftAt);
  final p = phase(seconds, proofShakeAt, end);
  if (p <= 0 || p >= 1) return Offset.zero;
  return Offset(
    proofShakeReach * (1 - p) * math.sin(2 * math.pi * proofShakeTurns * p),
    0,
  );
}

/// How much larger than itself the tag is [seconds] into [turn]: it
/// swells as the lift lands and is back at its own size after it.
double proofTagSwellAt(ProofTurn turn, double seconds) {
  final p = phase(seconds, turn.liftAt, turn.liftAt + proofPopSeconds);
  return 1 + proofPopSwell * 4 * p * (1 - p);
}

/// A moment of a turn that is felt and heard.
enum ProofMoment { refusal, lift }

/// The moments of [turn] the clock passed between [from] and [to] seconds
/// into it. A clock that went backwards passed none.
Set<ProofMoment> proofMomentsBetween(ProofTurn turn, double from, double to) {
  if (to <= from) return const {};
  bool passed(double at) => from < at && to >= at;
  return {
    if (proofShakes(turn) && passed(proofShakeAt)) ProofMoment.refusal,
    if (passed(turn.liftAt)) ProofMoment.lift,
  };
}

/// What [moment] sounds and feels like, or null for nothing.
///
/// A turn the hand asked for ([byHand]) is the whole story: the refusal
/// knocks and the lift answers it. A turn the loop plays by itself marks
/// only the lift, with the tag turning over, and only [inFirstPass]
/// (`paywallLoopCues`): a screen left open does not keep sounding.
PaywallCue? proofCueFor(
  ProofMoment moment, {
  required bool byHand,
  required bool inFirstPass,
}) => switch (moment) {
  ProofMoment.refusal => byHand ? PaywallCue.refuse : null,
  ProofMoment.lift =>
    byHand
        ? PaywallCue.lift
        : inFirstPass
        ? PaywallCue.flip
        : null,
};

/// How far through the entrance the Free tag starts to show on the card's
/// corner: after the card has landed.
const double proofTagAppearsAt = 0.7;

/// What the entrance sounds like, by clock second, for a loop with
/// [prelude]: the mascot is dropped in, and the Free tag turns up on the
/// card.
List<PaywallCueBeat> proofEntranceCues({double prelude = 0}) => [
  heroLandingBeat(proofMotion.entrance, prelude: prelude),
  PaywallCueBeat(
    prelude + proofTagAppearsAt * heroEntranceSeconds,
    PaywallCue.flip,
  ),
];

/// The clock second to cue a preview at, so it holds its Free frame.
///
/// [playFrom] is the cue the loop gives the turn and [from] is
/// [ProofTurn.from]. Until the hold is over the cue moves with the clock
/// [t], which keeps the preview on the frame the turn starts with. After
/// it the loop's own cue is the earlier one, and the preview plays.
double proofCueAt(double t, {required double playFrom, required double from}) =>
    math.min(playFrom, t - from);

/// How long the lock takes to open and the colour to come back.
const double proofUnlockSeconds = 0.3;

/// How far a preview is behind its lock [seconds] into [turn], 1 to 0.
/// Only a [ProofStart.locked] turn is ever behind one.
double proofLockAt(ProofTurn turn, double seconds) =>
    turn.start != ProofStart.locked
    ? 0
    : 1 - phase(seconds, turn.liftAt, turn.liftAt + proofUnlockSeconds);

/// How long the tag takes to flip over.
const double proofFlipSeconds = 0.24;

/// The tag at one moment: which side is up, and how far it is through a
/// flip.
class ProofTagFrame {
  const ProofTagFrame({required this.isLifted, required this.flat});

  /// What a still screen shows: the lift, flat.
  static const ProofTagFrame rest = ProofTagFrame(isLifted: true, flat: 1);

  /// False while the tag says Free, true once it names the product.
  final bool isLifted;

  /// The tag's height against its own, 0 to 1. It closes to an edge half
  /// way through a flip, changes side there, and opens again. It rests
  /// at 1.
  final double flat;
}

/// The tag [seconds] into a turn whose lift lands at [liftAt].
///
/// It says Free until the lift and flips to the product's name there, with
/// the mascot's hop. When the turn before it ended lifted
/// ([cameFromLifted]), the tag flips back to Free as the turn starts.
ProofTagFrame proofTagAt({
  required double seconds,
  required double liftAt,
  bool cameFromLifted = false,
}) {
  if (seconds >= liftAt) {
    final p = phase(seconds, liftAt, liftAt + proofFlipSeconds);
    return ProofTagFrame(isLifted: p >= 0.5, flat: (1 - 2 * p).abs());
  }
  if (cameFromLifted && seconds < proofFlipSeconds) {
    final p = phase(seconds, 0, proofFlipSeconds);
    return ProofTagFrame(isLifted: p < 0.5, flat: (1 - 2 * p).abs());
  }
  return const ProofTagFrame(isLifted: false, flat: 1);
}

/// The tag for a [frame] of the Proof loop. [isStill] is true when nothing
/// may move.
ProofTagFrame proofTagFor(HeroFrame frame, {bool isStill = false}) {
  final scene = frame.scene;
  if (isStill || scene == null) return ProofTagFrame.rest;
  // The entrance: Free, waiting for the first turn.
  if (frame.entrance < 1) return const ProofTagFrame(isLifted: false, flat: 1);

  final previous = frame.previous;
  final previousTurn = frame.previousTurn;
  final cameFromLifted =
      previous != null &&
      previousTurn != null &&
      frame.turn - previousTurn >=
          proofLiftAt(previous.script) + proofFlipSeconds / 2;
  return proofTagAt(
    seconds: frame.sceneSeconds,
    liftAt: proofLiftAt(scene.script),
    cameFromLifted: cameFromLifted,
  );
}

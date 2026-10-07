import 'dart:math' as math;

import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_hero.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_tone.dart';

// The reel as numbers: which tone a scene is painted on, how full each story
// bar is, what a tap means, where the two scenes are during a push, and the
// frames the two scenes draw. No widget is in here, so every rule has a
// test.

/// What a scene is painted on. Cobalt is left out: the button owns it.
enum ReelTone { cream, high, panel, surface, canvas }

/// The tone of the scene at [index]. No two neighbours share one.
ReelTone reelToneFor(int index) =>
    ReelTone.values[index % ReelTone.values.length];

/// The tone the stage's atmosphere is tinted for on [tone]. Only the canvas
/// has colours of its own. On every other tone the disc and the shapes are
/// tints of the ink that reads there.
PaywallTone reelAirFor(ReelTone tone) => switch (tone) {
  ReelTone.canvas => PaywallTone.canvas,
  ReelTone.panel => PaywallTone.panel,
  ReelTone.cream || ReelTone.high || ReelTone.surface => PaywallTone.surface,
};

/// How full the story bar at [bar] is, 0 to 1, while the scene at [active]
/// is [progress] of the way through its turn: the scenes already seen are
/// full, the one playing fills, the rest wait.
double reelBarFill(int bar, {required int active, required double progress}) {
  if (bar < active) return 1;
  if (bar > active) return 0;
  return progress.clamp(0, 1).toDouble();
}

/// What a tap [x] points across a scene [width] points wide asks for: 1 is
/// the next scene (the right half), -1 the previous one.
int reelTapStep(double x, double width) => x < width / 2 ? -1 : 1;

/// A finger down this long was a hold, which only pauses. Lifting it does
/// not change the scene.
const Duration reelHoldAfter = Duration(milliseconds: 350);

/// Whether a finger that stayed down for [held] was holding the scene.
bool reelIsHold(Duration held) => held >= reelHoldAfter;

/// After a touch the chosen scene plays and then holds this long before
/// the reel moves on. Shorter than the kit's hold: a reel keeps going.
const double reelHoldSeconds = 2;

/// Where the two scenes are while one pushes the other out, as shares of
/// the scene's width.
class ReelPush {
  const ReelPush({required this.into, required this.out});

  /// The scene coming in: 0 is in place.
  final double into;

  /// The scene leaving: 0 is in place.
  final double out;
}

/// The push when the new scene is [eased] of the way in, 0 to 1. With
/// [direction] 1 it comes from the right, with -1 from the left. A scene
/// the loop brought (0) comes from the right, as the next one does.
ReelPush reelPushAt(double eased, int direction) {
  final from = direction < 0 ? -1.0 : 1.0;
  return ReelPush(into: from * (1 - eased), out: -from * eased);
}

/// [frame] for the scene on stage, with nothing fading under its picture.
/// The push shows the scene before it, so the stage must not.
HeroFrame reelSettled(HeroFrame frame) => HeroFrame(
  scene: frame.scene,
  previous: null,
  sceneSeconds: frame.sceneSeconds,
  cardEnter: 1,
  playFrom: frame.playFrom,
  previousPlayFrom: null,
  turn: frame.turn,
  previousTurn: null,
  fromFace: frame.fromFace,
  face: frame.face,
  faceBlend: frame.faceBlend,
  props: frame.props,
  hop: frame.hop,
  blink: frame.blink,
  entrance: frame.entrance,
  bob: frame.bob,
  progress: frame.progress,
  isHeld: frame.isHeld,
  direction: 0,
  pull: 0,
);

/// The scene on its way out at [frame], as a frame of its own: its picture
/// carries on from where it was and the mascot keeps the face it had. Null
/// when no scene is leaving.
HeroFrame? reelLeaving(HeroFrame frame) {
  final previous = frame.previous;
  if (previous == null || frame.cardEnter >= 1) return null;
  return HeroFrame(
    scene: previous,
    previous: null,
    sceneSeconds: previous.script.seconds,
    cardEnter: 1,
    playFrom: frame.previousPlayFrom ?? frame.playFrom,
    previousPlayFrom: null,
    turn: frame.previousTurn ?? 0,
    previousTurn: null,
    fromFace: frame.fromFace,
    face: frame.fromFace,
    faceBlend: 1,
    props: const {},
    hop: 0,
    blink: 0,
    entrance: 1,
    bob: frame.bob,
    progress: 1,
    isHeld: false,
    direction: 0,
    pull: 0,
  );
}

/// The strip along the top that holds the story bars and the close cross.
const double reelBarsHeight = 44;

/// The room kept at the right of the bars for the close cross.
const double reelCrossRoom = 52;

/// The gap between the scene's round lower edge and the buy block, so the
/// button and the saving badge never touch it.
const double reelSceneGap = 12;

/// What one scene measures on one phone.
class ReelSizes {
  const ReelSizes({
    required this.headline,
    required this.eyebrowGap,
    required this.stageGap,
    required this.foot,
  });

  /// [isCompact] is `scope.isCompact`, a phone 667 points tall or under.
  factory ReelSizes.of({required bool isCompact}) => isCompact
      ? const ReelSizes(headline: 30, eyebrowGap: 4, stageGap: 4, foot: 12)
      : const ReelSizes(headline: 38, eyebrowGap: 6, stageGap: 8, foot: 20);

  /// Font size of the scene's headline.
  final double headline;

  /// Between the eyebrow and the headline.
  final double eyebrowGap;

  /// Between the headline and the stage.
  final double stageGap;

  /// Under the stage, down to the scene's lower edge.
  final double foot;
}

/// The height left for the stage in a scene [height] points tall whose
/// words take [words]. Never under zero: at a large text size the stage's
/// own arrangement drops the picture, then the mascot.
double reelStageHeight({
  required double height,
  required double words,
  required ReelSizes sizes,
}) => math
    .max(
      0,
      height -
          reelBarsHeight -
          words -
          sizes.stageGap -
          sizes.foot -
          reelSceneGap,
    )
    .floorToDouble();

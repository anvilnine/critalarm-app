import 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_turns.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';

export 'package:critalarm/features/paywall/presentation/layouts/kit/hero/hero_turns.dart';

// The loop of a stage that plays one benefit at a time, as numbers: which
// turn plays when, what the face does about it, what the hand changed, and
// what the frame is when nothing may move. No widget is in here, so every
// row of the table has a test.

/// One turn, placed in the loop.
class HeroScene {
  const HeroScene({
    required this.index,
    required this.preview,
    required this.start,
    required this.script,
  });

  /// Which turn: for the default loop, which benefit, in the order the
  /// product lists them.
  final int index;

  /// The preview the card plays. Null for a turn a layout draws itself.
  final PaywallPreviewId? preview;

  /// Seconds into the loop this turn starts.
  final double start;
  final HeroScript script;

  double get end => start + script.seconds;
}

/// What the hand last chose. With none, the loop is a function of the
/// clock alone.
///
/// The benefit at [index] takes the stage at [since], plays its turn from
/// the beginning, holds on its finished frame for [HeroLoop.holdSeconds],
/// and the loop then moves on from the benefit after it. Make one with
/// [HeroLoop.touch].
class HeroHand {
  const HeroHand({
    required this.index,
    required this.since,
    required this.touchedAt,
    this.direction = 0,
    this.pull = 0,
    this.before,
  });

  /// The benefit chosen.
  final int index;

  /// The clock second its turn begins. A touch during the entrance waits
  /// for the entrance to end.
  final double since;

  /// The clock second of the touch itself, for the mascot's small hop.
  final double touchedAt;

  /// Which way the preview comes in: 1 from the right (a swipe to the
  /// next), -1 from the left (a swipe to the previous), 0 in place (a tap).
  final int direction;

  /// How far the finger had pulled the preview sideways when it let go, in
  /// points. The preview on its way out leaves from there.
  final double pull;

  /// What the hand had chosen before this, so the stage knows what this
  /// turn comes in over. Null when the loop was untouched.
  final HeroHand? before;

  /// This choice with nothing remembered before it.
  HeroHand get alone => HeroHand(
    index: index,
    since: since,
    touchedAt: touchedAt,
    direction: direction,
    pull: pull,
  );
}

/// How far the loop is behind the clock, because it waits while a finger
/// is down on the stage.
///
/// The loop reads [loopSeconds] in place of the clock. That second stands
/// still for as long as the finger is down and goes on from there when it
/// lifts, so a turn never ends under a finger. The entrance does not wait.
class HeroWait {
  const HeroWait({this.waited = 0, this.downAt});

  /// The seconds waited under fingers that have lifted.
  final double waited;

  /// The clock second the finger now on the stage counts from. Null when
  /// none is down.
  final double? downAt;

  /// A finger goes down at clock second [t]. One that lands during the
  /// entrance counts from the entrance's end: pass [HeroLoop.entranceEnd]
  /// as [entranceEnd] for a loop with a beat of its own before it.
  HeroWait down(double t, {double entranceEnd = heroEntranceSeconds}) =>
      downAt != null
      ? this
      : HeroWait(waited: waited, downAt: t < entranceEnd ? entranceEnd : t);

  /// The finger lifts at clock second [t].
  HeroWait up(double t) => downAt == null ? this : HeroWait(waited: behind(t));

  /// How many seconds the loop is behind the clock at clock second [t].
  double behind(double t) {
    final since = downAt;
    return waited + (since == null || t < since ? 0 : t - since);
  }

  /// The second the loop is at when the clock is at [t].
  double loopSeconds(double t) => t - behind(t);
}

/// One turn as it falls on the clock: whose it is, when it began and
/// whether the hand chose it.
class _Turn {
  const _Turn(this.scene, this.began, {this.hand, this.cameAfter});

  final HeroScene scene;

  /// The clock second the turn began.
  final double began;

  /// The choice that started this turn. Null for a turn of the loop.
  final HeroHand? hand;

  /// For the first turn of the loop after a hold: the choice it follows.
  final HeroHand? cameAfter;

  bool get byHand => hand != null;
}

/// The whole loop of a stage: the turns in order, and every frame as a
/// function of the clock and of what the hand last chose. It holds no
/// timer and no state.
///
/// The default constructor is the approved loop for a product's benefits.
/// [HeroLoop.turns] takes a table a layout wrote itself and behaves the
/// same way: the hand, the hold, the wait and the resting frame all work.
class HeroLoop {
  /// One turn per preview in [previews], each with its approved script. A
  /// script in [scripts] replaces the approved one for that preview.
  ///
  /// [prelude] is how many seconds of its own a layout plays before the
  /// entrance (see [entranceEnd]). [holdSeconds] is how long a chosen turn
  /// holds on its finished frame.
  HeroLoop(
    List<PaywallPreviewId> previews, {
    Map<PaywallPreviewId, HeroScript> scripts = const {},
    this.prelude = 0,
    this.holdSeconds = heroHandHoldSeconds,
  }) : scenes = _scenesOf([
         for (final preview in previews)
           HeroTurn(
             heroScriptFor(preview, count: previews.length, own: scripts),
             preview: preview,
           ),
       ]);

  /// A loop of a layout's own [turns], in order: which preview (or none),
  /// how long, which faces at which beats, which props.
  HeroLoop.turns(
    List<HeroTurn> turns, {
    this.prelude = 0,
    this.holdSeconds = heroHandHoldSeconds,
  }) : scenes = _scenesOf(turns);

  static List<HeroScene> _scenesOf(List<HeroTurn> turns) {
    final scenes = <HeroScene>[];
    var start = 0.0;
    for (final (i, turn) in turns.indexed) {
      scenes.add(
        HeroScene(
          index: i,
          preview: turn.preview,
          start: start,
          script: turn.script,
        ),
      );
      start += turn.script.seconds;
    }
    return scenes;
  }

  final List<HeroScene> scenes;

  /// Seconds a layout plays of its own before the entrance starts: a gag,
  /// a title card. Until then every frame is the entrance at zero, which
  /// draws nothing on the stage. Zero for the approved composition.
  final double prelude;

  /// How long a turn the hand chose holds on its finished frame before the
  /// loop moves on.
  final double holdSeconds;

  /// The clock second the entrance is over and the first turn starts. Give
  /// it to the frame as `restAt`.
  double get entranceEnd => prelude + heroEntranceSeconds;

  /// Seconds in one pass through every benefit.
  double get period => scenes.isEmpty ? 0 : scenes.last.end;

  /// The benefit that has the stage at [t], or will have it as soon as the
  /// entrance ends.
  int chosenAt(double t, {HeroHand? hand}) {
    if (scenes.isEmpty) return 0;
    if (hand != null && t < hand.since) return hand.index;
    return _turnAt(t, hand)?.scene.index ?? 0;
  }

  /// The hand's choice after a touch at clock second [t].
  ///
  /// Give [index] for a tap on a line, or [step] for a swipe: 1 is the
  /// next benefit and -1 the previous, wrapping at the ends. Neither is a
  /// tap on the stage, which plays the current benefit again. [hand] is
  /// the choice in force before the touch. Null when there is no benefit.
  ///
  /// A touch during the entrance waits: the entrance plays to its end and
  /// the chosen turn begins there.
  HeroHand? touch(
    double t, {
    HeroHand? hand,
    int? index,
    int step = 0,
    double pull = 0,
    bool isStill = false,
  }) {
    if (scenes.isEmpty) return null;
    final count = scenes.length;
    final target = index ?? chosenAt(t, hand: hand) + step;
    // A choice that never began leaves no trace.
    final settled = hand != null && t < hand.since ? hand.before : hand;
    return HeroHand(
      index: (target % count + count) % count,
      since: isStill || t >= entranceEnd ? t : entranceEnd,
      touchedAt: t,
      direction: index == null ? step.sign : 0,
      pull: pull,
      before: settled?.alone,
    );
  }

  /// The clock second the loop takes over again after [hand]: when the
  /// benefit after the chosen one starts its turn.
  double resumesAt(HeroHand hand) =>
      hand.since +
      scenes[hand.index % scenes.length].script.seconds +
      holdSeconds;

  /// The turn on the stage at [t]. Null during the entrance of an
  /// untouched loop is never returned: the first turn stands in for it.
  _Turn? _turnAt(double t, HeroHand? hand) {
    if (scenes.isEmpty) return null;
    if (hand != null && t < hand.since) return _turnAt(t, hand.before);

    if (hand != null) {
      final scene = scenes[hand.index % scenes.length];
      final resume = resumesAt(hand);
      if (t < resume) return _Turn(scene, hand.since, hand: hand);

      // The loop again, from the benefit after the chosen one.
      final next = scenes[(scene.index + 1) % scenes.length];
      final run = next.start + (t - resume);
      final pass = (run / period).floor();
      final local = run - pass * period;
      var now = scenes.first;
      for (final s in scenes) {
        if (local >= s.start) now = s;
      }
      return _Turn(
        now,
        resume + pass * period + now.start - next.start,
        cameAfter: pass == 0 && now.index == next.index ? hand : null,
      );
    }

    final run = (t < entranceEnd ? entranceEnd : t) - entranceEnd;
    final pass = (run / period).floor();
    final local = run - pass * period;
    var now = scenes.first;
    for (final s in scenes) {
      if (local >= s.start) now = s;
    }
    return _Turn(now, entranceEnd + pass * period + now.start);
  }

  /// The turn that [turn] came in over, or null when nothing was there:
  /// the first turn of all, and a lone benefit going round by itself.
  _Turn? _before(_Turn turn) {
    if (turn.hand case final hand?) return _turnAt(hand.since, hand.before);
    if (turn.cameAfter case final hand?) {
      return _Turn(scenes[hand.index % scenes.length], hand.since, hand: hand);
    }
    if (scenes.length == 1) return null;
    if (turn.scene.index == 0 && turn.began <= entranceEnd) {
      return null;
    }
    final previous =
        scenes[(turn.scene.index + scenes.length - 1) % scenes.length];
    return _Turn(previous, turn.began - previous.script.seconds);
  }

  /// How far into its script [turn] is at [t]. A turn the hand chose stops
  /// at its end and holds there.
  static double _since(_Turn turn, double t) {
    final elapsed = t - turn.began;
    final seconds = turn.scene.script.seconds;
    return turn.byHand && elapsed > seconds ? seconds : elapsed;
  }

  /// The clock second [turn]'s preview is cued at, as seen at [t]. While a
  /// chosen turn holds, the cue moves with the clock, so the preview stays
  /// on its finished frame.
  static double _cue(_Turn turn, double t) {
    final script = turn.scene.script;
    final elapsed = t - turn.began;
    if (turn.byHand && elapsed > script.seconds) {
      return t - script.seconds - script.lead;
    }
    return turn.began - script.lead;
  }

  static HeroBeat _beatAt(HeroScript script, double since) {
    var beat = script.beats.first;
    for (final b in script.beats) {
      if (since >= b.at) beat = b;
    }
    return beat;
  }

  /// The frame at clock second [t]. With [isStill] it is the resting frame
  /// whatever the clock says. [hand] is what the hand last chose.
  HeroFrame frameAt(double t, {bool isStill = false, HeroHand? hand}) {
    if (scenes.isEmpty) return HeroFrame.empty;
    if (isStill) return restFor(hand?.index ?? 0);

    final touchHop = hand == null
        ? 0.0
        : heroTouchHopHeight *
              _arc(
                phase(
                  t,
                  hand.touchedAt,
                  hand.touchedAt + heroTouchHopSeconds,
                ),
              );

    if (t < entranceEnd) {
      // A layout's own beat comes first. Then the mascot lands startled
      // and is glad by the end of the entrance.
      final local = t < prelude ? 0.0 : t - prelude;
      return HeroFrame(
        scene: scenes.first,
        previous: null,
        sceneSeconds: 0,
        cardEnter: 1,
        playFrom: entranceEnd - scenes.first.script.lead,
        previousPlayFrom: null,
        turn: entranceEnd,
        previousTurn: null,
        fromFace: HeroFace.arriving,
        face: HeroFace.glad,
        faceBlend: phase(local, 0.55, 0.85),
        props: const {},
        hop: touchHop,
        blink: 0,
        entrance: local / heroEntranceSeconds,
        bob: 0,
        progress: 0,
        isHeld: false,
        direction: 0,
        pull: 0,
      );
    }

    final turn = _turnAt(t, hand)!;
    final scene = turn.scene;
    final script = scene.script;
    final previous = _before(turn);
    final elapsed = t - turn.began;
    final since = _since(turn, t);
    final run = t - entranceEnd;

    // The face: the last beat that has started, blending in from the one
    // before it. The first beat of a turn comes from the face the stage
    // had when the turn began.
    final beats = script.beats;
    final beat = _beatAt(script, since);
    final beatIndex = beats.indexOf(beat);
    final HeroFace fromFace;
    if (beatIndex > 0) {
      fromFace = beats[beatIndex - 1].face;
    } else if (previous != null) {
      fromFace = _beatAt(
        previous.scene.script,
        _since(previous, turn.began),
      ).face;
    } else {
      fromFace = scenes.length == 1 && turn.began > entranceEnd
          ? beats.last.face
          : HeroFace.glad;
    }

    // A prop goes on at its time and comes off as the turn ends. A chosen
    // turn keeps it on through the hold.
    final stay = turn.byHand ? script.seconds + holdSeconds : script.seconds;
    final props = <HeroProp, double>{};
    for (final MapEntry(key: prop, value: at) in script.props.entries) {
      final on = phase(since, at, at + heroPropBlend);
      final early = script.propsOff[prop];
      final off = early != null
          ? phase(since, early, early + heroPropBlend)
          : phase(elapsed, stay - heroPropBlend, stay);
      final amount = on * (1 - off);
      if (amount > 0) props[prop] = amount;
    }

    final reaction = beat.isReaction
        ? _arc(phase(since, beat.at, beat.at + heroHopSeconds))
        : 0.0;

    return HeroFrame(
      scene: scene,
      previous: previous?.scene,
      sceneSeconds: since,
      cardEnter: previous == null ? 1 : phase(elapsed, 0, heroCardBlend),
      playFrom: _cue(turn, t),
      previousPlayFrom: previous == null ? null : _cue(previous, t),
      turn: turn.began,
      previousTurn: previous?.began,
      fromFace: fromFace,
      face: beat.face,
      faceBlend: phase(since, beat.at, beat.at + heroFaceBlend),
      props: props,
      hop: reaction > touchHop ? reaction : touchHop,
      blink: heroBlinkAt(run),
      entrance: 1,
      bob: run,
      progress: phase(since, 0, script.seconds),
      isHeld: turn.byHand && elapsed >= script.seconds,
      direction: turn.hand?.direction ?? 0,
      pull: turn.hand?.pull ?? 0,
    );
  }

  /// The frame shown when nothing may move: the first benefit, the mascot
  /// glad, nothing worn, nothing half way.
  HeroFrame get rest => restFor(0);

  /// The resting frame with the benefit at [index] on the stage: what a
  /// touch cuts to when nothing may move.
  HeroFrame restFor(int index) {
    final scene = scenes[index % scenes.length];
    return HeroFrame(
      scene: scene,
      previous: null,
      sceneSeconds: 0,
      cardEnter: 1,
      playFrom: entranceEnd,
      previousPlayFrom: null,
      turn: 0,
      previousTurn: null,
      fromFace: HeroFace.glad,
      face: HeroFace.glad,
      faceBlend: 1,
      props: const {},
      hop: 0,
      blink: 0,
      entrance: 1,
      bob: 0,
      progress: 1,
      isHeld: false,
      direction: 0,
      pull: 0,
    );
  }

  /// Up and back down across a window, 0 at both ends.
  static double _arc(double p) => 4 * p * (1 - p);
}

/// How far the eyes are shut by a blink at [seconds] on any clock, 0 to 1.
/// The loop blinks with it, and so can a mascot drawn outside a stage.
double heroBlinkAt(double seconds) {
  final local = loopT(seconds, heroBlinkEvery);
  const start = heroBlinkEvery - heroBlinkSeconds;
  if (local < start) return 0;
  final p = phase(local, start, heroBlinkEvery);
  return 4 * p * (1 - p);
}

/// Everything the stage draws at one moment.
class HeroFrame {
  const HeroFrame({
    required this.scene,
    required this.previous,
    required this.sceneSeconds,
    required this.cardEnter,
    required this.playFrom,
    required this.previousPlayFrom,
    required this.turn,
    required this.previousTurn,
    required this.fromFace,
    required this.face,
    required this.faceBlend,
    required this.props,
    required this.hop,
    required this.blink,
    required this.entrance,
    required this.bob,
    required this.progress,
    required this.isHeld,
    required this.direction,
    required this.pull,
  });

  /// A product with nothing to show.
  static const HeroFrame empty = HeroFrame(
    scene: null,
    previous: null,
    sceneSeconds: 0,
    cardEnter: 1,
    playFrom: 0,
    previousPlayFrom: null,
    turn: 0,
    previousTurn: null,
    fromFace: HeroFace.glad,
    face: HeroFace.glad,
    faceBlend: 1,
    props: {},
    hop: 0,
    blink: 0,
    entrance: 1,
    bob: 0,
    progress: 0,
    isHeld: false,
    direction: 0,
    pull: 0,
  );

  /// This frame for a loop that is [seconds] behind the clock: the
  /// previews are cued that much later, so they wait with the loop.
  HeroFrame behind(double seconds) => seconds == 0
      ? this
      : HeroFrame(
          scene: scene,
          previous: previous,
          sceneSeconds: sceneSeconds,
          cardEnter: cardEnter,
          playFrom: playFrom + seconds,
          previousPlayFrom: switch (previousPlayFrom) {
            final from? => from + seconds,
            null => null,
          },
          turn: turn,
          previousTurn: previousTurn,
          fromFace: fromFace,
          face: face,
          faceBlend: faceBlend,
          props: props,
          hop: hop,
          blink: blink,
          entrance: entrance,
          bob: bob,
          progress: progress,
          isHeld: isHeld,
          direction: direction,
          pull: pull,
        );

  /// The turn playing. Null only for a loop with no turn.
  final HeroScene? scene;

  /// The benefit on its way out, while its preview fades. Null otherwise.
  final HeroScene? previous;

  /// Seconds since [scene] started. A chosen turn stops at its end.
  final double sceneSeconds;

  /// How far [scene]'s preview has come in over [previous]'s, 0 to 1.
  final double cardEnter;

  /// The clock second the preview's loop started at.
  final double playFrom;

  /// The same for the preview on its way out, so it carries on from where
  /// it was while it fades.
  final double? previousPlayFrom;

  /// The clock second this turn began, and the one before it. Each names
  /// one turn, so a benefit played twice in a row is two pictures.
  final double turn;
  final double? previousTurn;

  /// The face is [faceBlend] of the way from [fromFace] to [face].
  final HeroFace fromFace;
  final HeroFace face;
  final double faceBlend;

  /// How far on each worn prop is, 0 to 1. A prop not in the map is off.
  final Map<HeroProp, double> props;

  /// How high the mascot is in its hop, 0 to 1.
  final double hop;

  /// How far the eyes are shut by a blink, 0 to 1.
  final double blink;

  /// How far through the entrance, 0 to 1.
  final double entrance;

  /// The seconds the idle bob reads. Zero holds the mascot level.
  final double bob;

  /// How far the turn has played, 0 to 1. The current pip fills with it.
  final double progress;

  /// True while a chosen turn holds on its finished frame.
  final bool isHeld;

  /// Which way this turn's preview came in: 1 from the right, -1 from the
  /// left, 0 in place. [pull] is where the finger left the one before it.
  final int direction;
  final double pull;

  /// Which benefit's line is emphasised in the list.
  int get activeIndex => scene?.index ?? 0;
}

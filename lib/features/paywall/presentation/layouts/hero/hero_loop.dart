import 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';
import 'package:critalarm/features/paywall/presentation/layouts/kit/paywall_clock.dart';

// The Hero layout's loop, as numbers: which benefit plays when, what the
// face does about it, and what the frame is when nothing may move. No
// widget is in here, so every row of the table has a test.

/// The faces the mascot makes on the stage. The widget turns each into a
/// shape, so the table can be read and tested without drawing anything.
enum HeroFace {
  /// The entrance: eyes wide, just landed.
  arriving,

  /// Glad. The resting face.
  glad,

  /// Eyes on the card, a small smile.
  watching,

  /// One brow up at something that will not go through.
  doubtful,

  /// Leaning in: wide eyes, brows up.
  keen,

  /// Working something out.
  thinking,

  /// Startled by a ring.
  startled,

  /// A small win: dot eyes, an open smile, lines popping above.
  winning,

  /// Pleased with itself.
  proud,

  /// A wink.
  winking,

  /// Half a smile, for behind a pair of shades.
  cool,

  /// Relief: eyes shut, a puff of breath let go.
  relieved,

  /// Listening: eyes shut, a small easy smile.
  listening,

  /// Taken with something: soft eyes and a heart above the head.
  loving,
}

/// What the mascot wears.
enum HeroProp { crown, shades, headphones, bowTie }

/// One change of face inside a scene, [at] seconds after the scene starts.
class HeroBeat {
  const HeroBeat(this.at, this.face, {this.isReaction = false});

  final double at;
  final HeroFace face;

  /// True for the beat where the feature has done its job: the mascot
  /// hops.
  final bool isReaction;
}

/// One benefit's turn on the stage.
class HeroScript {
  const HeroScript({
    required this.seconds,
    required this.beats,
    this.lead = 0,
    this.props = const {},
    this.propsOff = const {},
  });

  /// How long the turn lasts.
  final double seconds;

  /// How far into its own loop the preview already is when the turn
  /// starts, so the part worth watching falls inside the turn.
  final double lead;

  /// The faces, in order. The first is at zero.
  final List<HeroBeat> beats;

  /// When each prop goes on, in seconds after the turn starts. It comes off
  /// as the turn ends, unless [propsOff] takes it off sooner.
  final Map<HeroProp, double> props;

  /// When a prop comes off before the turn ends, to make room for the
  /// next one.
  final Map<HeroProp, double> propsOff;
}

/// The entrance is over and the first turn starts at this second.
const double heroEntranceSeconds = 1;

/// How long one face takes to become the next.
const double heroFaceBlend = 0.24;

/// How long one preview takes to give way to the next.
const double heroCardBlend = 0.32;

/// How long a prop takes to land, and to leave before the turn ends.
const double heroPropBlend = 0.3;

/// How long the hop after a reaction lasts.
const double heroHopSeconds = 0.42;

/// After a touch, the chosen benefit plays its turn and then holds on its
/// finished frame for this long before the loop moves on.
const double heroHandHoldSeconds = 4;

/// The small hop the mascot gives on any touch: how long it lasts, and how
/// high it goes against the hop of a reaction.
const double heroTouchHopSeconds = 0.3;
const double heroTouchHopHeight = 0.55;

/// Seconds between blinks, and how long one lasts.
const double heroBlinkEvery = 3.1;
const double heroBlinkSeconds = 0.16;

/// The turn of each benefit when it shares the stage with others. The
/// times follow what the preview is doing at that moment. Every preview
/// has one.
const Map<PaywallPreviewId, HeroScript> _scripts = {
  // A third switch is refused, then goes on.
  PaywallPreviewId.topics: HeroScript(
    seconds: 2.4,
    lead: 0.3,
    beats: [
      HeroBeat(0, HeroFace.watching),
      HeroBeat(0.8, HeroFace.doubtful),
      HeroBeat(1.85, HeroFace.glad, isReaction: true),
    ],
  ),
  // The count stalls at the free limit, then runs to the Hosted one.
  PaywallPreviewId.pushes: HeroScript(
    seconds: 2.6,
    lead: 0.5,
    beats: [
      HeroBeat(0, HeroFace.watching),
      HeroBeat(0.75, HeroFace.keen),
      HeroBeat(2.1, HeroFace.winning, isReaction: true),
    ],
  ),
  // The list stops at the free limit, the limit lifts, the list goes on.
  PaywallPreviewId.history: HeroScript(
    seconds: 2.4,
    lead: 0.3,
    beats: [
      HeroBeat(0, HeroFace.watching),
      HeroBeat(0.8, HeroFace.thinking),
      HeroBeat(1.45, HeroFace.proud, isReaction: true),
    ],
  ),
  // The widget rings, its button is pressed, it is awake.
  PaywallPreviewId.widgets: HeroScript(
    seconds: 2.3,
    lead: 1.5,
    beats: [
      HeroBeat(0, HeroFace.startled),
      HeroBeat(1.1, HeroFace.winking, isReaction: true),
    ],
  ),
  // The icon gets its crown, and so does the mascot. Then the shades.
  PaywallPreviewId.appIcons: HeroScript(
    seconds: 2.3,
    lead: 2.3,
    beats: [
      HeroBeat(0, HeroFace.watching),
      HeroBeat(0.7, HeroFace.keen),
      HeroBeat(1.2, HeroFace.cool, isReaction: true),
    ],
    props: {HeroProp.crown: 0.7, HeroProp.shades: 1.2},
  ),
  // The alarm rings behind a locked button. The code is scanned, the lock
  // opens and the alarm stops: a breath let go.
  PaywallPreviewId.wakeUpChallenges: HeroScript(
    seconds: 3.1,
    lead: 0.15,
    beats: [
      HeroBeat(0, HeroFace.startled),
      HeroBeat(0.6, HeroFace.keen),
      HeroBeat(2.35, HeroFace.relieved, isReaction: true),
    ],
  ),
  // A push leaves the relay, reaches the phone, and this week is ticked.
  PaywallPreviewId.weeklyCheck: HeroScript(
    seconds: 2.6,
    lead: 1.6,
    beats: [
      HeroBeat(0, HeroFace.watching),
      HeroBeat(0.3, HeroFace.keen),
      HeroBeat(1.6, HeroFace.winning, isReaction: true),
    ],
  ),
  // The record button goes down and the mascot puts headphones on to
  // listen. The take becomes a sound of its own, and it loves it.
  PaywallPreviewId.customSounds: HeroScript(
    seconds: 3.2,
    lead: 0.3,
    beats: [
      HeroBeat(0, HeroFace.watching),
      HeroBeat(0.35, HeroFace.listening),
      HeroBeat(2.45, HeroFace.loving, isReaction: true),
    ],
    props: {HeroProp.headphones: 0.3},
  ),
  // The alarm screen tries on its looks and the mascot dresses to match:
  // shades for the dark one, a bow tie for the poster.
  PaywallPreviewId.customAlarmScreens: HeroScript(
    seconds: 3,
    lead: 0.9,
    beats: [
      HeroBeat(0, HeroFace.watching),
      HeroBeat(0.6, HeroFace.cool),
      HeroBeat(2.1, HeroFace.proud, isReaction: true),
    ],
    props: {HeroProp.shades: 0.6, HeroProp.bowTie: 2.1},
    propsOff: {HeroProp.shades: 1.8},
  ),
};

/// The one benefit of a product that has only one: its turn is the
/// preview's whole loop, so the picture never jumps.
const Map<PaywallPreviewId, HeroScript> _soloScripts = {
  // Earlier weeks pass, a push travels to the phone, this week is ticked.
  PaywallPreviewId.weeklyCheck: HeroScript(
    seconds: 9,
    beats: [
      HeroBeat(0, HeroFace.watching),
      HeroBeat(1.9, HeroFace.keen),
      HeroBeat(3.3, HeroFace.winning, isReaction: true),
      HeroBeat(4.6, HeroFace.glad),
      HeroBeat(6.2, HeroFace.proud),
      HeroBeat(7.8, HeroFace.glad),
    ],
  ),
};

/// The script [preview] plays when it is one of [count] benefits.
HeroScript heroScriptFor(PaywallPreviewId preview, {required int count}) {
  if (count == 1) {
    final solo = _soloScripts[preview];
    if (solo != null) return solo;
  }
  return _scripts[preview]!;
}

/// One benefit's turn, placed in the loop.
class HeroScene {
  const HeroScene({
    required this.index,
    required this.preview,
    required this.start,
    required this.script,
  });

  /// Which benefit, in the order the product lists them.
  final int index;
  final PaywallPreviewId preview;

  /// Seconds into the loop this turn starts.
  final double start;
  final HeroScript script;

  double get end => start + script.seconds;
}

/// What the hand last chose. With none, the loop is a function of the
/// clock alone.
///
/// The benefit at [index] takes the stage at [since], plays its turn from
/// the beginning, holds on its finished frame for [heroHandHoldSeconds],
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

/// The whole loop for one product's benefits, in order.
class HeroLoop {
  HeroLoop(List<PaywallPreviewId> previews) : scenes = _scenesOf(previews);

  static List<HeroScene> _scenesOf(List<PaywallPreviewId> previews) {
    final scenes = <HeroScene>[];
    var start = 0.0;
    for (final (i, preview) in previews.indexed) {
      final script = heroScriptFor(preview, count: previews.length);
      scenes.add(
        HeroScene(index: i, preview: preview, start: start, script: script),
      );
      start += script.seconds;
    }
    return scenes;
  }

  final List<HeroScene> scenes;

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
      since: isStill || t >= heroEntranceSeconds ? t : heroEntranceSeconds,
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
      heroHandHoldSeconds;

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

    final run =
        (t < heroEntranceSeconds ? heroEntranceSeconds : t) -
        heroEntranceSeconds;
    final pass = (run / period).floor();
    final local = run - pass * period;
    var now = scenes.first;
    for (final s in scenes) {
      if (local >= s.start) now = s;
    }
    return _Turn(now, heroEntranceSeconds + pass * period + now.start);
  }

  /// The turn that [turn] came in over, or null when nothing was there:
  /// the first turn of all, and a lone benefit going round by itself.
  _Turn? _before(_Turn turn) {
    if (turn.hand case final hand?) return _turnAt(hand.since, hand.before);
    if (turn.cameAfter case final hand?) {
      return _Turn(scenes[hand.index % scenes.length], hand.since, hand: hand);
    }
    if (scenes.length == 1) return null;
    if (turn.scene.index == 0 && turn.began <= heroEntranceSeconds) {
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

    if (t < heroEntranceSeconds) {
      // The mascot lands startled and is glad by the end of the entrance.
      return HeroFrame(
        scene: scenes.first,
        previous: null,
        sceneSeconds: 0,
        cardEnter: 1,
        playFrom: heroEntranceSeconds - scenes.first.script.lead,
        previousPlayFrom: null,
        turn: heroEntranceSeconds,
        previousTurn: null,
        fromFace: HeroFace.arriving,
        face: HeroFace.glad,
        faceBlend: phase(t, 0.55, 0.85),
        props: const {},
        hop: touchHop,
        blink: 0,
        entrance: t / heroEntranceSeconds,
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
    final run = t - heroEntranceSeconds;

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
      fromFace = scenes.length == 1 && turn.began > heroEntranceSeconds
          ? beats.last.face
          : HeroFace.glad;
    }

    // A prop goes on at its time and comes off as the turn ends. A chosen
    // turn keeps it on through the hold.
    final stay = turn.byHand
        ? script.seconds + heroHandHoldSeconds
        : script.seconds;
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
      blink: _blink(run),
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
      playFrom: heroEntranceSeconds,
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

  /// How far the eyes are shut at [run] seconds into the loop.
  static double _blink(double run) {
    final local = loopT(run, heroBlinkEvery);
    const start = heroBlinkEvery - heroBlinkSeconds;
    if (local < start) return 0;
    return _arc(phase(local, start, heroBlinkEvery));
  }
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

  /// The benefit playing. Null only for a product with no benefit.
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

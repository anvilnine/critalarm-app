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
}

/// What the mascot wears.
enum HeroProp { crown, shades }

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
  });

  /// How long the turn lasts.
  final double seconds;

  /// How far into its own loop the preview already is when the turn
  /// starts, so the part worth watching falls inside the turn.
  final double lead;

  /// The faces, in order. The first is at zero.
  final List<HeroBeat> beats;

  /// When each prop goes on, in seconds after the turn starts. It comes off
  /// as the turn ends.
  final Map<HeroProp, double> props;
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

/// Seconds between blinks, and how long one lasts.
const double heroBlinkEvery = 3.1;
const double heroBlinkSeconds = 0.16;

/// A turn for a benefit with no script of its own.
const HeroScript _plainScript = HeroScript(
  seconds: 2.4,
  beats: [
    HeroBeat(0, HeroFace.watching),
    HeroBeat(1.2, HeroFace.glad, isReaction: true),
  ],
);

/// The turn of each benefit when it shares the stage with others. The
/// times follow what the preview is doing at that moment.
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
  return _scripts[preview] ?? _plainScript;
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

  /// The frame at clock second [t]. With [isStill] it is the resting frame
  /// whatever the clock says.
  HeroFrame frameAt(double t, {bool isStill = false}) {
    if (scenes.isEmpty) return HeroFrame.empty;
    if (isStill) return rest;

    if (t < heroEntranceSeconds) {
      // The mascot lands startled and is glad by the end of the entrance.
      return HeroFrame(
        scene: scenes.first,
        previous: null,
        sceneSeconds: 0,
        cardEnter: 1,
        playFrom: _playFrom(scenes.first, 0),
        fromFace: HeroFace.arriving,
        face: HeroFace.glad,
        faceBlend: phase(t, 0.55, 0.85),
        props: const {},
        hop: 0,
        blink: 0,
        entrance: t / heroEntranceSeconds,
        bob: 0,
      );
    }

    final run = t - heroEntranceSeconds;
    final pass = (run / period).floor();
    final local = run - pass * period;
    var scene = scenes.first;
    for (final s in scenes) {
      if (local >= s.start) scene = s;
    }
    final since = local - scene.start;
    final isFirstTurn = pass == 0 && scene.index == 0;
    final previous = scenes.length == 1 || isFirstTurn
        ? null
        : scenes[(scene.index + scenes.length - 1) % scenes.length];

    // The face: the last beat that has started, blending in from the one
    // before it. The first beat of a turn comes from the last face of the
    // turn before, or from the entrance's glad face.
    final beats = scene.script.beats;
    var beatIndex = 0;
    for (final (i, beat) in beats.indexed) {
      if (since >= beat.at) beatIndex = i;
    }
    final beat = beats[beatIndex];
    final fromFace = beatIndex > 0
        ? beats[beatIndex - 1].face
        : previous?.script.beats.last.face ??
              (scenes.length == 1 && pass > 0
                  ? beats.last.face
                  : HeroFace.glad);

    final props = <HeroProp, double>{};
    for (final MapEntry(key: prop, value: at) in scene.script.props.entries) {
      final on = phase(since, at, at + heroPropBlend);
      final off = phase(
        since,
        scene.script.seconds - heroPropBlend,
        scene.script.seconds,
      );
      final amount = on * (1 - off);
      if (amount > 0) props[prop] = amount;
    }

    return HeroFrame(
      scene: scene,
      previous: previous,
      sceneSeconds: since,
      cardEnter: previous == null ? 1 : phase(since, 0, heroCardBlend),
      playFrom: _playFrom(scene, pass),
      fromFace: fromFace,
      face: beat.face,
      faceBlend: phase(since, beat.at, beat.at + heroFaceBlend),
      props: props,
      hop: beat.isReaction
          ? _arc(phase(since, beat.at, beat.at + heroHopSeconds))
          : 0,
      blink: _blink(run),
      entrance: 1,
      bob: run,
    );
  }

  /// The clock second at which [scene]'s preview is at the start of its
  /// loop, on pass number [pass].
  double _playFrom(HeroScene scene, int pass) =>
      heroEntranceSeconds + pass * period + scene.start - scene.script.lead;

  /// The clock second the outgoing preview of [frame] was cued at, so it
  /// carries on from where it was while it fades.
  double? previousPlayFrom(double t, HeroFrame frame) {
    final previous = frame.previous;
    if (previous == null) return null;
    final run = t - heroEntranceSeconds;
    final pass = (run / period).floor();
    // The last benefit hands over to the first of the next pass.
    final itsPass = previous.index > frame.activeIndex ? pass - 1 : pass;
    return _playFrom(previous, itsPass);
  }

  /// The frame shown when nothing may move: the first benefit, the mascot
  /// glad, nothing worn, nothing half way.
  HeroFrame get rest => HeroFrame(
    scene: scenes.first,
    previous: null,
    sceneSeconds: 0,
    cardEnter: 1,
    playFrom: heroEntranceSeconds,
    fromFace: HeroFace.glad,
    face: HeroFace.glad,
    faceBlend: 1,
    props: const {},
    hop: 0,
    blink: 0,
    entrance: 1,
    bob: 0,
  );

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
    required this.fromFace,
    required this.face,
    required this.faceBlend,
    required this.props,
    required this.hop,
    required this.blink,
    required this.entrance,
    required this.bob,
  });

  /// A product with nothing to show.
  static const HeroFrame empty = HeroFrame(
    scene: null,
    previous: null,
    sceneSeconds: 0,
    cardEnter: 1,
    playFrom: 0,
    fromFace: HeroFace.glad,
    face: HeroFace.glad,
    faceBlend: 1,
    props: {},
    hop: 0,
    blink: 0,
    entrance: 1,
    bob: 0,
  );

  /// The benefit playing. Null only for a product with no benefit.
  final HeroScene? scene;

  /// The benefit on its way out, while its preview fades. Null otherwise.
  final HeroScene? previous;

  /// Seconds since [scene] started.
  final double sceneSeconds;

  /// How far [scene]'s preview has come in over [previous]'s, 0 to 1.
  final double cardEnter;

  /// The clock second the preview's loop started at.
  final double playFrom;

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

  /// Which benefit's line is emphasised in the list.
  int get activeIndex => scene?.index ?? 0;
}

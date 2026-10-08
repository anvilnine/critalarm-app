import 'package:critalarm/features/paywall/domain/entities/paywall_preview_id.dart';

// The turn table of a stage that plays one benefit at a time: the faces
// the mascot can make, what it can wear, and one script per benefit. Only
// numbers and names, so every row has a test. A layout reuses the approved
// tables or writes its own rows with the same parts.

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

/// The approved turn of each benefit, Hosted's and Pro's, when it shares
/// the stage with others. The times follow what the preview is doing at
/// that moment. Every preview has one, so a layout can use the table as it
/// is, or hand `HeroLoop` a few scripts of its own to lay over it.
const Map<PaywallPreviewId, HeroScript> heroDefaultScripts = {
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
  // A test push leaves the relay and lands on the phone, which lights with
  // a tick. Then this week is ticked.
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
const Map<PaywallPreviewId, HeroScript> heroSoloScripts = {
  // Earlier weeks are ticked, a test push lands on the phone, this week is
  // ticked.
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

/// The script [preview] plays when it is one of [count] benefits. A script
/// in [own] wins over the approved one for that preview.
HeroScript heroScriptFor(
  PaywallPreviewId preview, {
  required int count,
  Map<PaywallPreviewId, HeroScript> own = const {},
}) {
  final mine = own[preview];
  if (mine != null) return mine;
  if (count == 1) {
    final solo = heroSoloScripts[preview];
    if (solo != null) return solo;
  }
  return heroDefaultScripts[preview]!;
}

/// One turn a layout writes for itself, for `HeroLoop.turns`: what plays
/// and the script the mascot follows while it does.
class HeroTurn {
  const HeroTurn(this.script, {this.preview});

  final HeroScript script;

  /// The preview the stage's card plays. Null for a turn whose picture the
  /// layout draws itself, through the stage's `sceneBuilder`.
  final PaywallPreviewId? preview;
}

# Paywall layout kit

Every paywall layout sells Hosted or Pro from the same parts. A layout draws its own composition
and nothing else: no button, price row, legal text, clock, benefit list or purchase call.

## Add a layout

1. Add one file, `layouts/<name>_paywall_layout.dart`, whose widget returns a `PaywallFrame`.
   Build on "Hero parts" below. `hero_paywall_layout.dart` is the worked example and the
   shortest layout there is.
2. Register it in `kit/paywall_layout_registry.dart`: `PaywallLayoutId.proof: (_) => const Proof...()`.
3. Open it at `/plans/<key>?product=hosted|pro`, or from Developer options, Paywall layouts,
   where it gets a tile that plays it. Add `&intro=<key>` to play an intro first.
   The route lists what this build has (`paywallBenefitsFor`). The developer page adds
   `&benefits=all`, which also lists what is not built yet and which only a developer build
   reads. An unregistered id draws `hero` (`paywallFallbackLayout`).
4. Import `kit/paywall_frame.dart` (buy block, clock, scope, tones), `kit/paywall_preview.dart`.

## Add an intro

An intro is a short full screen animation (1.5 to 2.5 seconds) that plays once when a paywall
opens, then hands over to whichever layout was chosen. It is not a layout: any intro goes with
any layout, and it never draws a benefit, a price or a button.

1. Add an id to `PaywallIntroId` (`lib/core/paywall/paywall_intro.dart`). The key ships in
   remote values and analytics, so it never changes.
2. Add one folder, `presentation/intros/<name>/`, with one file that holds a
   `const PaywallIntro` and the widget its `builder` returns. Keep the times in a pure timeline
   (a class of static functions of `t`) and unit test it: the order of the beats, the first
   frame, what a tap skips to, and that nothing is drawn from `seconds` on.
3. Register it in `kit/paywall_intro_registry.dart`: `PaywallIntroId.falseAlarm: falseAlarmIntro`.

```dart
const PaywallIntro falseAlarmIntro = PaywallIntro(
  seconds: FalseAlarmTimeline.end, // 1.75: the intro is taken away
  handover: FalseAlarmTimeline.handover, // 1.5: the layout's clock starts at zero
  skipTo: FalseAlarmTimeline.reveal, // 1.25: where a tap jumps to
  tone: PaywallTone.crit, // colours the close cross while it covers the screen
  score: PaywallCue.scoreFalseAlarm, // its music, started on the first frame
  beats: [PaywallIntroBeat.tap(FalseAlarmTimeline.reveal, HapticPattern.tripleRise)], // felt on the way
  skipCue: PaywallCue.introArrive, // what a tap that skips it plays
  quietAfter: FalseAlarmTimeline.reveal + paywallIntroArrivalSeconds - FalseAlarmTimeline.handover,
  tag: _tag, // () => the few words left by the layout's mascot afterwards
  builder: _build, // (context, PaywallIntroScope scope) => FalseAlarmIntro(scope: scope)
);
```

What the builder gets is a `PaywallIntroScope`: `clock` (seconds since the intro began, read it
with `PaywallClockBuilder`), `size` (the whole screen), `padding` (the safe areas), `product` and
`landing` (where the layout's own mascot stands, once the host has found it). Draw every frame
from `scope.clock` alone and hold no timer.

`intros/intro_parts.dart` has the parts the intros share: `IntroCrit` (the mascot, with its way
out), `IntroWord` (the one line), `introFaceShape` and `introStageFor`, and the props two jokes
use: `IntroAlarmRedPainter` (the red of a ringing screen, which opens in a circle),
`IntroPillButton` (a button drawn as a picture) and `IntroTouchMark` (a finger).

**The hand over is one move.** Two faces never show together. The intro's mascot is whole until
`skipTo`, then travels to `scope.landing` and shrinks to nothing at its foot, and is gone at
`handover` (`IntroCrit(leave:)`, `paywallIntroLeaveBox`). The layout's mascot pops up from that
same spot as its clock starts. The screen the intro painted is all but gone by `handover` too, so
the pop is in the open. The host finds the landing itself: the largest `FaceWidget` in the layout,
where the layout laid it out. A layout does nothing for it.

**The score.** An intro's sound is one short piece of music, a `PaywallCue` named as `score`,
started on the first frame and timed to the intro's timeline. It has three parts:

- The set up: the soft figure the joke is built on, for as long as the picture builds.
- The turn: the joke lands and the music stops dead on one tap, then a beat of nothing.
- The arrival: a short pickup from `skipTo` (the reveal) that lands on a warm chord 0.4 s later,
  as the layout starts, and rings on over its first moments.

The arrival is the same phrase for every intro and is also a cue of its own, `introArrive`. Name
it as `skipCue`, so a skipped intro plays the last part alone. A score never rings or buzzes like
an alarm: the set up is a soft musical figure. It never uses the three note call, which is
`bought`'s alone.

**Flavours.** Every score and `introArrive` comes in each `IntroSoundFlavour` (`piano`,
`kalimba`), with the same timing and one file each: `ui_score_<intro>_<flavour>.m4a`. A cue with
`hasFlavours` gets the flavour as a suffix on its file name when it is played
(`PaywallCue.assetIn`). Which flavour plays is a developer pref, `dev.paywall_intro_sound`, set by
the "Intro sound" row of the Paywall layouts screen. There is no remote value: a build with no
Developer options plays `piano`.

**Beats.** The score has the player for the whole intro, and a cue would cut it off. So the
beats of an intro with a score are haptics alone: `PaywallIntroBeat.tap(seconds, pattern)`, one
for each moment the hand should feel (a hop, a knock, the reveal). `PaywallIntroBeat(seconds, cue)`
is for an intro with no score, whose beats are its sound. The host plays each as the clock passes,
never in a tile, and never for a moment a tap skipped. The beat at the reveal is what the hand
over feels like, so the host adds no tap of its own. While a picture of an alarm rings the hand
feels nothing of the ringing: at most one light pulse for a thing that moves on it (a button
hopping), well apart, never a run.

**Quiet after.** The layout plays no cue of its own entrance for `quietAfter` seconds from the
hand over (`paywallQuietAfterIntro` by default), because the intro's last sound still has the
room. An intro with a score says `reveal + paywallIntroArrivalSeconds - handover`: the arrival
takes 1.25 s from the reveal to ring out, played through or skipped. The frame's own `open` is not
played after an intro either.

**The tag.** `tag` is what the mascot is left saying ("Just kidding."). The host draws it as a
small tag by the layout's mascot for `paywallIntroTagSeconds` after the hand over, above its head
when there is air and under its foot when there is not, and only while that mascot is there at
about full size. It takes no room and no touch, and at a large text size it is left out.

What `PaywallIntroHost` does, so an intro does not:

- The layout is built under the intro from the first frame, with its clock held at zero
  (`PaywallClockHold`). At `handover` that clock starts, so the layout's own entrance plays under
  the intro's last moments. That is the hand over: one move, never a cut.
- So an intro ends on Crit and then **uncovers** the layout between `handover` and `seconds`. It
  paints nothing where the layout should show (the false alarm clips a growing circle out of its
  red). It never paints the layout's background colour over it.
- The close cross is over the intro from the first frame, in the corner the layout keeps its own.
- A tap anywhere before `handover` moves the clock to `skipTo` (`paywallIntroSkip`). After it the
  layout takes the touch.
- Reduce motion, or a `PaywallStill`, plays no intro at all: the layout opens as it does alone.
- It plays once for each open. A rebuild does not start it again.
- The intro's `score` (or its `cue`) and its beats. None is an alarm: an intro makes
  no alarm sound, no notification and no vibration like one. A picture of a ringing screen is a
  silent picture.

A layout knows it follows an intro: `scope.intro` is the `PaywallIntroId` (`none` when none
plays, reduce motion included) and `scope.followsIntro` is true when one does. The intro ends on
the mascot, so a layout may shorten or skip its own entrance pop then. Hero plays its approved
entrance either way.

Which intro plays is a second value beside the layout: remote keys `paywall_intro` and
`pro_paywall_intro`, developer prefs `dev.paywall_intro` and `dev.pro_paywall_intro`. Empty is no
intro. An empty layout value still means the shipped surface, whatever the intro says. The
layout value `false_alarm`, from when the joke was a layout, reads as `hero` with that intro.

## Add a step after the purchase

What plays once a purchase is confirmed is a third value beside the intro and the layout, a
`PaywallThanksId`. Any one goes with any layout, for either product. `none` is the purchase
ending as it did before: Hosted goes to the welcome screen, Pro's buy block says it is on.

1. Add an id to `PaywallThanksId` (`lib/core/paywall/paywall_thanks.dart`). The key ships in
   remote values and analytics, so it never changes. Add its name to `paywallThanksNameKey`.
2. Add one folder, `presentation/thanks/<name>/`, with a pure timeline (a class of static
   functions of `t`) and one file that holds a `const PaywallThanks` and the widget its
   `builder` returns. Unit test the timeline: the order of the beats, the first frame, and that
   the frame at `seconds` is complete, with nothing half way or at an angle.
3. Register it in `kit/paywall_thanks_registry.dart`: `PaywallThanksId.confetti: confettiThanks`.

```dart
const PaywallThanks confettiThanks = PaywallThanks(
  seconds: ConfettiTimeline.end, // 2.4: the resting frame from here on
  cover: ConfettiTimeline.cover, // 0.38: it covers the whole screen from here on
  buttonAt: ConfettiTimeline.goOn, // 1.1: the host's button comes on, 1.5 at the latest
  tone: PaywallTone.canvas, // what the resting frame is painted on
  beats: confettiBeats, // (int lines) => what is felt on the way
  builder: _build, // (context, PaywallThanksScope scope) => ConfettiThanks(scope: scope)
);
```

**Second zero is the confirmed purchase.** `PaywallThanksHost` starts the clock on the frame the
buy model says the product is held after a trip to the store (`paywallThanksKindFor`), and never
before. A cancel, a failure, a restore that found nothing and a held payment start nothing.
The buy block plays `PaywallCue.bought` on that same frame, so a version never plays it. The cue
is a click, a short pick up, one swell that starts at 0.4 and peaks at 0.6, and a tail that is
over by `paywallBoughtCueSeconds` (2.2). Time the show to that.

**Beats.** `PaywallThanksBeat.tap(seconds, pattern)` is a haptic alone, which is what every beat
under the purchase cue must be. `PaywallThanksBeat(seconds, cue)` plays a cue of the palette and
belongs after 2.2. `PaywallThanks.isSound` checks it and a test asks it of every version. Keep
beats single and apart: nothing may ring or buzz like an alarm.

**It grows out of the paywall.** A `PaywallThanksScope` has `clock`, `size`, `padding`, `product`,
`benefits` (only what this build has), `origin` (the buy button that was pressed), `source` (its
middle, or a fallback), `mascot` (the layout's own mascot as it was painted) and `room` (the
screen less the safe areas and the host's button). Until `cover` the version draws over the
paywall: put a `ThanksCover` first, growing from `scope.source`, and start the mascot at
`thanksStartBox(scope.mascot)`. From `cover` on the host takes the layout away, so the version
paints every pixel. The buy block does not change to its done state under a version
(`PaywallThanksPlay`), so nothing moves as the show starts.

`thanks/thanks_parts.dart` has the shared parts: `ThanksStage` (where the mascot stands and the
words go), `ThanksCrit`, `ThanksDisc`, `ThanksCover`, `ThanksWords` (the headline and one line a
benefit, each led by a mark you draw), `ThanksCheck`, `thanksIdleFace` and `ThanksQuiet`. It also
has what more than one version draws: confetti thrown from a point (`ThanksConfetti`,
`ThanksConfettiPainter`), a slip the mascot holds (`ThanksSlipPlan`, `ThanksPaperPainter`,
`ThanksDashPainter`, `ThanksStampMark`, `thanksHands`), and the plan's limits as rows
(`limitsRowsFor`, `LimitsRow`).

What the host does, so a version does not:

- The one button, at the foot, on by `buttonAt`. It goes where the purchase went before: Hosted
  starts the app over at home, Pro closes the paywall.
- A tap anywhere skips the show to its resting frame. Skipped beats are not played.
- A restore that worked gets `ThanksQuiet`: the mascot, a check and one line. No show.
- A product that was already held gets the resting frame with no show.
- Reduce motion, or a `PaywallStill`: the frame at `seconds`, at once, with the clock still.
  Otherwise the clock runs on past `seconds`, so the mascot may blink and bob at rest.
- It plays once. The layout under it makes no sound from the first frame.
- Analytics: `paywall_thanks_shown` and `paywall_thanks_left`, and every layout event carries
  `thanks`.

Which one plays: remote keys `paywall_thanks` and `pro_paywall_thanks`, developer prefs
`dev.paywall_thanks` and `dev.pro_paywall_thanks`, the route's `?thanks=<key>`. Empty is none. An
empty layout value still means the shipped surface, whatever this says.

## The frame

`PaywallFrame(builder: (context, scope) => ...)` never scrolls. It keeps the safe areas, puts
the close cross on screen from the first frame, and pins the buy block at the bottom.

- `tone`: `PaywallTone.canvas`, `surface`, `panel`, `cobalt` or `crit`: the background and the
  text colours of the cross and the buy block. `PaywallToneColors.of` gives them to your text.
  `backdrop`: a widget drawn edge to edge behind everything. `closeOnLeft`: the cross's corner.
- `buyBlockVisible`: false hides the buy block during an entrance. It keeps its room, so
  nothing moves when it comes in. Draw a full-screen entrance in `backdrop`.
- `buyStyle`: a `PaywallBuyBlockStyle` with `tone`, `buttonVariant`, `pickerStyle` (`segments`,
  the default, or `rows`, one plan per row and 60 points taller) and `showsPicker` (false only
  when you place a `PaywallPlanPicker` yourself). A layout does not choose what the button says.
- `entranceCue`: `open` (the default), `print`, `rise`, `none`. `restAt`: the clock's resting second.

A sheet-style layout puts `PaywallFrameBody` (same options, no full screen) in its own sheet.
What it draws outside that body reads `PaywallOffer.of(context)` (`product`, `benefits`,
`source`) and a `PaywallFrameController`, made and disposed in your `State` and passed as
`controller`: `close()` does what the cross does, `buyBlockHeight` is the buy block's height as
a listenable (null for the first frame). `PaywallLayoutScope.closeCrossInset` places the cross.

## The buy block

Top to bottom, at a 20 point side inset: the plans (Hosted only, two cards 52 points tall, the
picked one cream with an ink stroke and a filled pick mark, a saving as a small ink badge
above its card), the 48 point button (`buyButtonLabel`: "Get Hosted", or Pro's name and price),
the own-server line (Hosted only), the legal line (`legalLine`), then Restore, Terms and Privacy
with 44 point tap areas. About 200 points tall for Hosted (192 with no saving) and 98 for Pro
at the default text size. The button is the only cobalt thing, the pick mark and the badge are
ink, and the billed amount is the largest price: add nothing that competes. Its text stops
growing at 1.3 times and no sentence is cut, so at a large text size the block is taller and
your layout gets less room. Use the same 20 point side inset, so the screen has one left edge.

## One benefit

A product with one benefit is not a list of one. When `scope.benefits.length == 1`, return
`PaywallOneBenefit(benefit: scope.benefits.single, headline: ...)` in place of your own
composition: a 96 point face, the headline, the preview as one card 200 points tall and the
benefit's line, never stretched (`oneBenefitSizes`). `HeroComposition` handles one by itself.

## Hero parts

The approved Hero paywall, as parts. Import `kit/paywall_hero.dart`. No part holds a timer: each
draws the frame it is handed, so the resting frame is one more frame. Compose them, never copy.
The example changes the tone, the headline and the picture beside Crit.

| Part | What it is |
|---|---|
| `HeroComposition(scope:)` | The whole approved screen: stage, pips, headline, lines. Start here. |
| `HeroLoop` | The turn table as numbers: `frameAt`, `touch`, the hold, the resting frame. |
| `HeroPlayer(clock:)` | Plays a loop and keeps what the hand chose. Every part asks it `frameAt(t)`. |
| `HeroLiveStage(player:, size:)` | The stage, playing, with swipes and taps. `HeroStage` is the still one. |
| `HeroMascot(size:, face:)` | Crit alone, anywhere: `hop`, `bob`, `blink`, `entrance`, `props`, `entranceStyle`, `idle`. |
| `HeroAtmosphere(focus:, radius:)` | The disc and what moves around it alone, in a `tone` and a `style`. |
| `HeroMotion` | The motion variants a layout picks. See "Motion variants". |
| `HeroBenefitLines(player:, metrics:)` | Check lines, the playing one strong, fixed row heights, 44 point tap areas. |
| `HeroPips(player:, count:, color:)`, `HeroRise(clock:, index:)` | One pip per turn. The words' share of the entrance: each rises after the one above. |
| `HeroTouchArea`, `HeroStageDragRecognizer` | Tap, swipe and wait for a box of your own. The drag is safe from the back swipe. |

```dart
class ReceiptPaywallLayout extends StatelessWidget {
  const ReceiptPaywallLayout({super.key});
  @override
  Widget build(BuildContext context) => PaywallFrame(
    tone: PaywallTone.surface,
    closeOnLeft: false,
    restAt: heroEntranceSeconds,
    builder: (context, scope) => HeroComposition(
      scope: scope,
      tone: PaywallTone.surface,
      headline: LocaleKeys.paywall_receipt_headline.tr(),
      // One picture per turn, in the card's place. `playFrom` cues it as it does a preview.
      sceneBuilder: (context, scene, size, playFrom) =>
          ReceiptSlip(scope.benefits[scene.index], size: size, playFrom: playFrom),
    ),
  );
}
```

- **Your own turns.** Pass `loop:`. `HeroLoop(previews, scripts: {id: HeroScript(...)})` swaps
  single turns of the approved table (`heroDefaultScripts`, Hosted and Pro).
  `HeroLoop.turns([HeroTurn(script, preview: id)])` is your own table. A `HeroScript` is
  `seconds`, `beats` (`HeroBeat(at, face, isReaction: true)` hops), `props` and `lead`.
- **Your own entrance.** `HeroLoop(..., prelude: 2.4)` keeps the stage and the words out for
  2.4 seconds, then plays the approved entrance. Draw your beat over the composition (a
  `Stack`, or the frame's `backdrop`) on the clock, end it by `prelude`, and give the frame
  `restAt: loop.entranceEnd`.
- **Your own stage.** `sceneBuilder` draws each turn's picture. `beside` is one widget for
  every turn. `arrange` places both: return a `HeroArrangement` with the mascot's and the
  card's boxes (`HeroStageKind.mascot` for Crit alone). `tone` colours the air.
- **Parts by hand.** Keep a `HeroPlayer` in your `State`, set `player.loop` in `build`, dispose
  it. Size with `heroStageRoomFor`, `HeroSizes.of` and `HeroLinesMetrics.measure`. Listen to the
  player for anything not under a `PaywallClockBuilder`: no clock ticks when nothing may move.
- **Motion variants.** Pass `motion: const HeroMotion(...)` to `HeroComposition`,
  `HeroLiveStage` or `HeroStage` (and to `HeroMascot.frame`). Each field has a default, which is
  the approved Hero, so name only what changes. Every variant is a pure function in
  `hero/hero_motion.dart`, ends flat and upright, and has the same resting frame as Hero.

  | Field | Values, the default first |
  |---|---|
  | `atmosphere: HeroAtmosphereStyle` | `drift`, `rays`, `bubbles`, `confetti`, `rings` |
  | `entrance: HeroEntranceStyle` | `pop`, `drop`, `slide`, `peek` |
  | `idle: HeroIdleStyle` | `bob`, `lean`, `benefitHop` |
  | `arrival: HeroCardArrival` | `fade`, `flip`, `slideThrough` |

  Parts used by hand take one value each: `HeroAtmosphere(style:)`,
  `HeroAtmospherePainter(style:)`, `HeroMascot(entranceStyle:, idle:, turnSeconds:)`.
- **The hand**, the same for any table: `player.touch(index:)` for a line, `touch(step:)` for a
  swipe (it wraps), `touch()` to play the turn again. The chosen turn plays from its start,
  holds `heroHandHoldSeconds`, then the loop goes on. It waits under a finger.

## The scope

`product` (`isHosted`, `isPro`), `benefits` (only what this build has, in order), `size`
(the room you have), `isCompact` (667 points tall or under), `source`, `clock`, `closeOnLeft`,
`close` (what the cross does), `intro` and `followsIntro` (see "Add an intro"). The cross covers a 44 point square in a top corner of your room:
keep words out of it. Deeper in your tree, `PaywallLayoutScope.of(context)` is the same scope.

## Previews

Draw a benefit with `benefit.title`, `benefit.line` and `PaywallPreview(benefit.previewId)`.
A preview not built yet draws a placeholder tile.
`PaywallPreview(id, size: ..., playFrom: 6)`: the second on the layout clock at which that
preview's loop starts at zero. Before it the preview holds its first frame. To build one, add
it to `paywallPreviewBuilders` and read time through `PaywallPreviewClock` (or `.seconds`).

## The clock

One number, seconds since the layout appeared. Work out every position and fade from it.
`PaywallClockBuilder(clock: scope.clock, builder: (context, t, child) => ...)` redraws one
part every frame. Or extend `PaywallClockState<T>`, read `t` in `build`, override `restAt`.
`phase(t, start, end)` is 0 to 1 across a window, `loopT(t, period)` wraps, and
`stagger(i, t, each: 0.08)` is the clock as item `i` sees it.

With reduce motion on, or under a `PaywallStill`, `t` is `restAt` and no ticker runs. That frame
must be complete: nothing hidden, half way or at an angle. The clock stops under another route,
and waits at zero under a `PaywallClockHold` (an intro puts one over the layout).

## Tiles

`PaywallLayoutTile(layout:, product:, label:)`, `PaywallIntroTile(intro:, product:, label:)` and
`PaywallThanksTile(thanks:, product:, label:)` (which buys on the demo model after a moment)
draw the real layout (and intro) at 390 by 844 on the demo buy model, scaled down with a
`FittedBox`. A tile takes no touch of its own, plays no cue (`PaywallMuted`), and an intro tile
starts again every few seconds. Its clock runs only while the tile is built, so put tiles in a
lazy list with no cache: the developer picker shows about three at once.

## Cues

A cue is a sound and its haptic together, by name: `PaywallCue` in
`lib/core/ui_sound/paywall_cues.dart`. One cue per moment, and never a raw `AppHaptics` call
beside one. `playPaywallCue(PaywallCue.swap)` plays one from a touch.

Three cues mark the three moments of every paywall, and no two may sound alike. A person should
be able to name the moment with eyes shut:

| Cue | Moment | Lead voice | Shape | Ends | Haptic |
|---|---|---|---|---|---|
| `open` | The paywall arrives and asks | A tine, struck once | Level: one strike, all of it in the first 30 ms | Hanging, on the second and the fifth | `light` |
| `bought` | The purchase is confirmed | Mallets, with a bell on top | Rising, into the three note call | Home, on the tonic | `risingPair` |
| `close` | Left without buying | A music box, three single notes | Held, a fall of a third, a lift of a step at the very end | Open, on the second | `fallingPair` |

- `open` is never a reward: no mallet, nothing that climbs, no tonic, no sparkle. Six layouts
  play their next cue about 0.3 s later, so its identity sits at the very start.
- `bought` is the only celebration and the one place the call plays in full. Its clock is fixed,
  because the step after a purchase is drawn to it: a click at 0, a swell from 0.40 s to a peak
  at 0.60 s, silence by 2.15 s.
- `close` is a little let down and kind about it: a small musical sigh, "oh... okay". F sharp 5
  held, D5, then E5, each softer, the last a lift like a shrug. Every note is above 500 Hz, so a
  phone speaker plays it, and it sits just under `open` in loudness. `error` is two low mallet
  notes stepping down, E4 then C sharp 4 ("that did not work"), so the two are never confused.
  It never mocks: nothing minor, nothing low, no last thud.

An intro has a score, one for each intro, in each flavour. All of one flavour end on the same
arrival, which is also `introArrive`:

| Cue | Intro | Set up | The turn |
|---|---|---|---|
| `scoreFalseAlarm` | False alarm | The soft ringing figure, in two bursts as the picture rings | The tap as the ringing stops |
| `scoreSnooze` | Snooze snack | The figure growing, a new bar on each hop of the button | The tap on the gulp |
| `scoreWakeUp` | Rude awakening | One bar, soft and slow | The tap as the message lands, then one bright note |
| `scoreCurtain` | Curtain call | A hush, a note for each look | The tap as it sees you |
| `scoreAlarmSnack` | Alarm snack | The soft ringing figure three times, a nudge on each hop of the button | The tap on the gulp |

| Flavour | Set up voice | Arrival | Lead of the arrival |
|---|---|---|---|
| `piano` | A low piano figure on Bm, G, D, A with octaves on top | A rolled D major chord on piano, two glockenspiel notes above | A5, G5, then F sharp 5: a step down onto the third |
| `kalimba` | Kalimba pairs on Bm, G, A with a bell and a low tine | A music box D6 over a rolled Dmaj7 celesta | G5, A5, E6, then D6 |

- Neither arrival is the three note call (A4 B4 D5 on mallets, climbing): that is `bought`, and it
  plays nowhere else. The piano's steps down, the kalimba's turns back down onto its last note,
  and neither leads on a mallet.
- Neither is `error` or `close` either: both of those are bare single notes and end open, and an
  arrival ends on a full tonic chord.
- The set up sits about 3 to 6 dB under the arrival, softer still for the two quiet intros.
- `introKnock` is still Doors' knock. No intro plays it.

The frame plays `close` once, when the paywall goes without the product in hand
(`paywallSaysClose`): from the cross, and from back or a swipe as the route starts to go. It
stays silent after a purchase, a restore that worked and the step after either, and in a tile.
The sound belongs to the app, so it plays on after the screen is gone.

A layout writes what its motion sounds like as a list of beats, each a clock second and a cue, in
its rules file beside the timeline they come from (`doorsCues`, `receiptCues`). It wraps its
composition in `PaywallCueScore(clock:, beats:, player:, turnCue:)`, which plays them:

- Each beat plays once, on the tick the clock passes its second. Never on a rebuild.
- `turnCue` marks a benefit the loop changed by itself, through the first pass only and never
  once the hand has taken over. A screen left open is silent. Use `next`, or the layout's own
  quiet cue.
- The hand's own change is `HeroPlayer.onChange`: `tick` by default, or the layout's cue.
- Nothing plays under reduce motion, where the frame's entrance cue is the only sound, or in a
  tile (`PaywallMuted`), or in the first moments after an intro.

`HeroComposition` has a score of its own: the approved entrance (`heroEntranceCues`: the mascot
lands with `pop`, or `drop` for a drop, and the card slides in with `whoosh`) and `next` for the
loop. Pass `entranceCues` or `turnCue` to change either. A layout built from parts uses
`heroLandingBeat` for its mascot.

A long entrance cue owns its whole span: play no second sound under it. The rules are pure
functions in `paywall_cue_rules.dart` and have tests. The buy block plays its own: `press` as a
finger goes down on the button, then `paywallBuyCue` for how the trip to the store ended.

## Rules every layout keeps

- One screen at 390 by 844 and 375 by 667 at the default text size. Nothing scrolls there.
- Text in your room grows to 1.5 times at most. At a large size, drop detail before you drop
  a benefit (second lines, then pictures, then the face). Only when nothing more can go may
  your content scroll inside its own box. The frame still does not.
- Nothing rests at an angle. Rotation lives inside a motion and ends at zero.
- No timer, no urgency, no made-up proof, no trial toggle. No word about how Pro is paid.
- Strings go in `en.json`, read through `LocaleKeys`. Sounds and haptics go through `PaywallCue`
  (see Cues).

## Capture it

```sh
fvm flutter test tool/capture_paywall_layout.dart --dart-define=MOCK=true \
  --dart-define=SKIP_PAYWALL=true --dart-define=LAYOUT=<key> --dart-define=PRODUCT=hosted
```

It writes eight PNGs to `build/paywall_shots` and fails on an overflow, a scroll at the default
size, or a cross or button off screen. The top of the tool lists the options: `OUT`, `STATE`,
`BENEFITS=built`, `SOURCE`, `PREVIEWS=gallery`, and `T=<seconds>`, which plays the motion a
frame at a time and captures that second (with `TAP=x,y`, `DRAG=x,y,x,y` and `THEN=<seconds>`).
`INTRO=<key>` plays that intro first (with `T`, which then counts from the intro's first frame).
`THANKS=<key>` buys on the demo model and captures what plays after (with `T`, which then counts
from the confirmed purchase, and `RESTORE=true` for the quiet frame).
`MOTION=rays,drop` draws the Hero composition with those variants.
`PICKER=page|intro|paywall|thanks` captures the developer picker.

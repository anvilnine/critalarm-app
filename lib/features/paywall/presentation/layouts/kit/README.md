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
  cue: PaywallEntranceCue.gag, // played once, in place of the layout's cue
  builder: _build, // (context, PaywallIntroScope scope) => FalseAlarmIntro(scope: scope)
);
```

What the builder gets is a `PaywallIntroScope`: `clock` (seconds since the intro began, read it
with `PaywallClockBuilder`), `size` (the whole screen), `padding` (the safe areas) and `product`.
Draw every frame from `scope.clock` alone and hold no timer.

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
- One light haptic at the hand over, and the intro's `cue`. Neither is an alarm: an intro makes
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
- `entranceCue`: `open` (the default), `gag`, `print`, `none`. `restAt`: the clock's resting second.

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

`PaywallLayoutTile(layout:, product:, label:)` and `PaywallIntroTile(intro:, product:, label:)`
draw the real layout (and intro) at 390 by 844 on the demo buy model, scaled down with a
`FittedBox`. A tile takes no touch of its own, plays no cue (`PaywallMuted`), and an intro tile
starts again every few seconds. Its clock runs only while the tile is built, so put tiles in a
lazy list with no cache: the developer picker shows about three at once.

## Rules every layout keeps

- One screen at 390 by 844 and 375 by 667 at the default text size. Nothing scrolls there.
- Text in your room grows to 1.5 times at most. At a large size, drop detail before you drop
  a benefit (second lines, then pictures, then the face). Only when nothing more can go may
  your content scroll inside its own box. The frame still does not.
- Nothing rests at an angle. Rotation lives inside a motion and ends at zero.
- No timer, no urgency, no made-up proof, no trial toggle. No word about how Pro is paid.
- Strings go in `en.json`, read through `LocaleKeys`. Sounds go through `PaywallCues`.

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
`MOTION=rays,drop` draws the Hero composition with those variants. `PICKER=page|intro|paywall`
captures the developer picker.

# Paywall layout kit

Every paywall layout sells Hosted or Pro from the same parts. A layout draws its own composition
and nothing else: no button, price row, legal text, clock, benefit list or purchase call.

## Add a layout

1. Add one file, `layouts/<name>_paywall_layout.dart`, whose widget returns a `PaywallFrame`.
   For Crit on a stage playing one benefit at a time, build on "Hero parts" below.
   `plain_paywall_layout.dart` is the shortest layout with no stage.
2. Register it in `kit/paywall_layout_registry.dart`: `PaywallLayoutId.proof: (_) => const Proof...()`.
3. Open it at `/plans/<key>?product=hosted|pro`, or from Developer options, Paywall layouts.
   That route lists every benefit, built or not. Add `&benefits=built` for the list a store
   build shows (`paywallBenefitsFor`). An unregistered id draws `hero` (`paywallFallbackLayout`).
4. Import `kit/paywall_frame.dart` (buy block, clock, scope, tones), `kit/paywall_preview.dart`.

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
| `HeroMascot(size:, face:)` | Crit alone, anywhere: `hop`, `bob`, `blink`, `entrance`, `props`. |
| `HeroAtmosphere(focus:, radius:)` | The disc and the drifting shapes alone, in a `tone`. |
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
- **The hand**, the same for any table: `player.touch(index:)` for a line, `touch(step:)` for a
  swipe (it wraps), `touch()` to play the turn again. The chosen turn plays from its start,
  holds `heroHandHoldSeconds`, then the loop goes on. It waits under a finger.

## The scope

`product` (`isHosted`, `isPro`), `benefits` (only what this build has, in order), `size`
(the room you have), `isCompact` (667 points tall or under), `source`, `clock`, `closeOnLeft`,
`close` (what the cross does). The cross covers a 44 point square in a top corner of your room:
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
must be complete: nothing hidden, half way or at an angle. The clock stops under another route.

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

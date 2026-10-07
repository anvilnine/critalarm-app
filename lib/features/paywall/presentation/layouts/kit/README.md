# Paywall layout kit

Every paywall layout sells Hosted or Pro from the same parts. A layout draws its own composition
and nothing else: no button, price row, legal text, clock, benefit list or purchase call.

## Add a layout

1. Add one file, `layouts/<name>_paywall_layout.dart`. Start from
   `plain_paywall_layout.dart`. The widget returns a `PaywallFrame`.
2. Register it in `kit/paywall_layout_registry.dart`:
   `PaywallLayoutId.bento: (_) => const BentoPaywallLayout(),`
3. Open it at `/plans/<key>?product=hosted|pro`, or from Developer options, Paywall layouts.
   An id with no line in the registry draws `plain`.

Import `kit/paywall_frame.dart` (buy block, clock, scope, tones) and `kit/paywall_preview.dart`.

## The frame

`PaywallFrame(builder: (context, scope) => ...)` never scrolls. It keeps the safe areas, puts
the close cross on screen from the first frame, and pins the buy block at the bottom.

- `tone`: `PaywallTone.canvas`, `surface`, `panel`, `cobalt` or `crit`. It sets the
  background and the text colours of the cross and the buy block. `PaywallToneColors.of`
  gives the same colours to your own text.
- `backdrop`: a widget drawn edge to edge behind everything, for more than one tone.
- `closeOnLeft`: which top corner holds the cross.
- `buyBlockVisible`: false hides the buy block during an entrance. It keeps its room, so
  nothing moves when it comes in. Draw a full-screen entrance in `backdrop`.
- `buyStyle`: a `PaywallBuyBlockStyle` with `pickerStyle` (`rows` or `segments`), `tone`,
  `buttonVariant`, `label` (`name` or `nameAndPrice`) and `showsPicker`. Set `showsPicker`
  to false only when you place a `PaywallPlanPicker` yourself.
- `entranceCue`: `open` (the default), `gag`, `print` or `none`.
- `restAt`: the second the scope's clock rests on when nothing may move.

A sheet-style layout puts `PaywallFrameBody` (same options, no full screen) in its own sheet.
What it draws outside that body reads the kit too:

- `PaywallOffer.of(context)`: `product`, `benefits` and `source`, the same ones the scope has.
- A `PaywallFrameController`, made and disposed in your `State` and passed as `controller`:
  `close()` does what the cross does (for a scrim tap), and `buyBlockHeight` listens to the buy
  block's measured height. It is null for the first frame, then follows the buy state.
- `PaywallLayoutScope.closeCrossInset` and `closeCrossSize` place the cross.

## The scope

`product` (`isHosted`, `isPro`), `benefits` (only what this build has, in order), `size`
(the room you have), `isCompact` (667 points tall or under), `source`, `clock`, `closeOnLeft`,
`close` (what the cross does). The cross covers a 44 point square in a top corner of your room:
keep words out of it. Deeper in your tree, `PaywallLayoutScope.of(context)` returns the same
scope, and `maybeOf` returns null where no frame is above.

## Previews

Draw a benefit with `benefit.title`, `benefit.line` and `PaywallPreview(benefit.previewId)`.
A preview not built yet draws a placeholder tile.

- `PaywallPreview(id, size: ..., playFrom: 6)`: the second on the layout clock at which that
  preview's loop starts at zero, for one benefit per scene. Before it the preview holds its
  first frame. Without it the three limit previews take turns in one 9 second loop.
- To build one, add it to `paywallPreviewBuilders` and read time through `PaywallPreviewClock`
  (or `.seconds`): the layout's clock under a frame, its own in the gallery, `restAt` when
  nothing may move. Write no clock of your own.
- A pop eases with `AppCurves.easeBack`. A locked thing shows `GlyphType.lock`.

## The clock

One number, seconds since the layout appeared. Work out every position and fade from it.

- `PaywallClockBuilder(clock: scope.clock, builder: (context, t, child) => ...)` redraws one
  part every frame.
- Or extend `PaywallClockState<T>` and read `t` in `build`. Override `restAt`.
- `phase(t, start, end)` is 0 to 1 across a window. `loopT(t, period)` wraps.
  `stagger(i, t, each: 0.08)` is the clock as item `i` sees it.

With reduce motion on, or under a `PaywallStill`, `t` is `restAt` and no ticker runs. That frame
must be complete: nothing hidden, half way or at an angle. The clock stops under another route.

## Rules every layout keeps

- One screen at 390 by 844 and 375 by 667 at the default text size. Nothing scrolls there.
- Text in your room grows to 1.5 times at most. Past the default size your content may scroll
  inside its own box. The frame still does not.
- Nothing rests at an angle. Rotation lives inside a motion and ends at zero.
- No timer, no urgency, no made-up proof, no trial toggle. No word about how Pro is paid.
- Strings go in `en.json` and are read through `LocaleKeys`. Sounds go through `PaywallCues`.

## Capture it

```sh
fvm flutter test tool/capture_paywall_layout.dart \
  --dart-define=MOCK=true --dart-define=SKIP_PAYWALL=true \
  --dart-define=LAYOUT=<key> --dart-define=PRODUCT=hosted
```

It writes eight PNGs to `build/paywall_shots` and fails on an overflow, a scroll at the default
size, or a cross or button off screen. The top of the tool lists the options: `OUT`, `STATE`,
`BENEFITS=all`, `SOURCE=<wire name>` (what opened the paywall, such as `history`) and
`T=<seconds>`, which plays the motion a frame at a time and captures that second.

`--dart-define=PREVIEWS=gallery` captures the two gallery preview sections, light and dark,
with no layout. Add `T=12.5` to run every preview through a loop and `SIZES=38,48` for other
tile sizes.

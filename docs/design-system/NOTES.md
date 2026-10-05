# v2-mascot: "The face"

## Direction

Crit Alarm has one state that matters, and the app shows it as a face before it shows a word.
The whole screen is one saturated yellow, heavy black type sits straight on it, a drawn character
fills the middle, and one white card floats at the bottom with the detail. Severity retints the
entire canvas: orange for a high message, red while a critical alarm rings, cobalt once you
acknowledge. The face is the glance layer. The card, the mono strings and the curl block are the
data, and they never soften to match the face.

## Canvas and second hue

- Canvas `#FFC93C`. Ink `#1A140F` on it measures 11.88:1, the muted line `#3A2A12` 9.00:1.
- Second hue: cobalt `#2A3BD8`. White on it 7.73:1, cobalt text on the yellow 5.03:1. It fights
  the yellow the way a deep green fights an orange, and it carries the primary action,
  the tilted hero box and the acknowledged state. Nothing else on screen is blue.
- Ladder: orange `#FF8A1F` for high (ink 7.74:1), red `#F5473A` for critical (ink 5.08:1, so
  black type survives the red takeover). Red appears nowhere except critical, so critical has a
  place to go that nothing else occupies.
- Severity never rests on hue or the face alone. Each rung also has a word on screen, a chip with
  its own glyph and weight (critical is taller, bordered, bolder), a position rule (critical pins
  to the top and flips its row to a black card), and on the alarm screen a shake and a pulse ring.
  The table in the design system section spells out all five channels.

## Dark theme

Canvas goes to `#171310`, cards to `#241D18`, type to cream. The face becomes an outline in a
low-luminance version of its state hue on a dark fill, and the severity canvases drop to tints
(`#3A100D` for critical, `#3A2208` for high, `#141A4A` for acknowledged). The 3am alarm screen is
therefore a dark red field with a red-outlined shaking face and a cobalt Acknowledge button, loud
without being a lamp. Buttons keep `--highlight #2A3BD8` in both themes; only the text and outline
cobalt lightens to `#7C8AFF` (6.10:1 on the dark canvas).

## Type

Bricolage Grotesque 800 for display and headings, tracked to -0.04em at hero size. It has enough
character to hold its own next to a drawn face and is not rounded, which keeps the page from
tipping into children's book. Instrument Sans 400 to 600 for body. JetBrains Mono for every string
a machine could consume: topic names, endpoints, tokens, timestamps, priorities. Prose is never
mono.

## The face

One construction, five feature sets, inline SVG generated from a 200 unit viewBox: rect head at
rx 66 with a 10 unit stroke, eyes r 11, mouth and brows as stroked paths. Calm, watching, worried,
alarmed, acknowledged. The head fills with `--canvas`, so a severity retint moves through the
face for free. It reads at 24px in the badge, 40px in list rows and 264px on the alarm screen.

## App icons

Four icons, one drawing. The default is the badge: the face peeking in from the left on the
orange field, the white mark on the right. Pro users can pick one of three others in Settings,
Appearance: Crowned, Shades, and Shades and crown. They change nothing else about the drawing.

- A Pro icon only adds a prop. Same face position, same field, same mark, same flat colours, no
  gradients, no words.
- The crown sits on the rounded top-right of the head, not the flat top, so it survives the round
  mask some Android launchers apply. Keep anything new inside the circle inscribed in the square.
- The default icon is the brand mark: favicons, store listings, the site header, OG images. The
  Pro icons appear only in the app and where the site describes Pro.
- When Pro ends, the app puts the default icon back, so a crown or shades always means an active
  plan.
- The masters are `assets/icon/src/*.svg` in the app repo and `src/assets/critalarm-icon*.svg` on
  the site. `tool/export_app_icons.sh` renders every size.

## Setup components

Three components in `lib/design/components/`, each in the gallery at `/gallery`.
Two more came later and are listed after them.

- `AppHighlightCard`: use it to mark the one choice on a screen that matters, or one row in a short
  checklist. It draws a tinted, stroked surface and nothing else, so a toggle row or a checklist
  row goes inside. It has four tones:
  - `choice`: cream with the ink stroke, for the one choice on a screen before the user has made
    it. It stands out from a white sheet and from the canvas and claims no state. Never use `calm`
    for an open choice: blue says done.
  - `crit`: the critical canvas with its stroke, once that choice is on. In the light palette it
    has the same stroke as `choice`, so only the fill changes when the switch flips.
  - `pending`: a plain surface with a quiet stroke, for a row that is waiting on something.
  - `calm`: the cobalt tint with a cobalt stroke, for a row that is done.

  Text on it takes `onCanvas`: muted text on the light `crit` tone is 3.85:1.
- `AppAnimatedTick`: use it when one thing finishes while the user watches, such as a first message
  landing or a checklist step. The ring fills, then the tick draws, once, in 600 ms. For a static
  "included" mark in a list, use `AppFeatureBullet`. The caller wraps it in `Semantics` with a
  label.
- `AppWaitingFace`: use it for every wait on something outside the app, in place of a bare spinner.
  It is the watching face over one line that says what is happening. The line is a live region,
  so a screen reader hears it change. `faceState` swaps the face for the moment the wait ends on
  the same screen, such as a phone that is now ringing.

- `AppFittedTitle`: use it for a display title that may be one long word. It scales the type down
  until the longest word fits the line, so a title never breaks inside a word. Between words it
  wraps like any text.
- `AppButtonVariant.tinted`: a soft tint of the canvas with no stroke. Use it for the quiet action
  on a coloured canvas, such as Silence on the alarm screen. It keeps the size and tap target of
  every other button.

## Faces in setup

One face per setup screen: 80 px, in a `Hero` with the tag `onboarding-face`, at the same top inset
on every step, so it flies from step to step and holds still inside one. A state that changes on
a screen swaps the `FaceState` on that widget.

- `watching` means waiting on something outside the app, and nothing else. A screen that asks the
  user to do something gets another face.
- `worried` means something failed. A state that is only missing a step (no server yet, Critical
  delivery off, a test that timed out) gets its own face: `sad`, `skeptical`, `confused`.
- Titles of setup task screens are `AppTypography.headline` at 30, centred. A problem or a wait
  goes on a card under the face (`SetupProblemCard`): a headline 22 title, at most one `body`
  line, and its action. Words never sit straight on the moving canvas there.

All three stop moving when the phone asks for reduced motion.

## With more time

- Draw the face in a real vector tool and test it against a grid of eye and mouth offsets; the
  alarmed mouth and the watching brow are the two that still feel drawn by code.
- A proper dot-matrix or halftone treatment for the ghost layer instead of plain CSS shapes.
- Acknowledged as a screen transition (red to cobalt wipe, face eyes closing) rather than a static
  state in the gallery.
- The hero face cycles on a timer; a scroll-driven version would tie the state to the copy.
- Test the phone screens at real device pixel density; the chips at 12px mono are on the edge.

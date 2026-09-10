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

## With more time

- Draw the face in a real vector tool and test it against a grid of eye and mouth offsets; the
  alarmed mouth and the watching brow are the two that still feel drawn by code.
- A proper dot-matrix or halftone treatment for the ghost layer instead of plain CSS shapes.
- Acknowledged as a screen transition (red to cobalt wipe, face eyes closing) rather than a static
  state in the gallery.
- The hero face cycles on a timer; a scroll-driven version would tie the state to the copy.
- Test the phone screens at real device pixel density; the chips at 12px mono are on the edge.

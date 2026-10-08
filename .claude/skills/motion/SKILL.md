---
name: motion
description: Use when adding or changing any animation in critalarm-app: a screen entrance, a hero, a mascot reaction, a feature preview, a list that comes in, a state change that should feel alive, or when a screen is called flat, plain, lifeless, cluttered or busy. Says what gets custom motion, how to build it on the clock, and how to prove it.
---

# Custom motion in Crit Alarm

The app has a character, Crit, and a loud palette. A screen that only fades in wastes both. A
screen where six small things wiggle is worse. This skill is the rule for the space between.

## The one idea

**One large living thing per screen. Everything under it is quiet.**

Two failures taught this, both on the same screen:

- Many small animated tiles, each in its own box. It read as cluttered.
- The fix removed the tiles and the character with them. It read as plain and lifeless.

What worked: the mascot large on a stage with a little atmosphere behind him, one feature
playing beside him, then plain lines of type, then the action. Life came from the hero. Calm
came from everything else being type on one edge.

So when a screen feels busy, take the boxes away from the small things. Never take the
character away. When a screen feels flat, give it one hero, not five decorations.

## What earns custom motion

| Worth it | Not worth it |
|---|---|
| A screen whose job is to persuade or welcome: setup steps, paywalls, empty states, a first success | A settings list, a form, a table of rows |
| A state change the user caused and should feel: a switch refused, a limit lifted, an alarm acknowledged | A value that updates in the background |
| Showing a feature doing its job, in miniature, before the user has it | Decoration that moves for its own sake |
| Crit reacting to what just happened | Crit on every row |

A list screen may carry one hero when the hero is the face: Crit large above the list, the
rows and sheet quiet. It is the one exception to "a list gets no hero".

Ask of every motion: what does it show that a still picture could not? If nothing, cut it.

## Rules

1. **One focal point.** One hero per screen. A second moving thing must be small, slow and
   behind it (atmosphere), or a direct reaction to the first.
2. **Motion shows the product.** A preview plays the real behaviour: the switch that refuses,
   the count that stops at the limit, the widget that rings and is answered. Use the real
   components and tokens inside it so it looks like the app.
3. **Crit reacts, with a reason.** Pick face states that match the beat: doubtful when
   something is refused, glad when it works, startled by a ring. Blink and bob a little. Do
   not hold one face for a whole loop. The face rig is `lib/design/faces/`. Draw props (a
   crown, shades) as overlays in the feature's own folder. Do not edit the face package for
   one screen.
4. **Entrances have character and are short.** About a second. The hero pops with
   `AppCurves.easeBack`, the supporting parts follow with a small stagger. No plain fade for a
   hero. Anything the user needs to leave (a close cross, a back arrow) is on screen from the
   first frame.
   Exception: a tab people open many times a day has no entrance at all. Its first frame is the
   finished picture, and only ambient motion (a slow breath, a blink) and reactions to real
   events play.
5. **Nothing rests at an angle.** Rotation lives inside a motion (a ring shake of a few
   degrees, a landing) and ends at zero. A tilted card at rest looks like a bug, and a build
   that freezes half way through one looks broken.
6. **Every animation has a resting frame that is complete.** Reduce motion shows that frame
   and nothing moves. Remove the animation. Never pause it half way. Read
   `context.reduceMotion`; use `context.motion(duration)` for implicit animations
   (`lib/design_system/motion.dart`).
7. **Small things do not move.** At thumbnail size (about 56 points and under) draw one mark on
   one shared tile shape. Motion starts at about 120 points.
8. **Fixed sizes.** A preview has size classes and never stretches to fill leftover height.
   Leftover height goes to the hero or to air, on purpose.
9. **The accent stays scarce.** Cobalt is the primary action, and a switch that is on. Motion
   does not get to add a third use.
10. **Let the hand in.** If a hero cycles through several things, a swipe moves to the next
    and a tap on the matching line jumps to it. After a touch, hold on what the user chose
    for a few seconds before the loop carries on. Give one light haptic per change through
    `AppHaptics`. Gestures are never the only way: the lines do the same job, and each is a
    labelled button.
11. **No sound that could be an alarm, ever.** The app generates no alarm. A miniature of a
    ringing screen stays a small silent picture on a card.
12. **No new dependency.** No Lottie, no Rive, no video. The face rig, painters and the design
    system are enough.

## How to build it

**Drive everything from one clock.** One number, seconds since the screen appeared. Work out
every position, fade and face from it with pure functions. That is what makes motion testable
and capturable.

- The clock and helpers are in `lib/design_system/screen_clock.dart` (the paywall's
  `kit/paywall_clock.dart` re-exports it, so its old imports still work):
  `PaywallClockState` (a `State` base with a ticker, `t` and `restAt`),
  `PaywallClockBuilder`, `PaywallStill`, and the helpers `phase(t, start, end)`,
  `loopT(t, period)` and `stagger(i, t)`.
- A small scene that must work inside a layout and alone in the gallery uses
  `PaywallPreviewClock` (`kit/paywall_preview_clock.dart`).
- They moved out of the paywall feature when a second screen needed them. Import from
  `lib/design_system/screen_clock.dart` in new code. Do not copy them.
- The welcome heroes in `onboarding_welcome_screen.dart` are the older, private form of the
  same idea. Read them for examples. Do not import from them.

**Write the timeline as a table, then test the table.** A list of beats: when each starts,
what the scene shows, which face Crit wears. Keep it in a pure function
(`layouts/kit/hero/hero_loop.dart` is the worked example). Unit test the order, the loop wrap and
the resting frame. Do not write widget tests.

**Tokens.** Durations from `AppDurations`, curves from `AppCurves` (`easeOut` for most moves,
`easeSpring` for a settle, `easeBack` for a pop). No literal colour, no literal font.

**Cost.** A scene that redraws every frame should repaint only itself (`RepaintBoundary`), and
should not rebuild when its frame did not change. A clock stops while its route is covered.

## How to prove it

Motion cannot be judged from a still, and an agent cannot watch it play. So:

1. Capture frames at several seconds of the timeline, at two phone sizes, light and dark, at
   the default and the largest text size, plus the resting frame. The paywall capture tool
   (`tool/capture_paywall_layout.dart`) steps the clock in 16 ms frames and fails on an
   overflow on the way. Use the same approach elsewhere.
2. Look at the frames yourself. Each must look finished on its own. Ask the two second
   question: what does the eye hit first, and is that the hero?
3. Say plainly in your report that the motion was not watched playing. Timing and feel are
   unverified until someone sees it on a phone.
4. Get it on a real phone early, one screen at a time. Do not build five more on a pattern
   nobody has seen move.

## A short checklist

- [ ] One hero. Everything else is type or a quiet control.
- [ ] The motion shows something a still could not.
- [ ] Crit's face changes for a reason.
- [ ] The way out is on screen from the first frame.
- [ ] Nothing tilted at rest. Reduce motion shows a complete frame.
- [ ] Thumbnails are still. Previews have a fixed size.
- [ ] The timeline is a pure function with tests.
- [ ] Frames captured at both sizes, both themes, large text. Looked at, not only passed.
- [ ] The report says what was not seen moving.

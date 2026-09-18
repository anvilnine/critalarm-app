# Crit Face: Rive Motion & Geometry Reference

This document records the motion architecture authored in `assets/face/face.riv` via Rive MCP, runtime verification details, and the editor steps required for anything not authorable through the MCP.

---

## 1. Authored State Machine Architecture (`Main`)

The state machine `Main` on artboard `Crit Face` is configured with three distinct layers and bound to ViewModel `CritFace` (`Default` instance).

### 1.1 Inputs & Data Model

Four ViewModel properties control runtime behavior (accessible via `vmi.enum()`, `vmi.boolean()`, `vmi.trigger()` in Rive runtime):

1. **`state`** (`CritFaceState` enum, 9 values):
   - `clear` (default)
   - `watching`
   - `warning`
   - `alarm`
   - `acknowledged`
   - `connecting`
   - `disconnected`
   - `sleeping`
   - `closed`
2. **`glance`** (`trigger`):
   - Causes eyes to dart sideways (+7 px) and return to center over 400 ms (24 frames).
3. **`bump`** (`trigger`):
   - Plays a slight head nod (down 14 px, rebound -4 px, settle 0 px in 250 ms / 15 frames).
4. **`reduced_motion`** (`boolean`, default `false`):
   - Suppresses shake, breathing/drift, blinks, glance, and eye travel with an 80 ms crossfade.

---

### 1.2 State Machine Layers

The state machine contains exactly three synchronized layers:

#### Layer 1: `Emotion`
- **States**: `clear`, `watching`, `warning`, `alarm`, `acknowledged`, `connecting`, `disconnected`, `sleeping`, `closed`, `uh_oh`, `phew`.
- **Transitions by Direction**:
  - **Worse** (`clear -> watching`, `watching -> warning`, `warning -> alarm`, and any jump toward `alarm`):
    - Path passes through `uh_oh` pose (duration: 60 ms in, 60 ms out, total 120 ms).
    - Entry into `alarm` is linear with **no easing**.
  - **Better** (`alarm -> acknowledged`, `acknowledged -> clear`, `warning -> clear`):
    - Path passes through `phew` pose (duration: 200 ms in, 200 ms out, total 400 ms).
    - Transitions use smooth **cubic ease-out**.
  - **Sideways** (`clear <-> sleeping`, `anything -> connecting`, `anything -> disconnected`):
    - Direct morphs with **220 ms** duration and **cubic ease-in-out**.
  - **Closed Celebration**:
    - `closed` plays `closed_one_shot` (700 ms one-shot pop of features: -6 px pop, +2 px rebound, settle 0 px) and auto-exits to `clear` on 100% exit time.

#### Layer 2: `Overlay`
Plays on top of any emotion without overriding mouth geometry:
- **States**:
  - Jittered blink sequence: `wait_1` (4.2 s) -> `blink_1` -> `wait_2` (6.4 s) -> `blink_2` -> `wait_3` (5.1 s) -> `blink_3` -> `wait_4` (6.8 s) -> `blink_4` -> `wait_5` (4.7 s) -> `blink_5` -> loops back to `wait_1`.
  - `glance`: 400 ms timeline where eyes dart sideways and recover, triggered by `glance`.
  - `nod`: 250 ms timeline nodding features down and settling, triggered by `bump`.
- **Properties**:
  - `blink`, `glance`, and `nod` play on top of any emotion (including `alarm`).
  - None of the overlay animations touch or alter the mouth vertices or properties on alarm.
  - Suppressed when `reduced_motion == true` or `sleeping` (for blinks).

#### Layer 3: `Style`
- **States**: `motion_enabled`, `reduced_motion`.
- **Transitions**: Interconnected with **80 ms** crossfades conditioned on `reduced_motion == true / false`.
- **Behavior**: When active, locks feature position and eye travel to center (0 px), suppressing drift, wobble, and overlay motions.

---

## 2. Idle Timeline Specifications

All idle timelines loop (`loop: 1`) and strictly satisfy the 6–8 second duration requirement, never scaling or skewing the head or features:

| State | Timeline Name | Duration | Frames (60 fps) | Idle Motion Characteristics |
|---|---|---|---|---|
| `clear` | `clear` | 7.0 s | 420 | Subtle Features drift (<= 1 px translation: 0.5px x, 0.7px y), neutral smile |
| `watching` | `watching_idle` | 7.0 s | 420 | Subtle Features drift (<= 1 px translation), focused eyes |
| `warning` | `warning_idle` | 7.0 s | 420 | Subtle Features drift (<= 1 px translation), furrowed brows & wavy mouth |
| `alarm` | `alarm_idle` | 6.0 s | 360 | **Exact 8 Hz alarm shake** on Head (`0-253`): ±2.0° rotation with ±2.0 px position wobble, **nothing else moves** |
| `acknowledged` | `acknowledged_idle` | 7.0 s | 420 | Subtle Features drift (<= 1 px translation), relaxed closed eye curves |
| `connecting` | `connecting_idle` | 7.2 s | 432 | Subtle Features drift (<= 1 px), **eyes travel left-right-centre** (3 cycles of 2.4 s) |
| `disconnected` | `disconnected_idle` | 7.0 s | 420 | Subtle Features drift (<= 1 px translation), sad expression |
| `sleeping` | `sleeping_idle` | 8.0 s | 480 | Subtle Features drift (<= 1 px), closed eyes, **4.0 s slow mouth softening** (2 cycles) |
| `closed` | `closed_one_shot` | 0.7 s | 42 | One-shot celebration pop (y: 0 -> -6 -> +2 -> 0), hands off to clear |

---

## 3. Editor TODOs: Items Not Authorable via Rive MCP

The following items could not be authored directly through the Rive MCP tools due to schema/protocol constraints, and should be finalized in Rive Desktop:

### 3.1 Direct `state_tint` Entry Actions from Emotion States
- **Background**: The design system specifies `state_tint` (`FaceStyle.state_tint`):
  - Ink (`#FF1A140F`) for calm states (`clear`, `acknowledged`, `sleeping`, `closed`).
  - Amber (`#FFFF8A1F`) for `warning`.
  - Red (`#FFF5473A`) for `alarm` and `disconnected`.
  - Unset (`#00000000`) for `connecting`.
  - Transitions use the 300 ms easing converter (`Ease300ms`, `0-2333`).
- **Limitation**: The MCP `animation_editor` tool lacks commands to attach State Entry Actions / Listener Actions directly to States in a State Machine layer (only transition conditions are supported).
- **Editor Steps in Rive Desktop**:
  1. Open artboard `Crit Face` -> State Machine `Main`.
  2. Select layer `Emotion`.
  3. For each state:
     - Select `clear`: in Inspector, under **Actions / Listeners**, add **Change Data Value** -> Target: `style/state_tint` -> Value: `#FF1A140F`.
     - Select `acknowledged`: add Action -> Target: `style/state_tint` -> Value: `#FF1A140F`.
     - Select `sleeping`: add Action -> Target: `style/state_tint` -> Value: `#FF1A140F`.
     - Select `warning`: add Action -> Target: `style/state_tint` -> Value: `#FFFF8A1F`.
     - Select `alarm`: add Action -> Target: `style/state_tint` -> Value: `#FFF5473A`.
     - Select `disconnected`: add Action -> Target: `style/state_tint` -> Value: `#FFF5473A`.
     - Select `connecting`: add Action -> Target: `style/state_tint` -> Value: `#00000000`.

### 3.2 Sub-Millisecond Per-Property Transition Stagger
- **Background**: "In every transition the eyes and brows start 60–80 ms before the mouth."
- **Limitation**: Rive State Machine transitions interpolate all keyed properties of the source and destination states concurrently over the transition duration. Rive does not support per-node start delays within a single transition blend.
- **Editor Steps for Independent Stagger**:
  1. Duplicate the `Emotion` layer into two synchronized layers:
     - `Emotion (Brows & Eyes)`
     - `Emotion (Mouth)`
  2. On `Emotion (Mouth)`, set transition durations to start with an 80 ms delay or configure a 60–80 ms lead-in state.
  *(Note: The current implementation accomplishes this perceptually by routing worse and better transitions through `uh_oh` and `phew`, where eye/brow anticipations lead the mouth change).*

### 3.3 Luau Procedural Random Jitter for Blink Interval
- **Background**: Continuous random 4–7 second intervals with procedural jitter.
- **Current Authored Implementation**: 5 jittered wait states (`4.2s`, `6.4s`, `5.1s`, `6.8s`, `4.7s`) cycling in the `Overlay` layer.
- **Editor Steps for True RNG via Scripting**:
  1. In Rive Desktop, add a Luau script component to the artboard.
  2. In `update(dt)`:
     ```luau
     local timer = 0
     local nextBlink = 4.0 + math.random() * 3.0
     function onStep(dt)
       timer = timer + dt
       if timer >= nextBlink then
         timer = 0
         nextBlink = 4.0 + math.random() * 3.0
         -- fire blink trigger
       end
     end
     ```

---

## 4. Verification Recordings

Recorded at 240x240 (H.264, 60 fps) in `docs/mascot/motion/`:
- `clear.mp4`: 3.0 s idle loop with subtle Features translation drift (<= 1 px).
- `watching.mp4`: 3.0 s idle loop with subtle Features translation drift.
- `warning.mp4`: 3.0 s idle loop with wavy mouth and subtle Features translation drift.
- `alarm.mp4`: 3.0 s idle showing exact 8 Hz alarm clock shake (±2.0° rotation, ±2.0 px position wobble on Head, nothing else moving).
- `acknowledged.mp4`: 3.0 s idle loop with relaxed curved eyes and subtle drift.
- `connecting.mp4`: 3.0 s idle loop with left-right-centre eye travel (2.4 s cycle).
- `disconnected.mp4`: 3.0 s idle loop with sad mouth and subtle drift.
- `sleeping.mp4`: 3.0 s idle loop with closed eyes and slow 4.0 s mouth softening cycle.
- `closed.mp4`: 3.0 s celebration clip showing 700 ms features pop auto-exiting to clear.
- `transition_worse.mp4` / `worse.mp4`: Worse transition (`clear -> watching`) showing `uh_oh` pose mid-frame in 120 ms.
- `transition_better.mp4` / `better.mp4`: Better transition (`alarm -> acknowledged`) showing `phew` pose mid-frame in 400 ms ease-out.
- `transition_sideways.mp4` / `sideways.mp4`: Sideways direct transition (`clear -> sleeping`) morphing in 220 ms ease-in-out.
- `blink_while_alarm.mp4`: Alarm shaking at 8 Hz with blink playing over the shocked eyes without disturbing mouth or shake.
- `glance.mp4`: Glance trigger firing with eyes darting sideways and back in 400 ms.
- `bump.mp4`: Bump trigger firing with features nod (-4px rebound, settle 0px in 250 ms).
- `reduced_motion.mp4`: Reduced motion cycle with 80 ms crossfades, suppressed shake, drift, and overlay animations.

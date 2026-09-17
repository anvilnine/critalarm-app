# Crit Face: Rive Motion & Geometry Reference

This document records the motion architecture authored in `assets/face/face.riv` via Rive MCP, runtime verification details, and the editor steps required for future single-path vertex morphing.

---

## 1. Authored State Machine Architecture (`Main`)

The state machine `Main` on artboard `Crit Face` is fully configured and bound to ViewModel `CritFace` (`Default` instance).

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
2. **`tone`** (`CritFaceTone` enum, 4 values):
   - `yellow` (default: `#FFC93C` head, `#1A140F` ink)
   - `paper` (`#FFFFFF` head, `#1A140F` ink)
   - `ink` (`#1A140F` head, `#F7F1EA` paper)
   - `red` (`#F5473A` head, `#1A140F` ink)
3. **`reduced_motion`** (`boolean`, default `false`):
   - Suppresses shake, breathing, blink, and eye travel with an 80 ms cubic crossfade.
4. **`bump`** (`trigger`):
   - Plays a slight head nod (down 14 px, rebound -4 px, settle 0 px in 250 ms).

---

### 1.2 State Machine Layers

The state machine contains 5 synchronized layers:

#### Layer 1: `Pose`
- **States**: `clear`, `watching`, `warning`, `alarm`, `acknowledged`, `connecting`, `disconnected`, `sleeping`, `closed`, and `neutral`.
- **Transitions**:
  - **Normal transitions**: For any source state except `alarm`, exiting to a different state transitions to `neutral` in **110 ms** (Cubic Ease-In-Out), then `neutral` transitions to the destination state in **110 ms** (total 220 ms).
  - **Alarm entry**: `{Any State} -> alarm` triggers directly in **120 ms** (Linear), bypassing `neutral`. Exiting `alarm` passes through `neutral` in 110 ms.
  - **Closed celebration**: `closed` plays `closed_one_shot` (700 ms, loop: 0) and transitions back to `clear` automatically on 100% exit time.

#### Layer 2: `Tone`
- **States**: `yellow`, `paper`, `ink`, `red`.
- Fully interconnected with 0 ms transitions on `tone == <destination>`. Color palettes swap instantly without disturbing ongoing facial animation or timelines.

#### Layer 3: `Reduced Motion`
- **States**: `motion_enabled`, `reduced_motion`.
- Interconnected with **80 ms** Cubic Ease-In-Out transitions conditioned on `reduced_motion == true / false`.
- `reduced_motion_override` locks:
  - `face_root` scale to 100% (suppresses breathing)
  - `face_root` rotation to 0° (suppresses alarm shake)
  - `connecting` eye position to center (suppresses travel)
  - Eye vertical scales to 100% (suppresses blink)

#### Layer 4: `Blink`
- Jittered blink cadence with non-fixed intervals:
  - `blink_wait_1` (4.2 s = 252 frames) -> `blink` (10 frames)
  - `blink_wait_2` (6.4 s = 384 frames) -> `blink` (10 frames)
  - `blink_wait_3` (5.1 s = 306 frames) -> `blink` (10 frames)
  - `blink_wait_4` (6.8 s = 408 frames) -> `blink` (10 frames)
  - `blink_wait_5` (4.7 s = 282 frames) -> `blink` (10 frames) -> loops back to `wait_1`.
- Consecutive blinks occur at differing intervals (4.2s, 6.4s, 5.1s, 6.8s, 4.7s), all strictly within 4–7 seconds and never on a fixed beat.
- Transitions into `blink` are conditioned on `reduced_motion == false`, `state != alarm`, and `state != sleeping`, ensuring blinks are suppressed when motion is reduced, when eyes are shut sleeping, or when staring in alarm.

#### Layer 5: `Bump`
- **States**: `idle`, `nod`.
- Transitions to `nod` on `triggerFired: bump`, returning to `idle` on 100% exit time.

---

## 2. Idle Timeline Specifications

All idle timelines loop (`loop: 1`) and meet the 6–8 second duration requirement:

| State | Timeline Name | Duration | Frames (60 fps) | Idle Motion Characteristics |
|---|---|---|---|---|
| `clear` | `clear` | 7.0 s | 420 | ±1.5% scale breathing (`face_root`), neutral smile |
| `watching` | `watching_idle` | 7.0 s | 420 | ±1.5% scale breathing, focused eyes & slight brow |
| `warning` | `warning_idle` | 7.0 s | 420 | ±1.5% scale breathing, furrowed brows & wavy mouth |
| `alarm` | `alarm_idle` | 6.0 s | 360 | **Exact 8 Hz shake** (±2° rotation across 48 cycles), no breathing |
| `acknowledged` | `acknowledged_idle` | 7.0 s | 420 | ±1.5% scale breathing, relaxed closed eye curves |
| `connecting` | `connecting_idle` | 7.2 s | 432 | ±1.5% scale breathing (2 cycles), **eye travel left-right** (3 cycles of 2.4s) |
| `disconnected` | `disconnected_idle` | 7.0 s | 420 | ±1.5% scale breathing, sad mouth & drooped eyes |
| `sleeping` | `sleeping_idle` | 8.0 s | 480 | **Deep/slow breathing** (4.0 s cycle, 98.5% scale), closed eyes |
| `closed` | `closed_one_shot` | 0.7 s | 42 | One-shot celebration pop (scale 90 -> 108 -> 100), settles to clear |

---

## 3. Future Editor Task: Single-Path Vertex Morphing

In the current implementation, expressions use 9 distinct node groups (`clear`, `watching`, `warning`, `alarm`, `acknowledged`, `connecting`, `disconnected`, `sleeping`, `closed`) crossfaded via `neutral`.

To transition from group crossfading to true geometric vertex morphing (shape deformation):

### Editor Steps in Rive Desktop:

1. **Geometry Consolidation**:
   - Under `face_root`, create three permanent `PointsPath` shapes:
     - `eye_left`
     - `eye_right`
     - `mouth`
   - Remove or deprecate the individual state node groups.

2. **Matching Vertex Topology**:
   - Ensure each path has the exact same vertex count and handle types across all 9 expressions:
     - **Eyes**: 4 cubic vertices per eye (top, right, bottom, left) with symmetric or detached handles.
       - In `clear`, `watching`, `warning`, `connecting`: Vertices form open round circles/ellipses.
       - In `sleeping`, `acknowledged`, `closed`: Vertices collapse vertically with handles adjusted to form smooth closed/smiling eye curves.
       - In `alarm`: Outer vertices expand for wide circles, and pupil shapes follow eye centers.
       - In `disconnected`: Vertices morph into downward drooped arcs.
     - **Mouth**: 4 cubic vertices (left corner, center-low, right corner, center-high):
       - In `clear` & `acknowledged`: Symmetrical upward arc (smile).
       - In `watching`, `connecting`, `neutral`: Flat horizontal line.
       - In `disconnected`: Downward arc (frown).
       - In `warning`: Wavy S-curve with alternating handle tangents.
       - In `alarm`: Circular opening with expanded center vertices.

3. **Keyframe Vertex Coordinates Across Timelines**:
   - In each of the 9 idle timelines (`clear`, `watching_idle`, `warning_idle`, etc.), animate the vertex positions and tangent handles of `eye_left`, `eye_right`, and `mouth`.
   - Because all timelines share the identical 3 `PointsPath` objects, switching between states in the `Pose` state machine layer automatically interpolates the point coordinates (true morphing) rather than toggling opacity between separate groups.

4. **Blink Integration with Morphed Eyes**:
   - On the `blink` timeline, keyframe the vertical scale or Y coordinates of the consolidated `eye_left` and `eye_right` vertices to collapse to 5% and return to 100% over 10 frames.

---

## 4. Verification Recordings

11 MP4 recordings generated at 240x240 (H.264, 60 fps) in `docs/mascot/motion/`:
- `clear.mp4`: Full idle loop and 3 consecutive jittered blinks (differing intervals: 4.2s, 6.4s, 5.1s).
- `watching.mp4`: Focused idle loop.
- `warning.mp4`: Warning idle loop.
- `alarm.mp4`: 8 Hz rotation shake (±2°), shock expression, no breathing.
- `acknowledged.mp4`: Relaxed idle loop.
- `connecting.mp4`: Left-right eye sweep (2.4s cycle) and breathing.
- `disconnected.mp4`: Sad idle loop.
- `sleeping.mp4`: Deep/slow 4s breathing, closed eyes.
- `closed.mp4`: Celebration one-shot pop and settling on clear.
- `cycle.mp4`: Sequential cycling through all 9 states with cubic easing through neutral and direct alarm transition.
- `reduced_motion.mp4`: Reduced motion enabled; shake, breathing, blink, and eye travel suppressed across expression changes.

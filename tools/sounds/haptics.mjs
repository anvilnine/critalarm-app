// Crit Alarm iPhone haptics. Turns each alarm sound into a Core Haptics pattern (an AHAP file)
// that follows the sound's loudness, so the phone buzzes on the beat while the incident screen
// is open and ringing. Run from the repo root:
//   node tools/sounds/haptics.mjs                  (every sound)
//   node tools/sounds/haptics.mjs classic_siren    (one, by id)
// Needs Node 22 or later and ffmpeg on PATH. On macOS the default ring sound (a caf ffmpeg
// cannot read) goes through Apple's afconvert first. No network.
//
// Writes into ios/Runner/Haptics/:
//   <id>.ahap      one per bundled sound, plus alarm.ahap (the ring sound that ships in the app
//                  for an alarm with no sound of its own) and steady.ahap (a plain pulse for a
//                  store sound pack or an own sound)
//   manifest.json  for each sound: the file it was made from, that file's sha256, its length and
//                  its loudness at 100 ms, so a test can tell when a sound changed without a new
//                  pattern, and can check the pattern against the sound.
//
// How a pattern is made (the same rule as the Android vibration, android/.../HapticPattern.kt):
// 1. Decode the sound the iPhone plays (assets/sounds/<id>.mp3 or .m4a) to mono 16-bit PCM.
// 2. RMS loudness for every 20 ms window, the loudest window at 1.
// 3. A window below GATE (0.3) is still. A louder one is one of LEVELS (5) strengths.
// 4. Neighbouring windows of the same strength join into one HapticContinuous event.
// 5. The pattern is exactly as long as the sound (a still tail gets a zero-strength event), so
//    the app can loop the pattern and the sound together.
// To change the feel, change the numbers below and run this again. To add a sound, add it to
// BundledSounds (lib/core/sound/bundled_sounds.dart) and run this again: a test fails until
// there is a pattern for every bundled sound.
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const SOUNDS = join(ROOT, 'assets', 'sounds');
const OUT = join(ROOT, 'ios', 'Runner', 'Haptics');
const DEFAULT_RING = join(ROOT, 'ios', 'Runner', 'Sounds', 'alarm.caf');

const SAMPLE_RATE = 24000;
const WINDOW_MS = 20;
const GATE = 0.3;
const LEVELS = 5;
const MIN_INTENSITY = 0.4;
const MAX_INTENSITY = 1.0;
const ENVELOPE_MS = 100;
// Core Haptics plays a continuous event for 30 seconds at most.
const MAX_EVENT_S = 10;

/** id to ms, read from the catalogue the app plays, so the two cannot disagree. */
function bundledSounds() {
  const source = readFileSync(join(ROOT, 'lib', 'core', 'sound', 'bundled_sounds.dart'), 'utf8');
  const ext = new Map();
  const extBlock = source.match(/iosExtensions = <String, String>\{([\s\S]*?)\};/)[1];
  for (const m of extBlock.matchAll(/'([a-z_0-9]+)': '([a-z0-9]+)'/g)) ext.set(m[1], m[2]);
  const durBlock = source.match(/durations = <String, Duration>\{([\s\S]*?)\};/)[1];
  const out = [];
  for (const m of durBlock.matchAll(/'([a-z_0-9]+)': Duration\((seconds|milliseconds): (\d+)\)/g)) {
    const ms = m[2] === 'seconds' ? Number(m[3]) * 1000 : Number(m[3]);
    out.push({ id: m[1], file: join(SOUNDS, `${m[1]}.${ext.get(m[1])}`), durationMs: ms });
  }
  return out;
}

function sha256(path) {
  return createHash('sha256').update(readFileSync(path)).digest('hex');
}

/** Mono 16-bit PCM of a sound file, as Int16Array. */
function decode(path) {
  let input = path;
  let scratch = null;
  if (path.endsWith('.caf')) {
    scratch = mkdtempSync(join(tmpdir(), 'haptics-'));
    input = join(scratch, 'in.wav');
    const made = spawnSync('afconvert', ['-f', 'WAVE', '-d', 'LEI16', path, input]);
    if (made.status !== 0) throw new Error(`afconvert failed for ${path}: ${made.stderr}`);
  }
  const run = spawnSync(
    'ffmpeg',
    ['-v', 'error', '-i', input, '-ac', '1', '-ar', String(SAMPLE_RATE), '-f', 's16le', '-'],
    { maxBuffer: 1 << 28 },
  );
  if (scratch) rmSync(scratch, { recursive: true, force: true });
  if (run.status !== 0) throw new Error(`ffmpeg failed for ${path}: ${run.stderr}`);
  const bytes = run.stdout;
  return new Int16Array(bytes.buffer, bytes.byteOffset, Math.floor(bytes.length / 2));
}

/** RMS per window, the loudest window at 1. */
function loudness(samples, durationMs) {
  const perWindow = Math.floor((SAMPLE_RATE * WINDOW_MS) / 1000);
  const frames = Math.min(samples.length, Math.round((SAMPLE_RATE * durationMs) / 1000));
  const count = Math.ceil((durationMs / WINDOW_MS));
  const out = new Float64Array(count);
  for (let w = 0; w < count; w++) {
    const start = w * perWindow;
    const end = Math.min(frames, start + perWindow);
    if (end <= start) continue;
    let sum = 0;
    for (let i = start; i < end; i++) {
      const v = samples[i] / 32768;
      sum += v * v;
    }
    out[w] = Math.sqrt(sum / (end - start));
  }
  const loudest = out.reduce((a, b) => Math.max(a, b), 0);
  if (loudest > 0) for (let i = 0; i < count; i++) out[i] /= loudest;
  return out;
}

/** 0 for a still window, otherwise 1..LEVELS. */
function step(level) {
  if (level < GATE) return 0;
  const above = Math.min(1, Math.max(0, (level - GATE) / (1 - GATE)));
  return Math.max(1, Math.ceil(above * LEVELS));
}

const r3 = (n) => Math.round(n * 1000) / 1000;

function event(timeMs, lengthMs, stepNumber) {
  const unit = stepNumber / LEVELS;
  const intensity = stepNumber === 0 ? 0 : MIN_INTENSITY + (MAX_INTENSITY - MIN_INTENSITY) * unit;
  return {
    Event: {
      Time: r3(timeMs / 1000),
      EventType: 'HapticContinuous',
      EventDuration: r3(lengthMs / 1000),
      EventParameters: [
        { ParameterID: 'HapticIntensity', ParameterValue: r3(intensity) },
      ],
    },
  };
}

/** Runs of one strength: [{ at, length, step }] covering the whole sound. */
function runsOf(levels, durationMs) {
  const runs = [];
  let at = 0;
  for (let i = 0; i < levels.length && at < durationMs; i++) {
    const length = Math.min(WINDOW_MS, durationMs - at);
    const s = step(levels[i]);
    const last = runs[runs.length - 1];
    if (last && last.step === s) last.length += length;
    else runs.push({ at, length, step: s });
    at += length;
  }
  return runs;
}

function ahapFrom(runs, durationMs, description) {
  const pattern = [];
  for (const run of runs) {
    if (run.step === 0) continue;
    for (let offset = 0; offset < run.length; offset += MAX_EVENT_S * 1000) {
      pattern.push(event(run.at + offset, Math.min(MAX_EVENT_S * 1000, run.length - offset), run.step));
    }
  }
  const lastEnd = runs.length ? runs[runs.length - 1].at + runs[runs.length - 1].length : 0;
  const stillTail = runs.length && runs[runs.length - 1].step === 0;
  if (!pattern.length || stillTail || lastEnd < durationMs) {
    // A zero-strength event at the very end gives the pattern the sound's length.
    pattern.push(event(durationMs - WINDOW_MS, WINDOW_MS, 0));
  }
  return {
    Version: 1.0,
    Metadata: { Project: 'Crit Alarm alarm haptics', Description: description },
    Pattern: pattern,
  };
}

/** Loudness at ENVELOPE_MS, 0 to 100, the loudest 20 ms window in each cell. */
function envelope(levels, durationMs) {
  const perCell = ENVELOPE_MS / WINDOW_MS;
  const cells = Math.ceil(durationMs / ENVELOPE_MS);
  const out = [];
  for (let c = 0; c < cells; c++) {
    let top = 0;
    for (let w = c * perCell; w < Math.min(levels.length, (c + 1) * perCell); w++) top = Math.max(top, levels[w]);
    out.push(Math.round(top * 100));
  }
  return out;
}

function write(name, ahap) {
  writeFileSync(join(OUT, `${name}.ahap`), JSON.stringify(ahap) + '\n');
}

const wanted = process.argv.slice(2);
mkdirSync(OUT, { recursive: true });

const sources = [
  ...bundledSounds(),
  { id: 'alarm', file: DEFAULT_RING, durationMs: 25000 },
].filter((s) => !wanted.length || wanted.includes(s.id));

let manifest = { sounds: {} };
try {
  manifest = JSON.parse(readFileSync(join(OUT, 'manifest.json'), 'utf8'));
} catch {
  // First run.
}
manifest.windowMs = WINDOW_MS;
manifest.gate = GATE;
manifest.levels = LEVELS;
manifest.envelopeMs = ENVELOPE_MS;

for (const sound of sources) {
  const levels = loudness(decode(sound.file), sound.durationMs);
  const runs = runsOf(levels, sound.durationMs);
  write(sound.id, ahapFrom(runs, sound.durationMs, `Follows the loudness of ${sound.id}.`));
  manifest.sounds[sound.id] = {
    source: sound.file.slice(ROOT.length + 1),
    sha256: sha256(sound.file),
    durationMs: sound.durationMs,
    envelope: envelope(levels, sound.durationMs),
  };
  const events = runs.filter((r) => r.step > 0).length;
  console.log(`${sound.id}: ${events} events, ${sound.durationMs} ms`);
}

if (!wanted.length || wanted.includes('steady')) {
  // For a sound the app has no pattern for: 0.6 s on, 0.4 s off, the same pulse the Android
  // fallback uses.
  const steady = ahapFrom(
    [
      { at: 0, length: 600, step: LEVELS },
      { at: 600, length: 400, step: 0 },
    ],
    1000,
    'A plain steady pulse for a sound with no pattern of its own.',
  );
  write('steady', steady);
  manifest.steadyDurationMs = 1000;
  console.log('steady: 1 event, 1000 ms');
}

manifest.sounds = Object.fromEntries(Object.entries(manifest.sounds).sort(([a], [b]) => a.localeCompare(b)));
writeFileSync(join(OUT, 'manifest.json'), JSON.stringify(manifest, null, 1) + '\n');

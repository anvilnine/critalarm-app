// Crit Alarm emergency sounds. Fourteen non-musical warning signals, synthesized here.
// Run from the repo root:
//   node tools/sounds/emergency.mjs                         (all 14)
//   node tools/sounds/emergency.mjs 07                      (one sound, by number)
//   node tools/sounds/emergency.mjs emergency_sos_horn      (one sound, by id)
// Writes one file for iOS and one for Android per sound into assets/sounds/, encoded as the
// ENCODING block below says (today: <id>.m4a AAC 64k and <id>.ogg Opus 48k, both 48 kHz mono).
// The 48 kHz 24-bit master wav lives in a temp folder and is deleted.
// Needs ffmpeg with libopus on PATH (AAC uses ffmpeg's own encoder). No samples, no network.
//
// None of these copy a real public alert: no 853 + 960 Hz pair, no Temporal-3 or Temporal-4
// rhythm, no national civil-defence pattern, no phone alarm.
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const SR = 48000, TAU = Math.PI * 2;
const OUT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..', 'assets', 'sounds');

// ---------- ENCODING: change a value here and rerun to re-encode all 14 ----------
// channels: 2 = stereo, 1 = mono. A mono file gets its own mono master (see master()).
// iOS gets AAC in m4a, not mp3: AVFoundation converts an m4a to caf at its exact length, while
// an mp3 comes out with encoder padding added. Changing ext also needs the matching extension
// in lib/core/sound/bundled_sounds.dart.
// opts are extra encoder flags, each there for a measured reason:
// - aac_coder fast: ffmpeg's default AAC coder overshoots short beeps by up to 5 dB
//   (speeding beeper decoded at +3.1 dBFS from a -1.9 dBFS master).
// - compression_level 5: libopus at its default 10 and 32k or 40k blew the yelp siren up to
//   -4 LUFS and +5 dBTP; 5 encodes it cleanly.
// - Opus 48k and cutoff 12000: mastered to -8.5 LUFS, the 32k files only got under -1.0 dBTP with
//   the shared limiter ceiling near -5 dBTP, which crushed the iOS file as well. At 48k the
//   ceiling settles near -3. The cutoff stops Opus spending bits rebuilding the top octave.
// Apple's aac_at encoder was tried: it still overshot one sound and padded m4a lengths.
// After encoding, every file is decoded and its true peak measured (ffmpeg ebur128, 4x
// oversampled). If either reads over MAX_DECODED_TP, the limiter ceiling drops by the overshoot
// and the sound is mastered and encoded again at the same loudness. Taking gain off instead would
// pull the file under the loudness target. The run fails if the ceiling never gets there.
const ENCODING = {
  ios: { ext: 'm4a', codec: 'aac', bitrate: '64k', sampleRate: 48000, channels: 1, opts: ['-aac_coder', 'fast'] },
  android: { ext: 'ogg', codec: 'libopus', bitrate: '48k', sampleRate: 48000, channels: 1, opts: ['-compression_level', '5', '-cutoff', '12000'] },
};
const MAX_DECODED_TP = -1.1, MAX_CEIL_ROUNDS = 8;

// Number in this file to the id the app stores against topics. Ids never change once shipped.
const IDS = {
  '01': 'emergency_hilo_siren',
  '02': 'emergency_wail_siren',
  '03': 'emergency_yelp_siren',
  '04': 'emergency_windup_siren',
  '05': 'emergency_klaxon',
  '06': 'emergency_sos_beeper',
  '07': 'emergency_sos_horn',
  '08': 'emergency_rapid_beeper',
  '09': 'emergency_red_alert',
  '10': 'emergency_endless_siren',
  '11': 'emergency_speeding_beeper',
  '12': 'emergency_proximity',
  '13': 'emergency_alarm_bell',
  '14': 'emergency_tone_ladder',
};
const PAD = 0.06; // digital silence at each end, seconds
// Every bundled sound has to read at least -9 LUFS on its decoded mono app file. -8.5 on the
// master leaves room for the AAC and Opus encodes to read a little lower.
const TARGET_LUFS = -8.5, CEIL_DBTP = -1.9;

// ---------- small helpers ----------
let seed = 7;
const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647) * 2 - 1;
const clamp = (x, a, b) => Math.max(a, Math.min(b, x));
const smooth = u => { u = clamp(u, 0, 1); return u * u * (3 - 2 * u); };
const db = d => Math.pow(10, d / 20);
const S = t => Math.round(t * SR);

function bus(dur) { const n = S(dur); return { n, dur, L: new Float64Array(n), R: new Float64Array(n) }; }
function add(b, x, g = 1, pan = 0, at = 0) { // pan -1..1, gentle law, centre = full both sides
  const gl = g * Math.min(1, 1 - pan), gr = g * Math.min(1, 1 + pan);
  for (let i = 0; i < x.length; i++) { const j = i + at; if (j >= b.n) break; b.L[j] += x[i] * gl; b.R[j] += x[i] * gr; }
}

// Band-limited additive oscillator. freq: number or per-sample array. amp(k) gives harmonic k weight.
// Harmonics fade out between 6 and 8 kHz so nothing loud lands above 9 kHz.
function osc(n, freq, amp = k => 1 / k, opts = {}) {
  const out = new Float64Array(n), maxK = opts.maxK || 60, lo = opts.lo || 6000, hi = opts.hi || 8000;
  const A = []; for (let k = 1; k <= maxK; k++) A.push(amp(k));
  let ph = opts.phase || 0;
  for (let i = 0; i < n; i++) {
    const f = typeof freq === 'number' ? freq : freq[i];
    ph += TAU * f / SR; if (ph > TAU) ph -= TAU;
    const s1 = Math.sin(ph), c2 = 2 * Math.cos(ph);
    let sPrev = 0, s = s1, acc = 0;
    for (let k = 1; k <= maxK; k++) {
      const kf = k * f; if (kf >= hi) break;
      const a = A[k - 1];
      if (a !== 0) acc += a * s * (kf < lo ? 1 : 0.5 + 0.5 * Math.cos(Math.PI * (kf - lo) / (hi - lo)));
      const sn = c2 * s - sPrev; sPrev = s; s = sn;
    }
    out[i] = acc;
  }
  return out;
}
const SAW = p => k => 1 / Math.pow(k, p);
const ODD = p => k => (k % 2 ? 1 / Math.pow(k, p) : 0);
const MIX = (oddP, evenG, evenP) => k => (k % 2 ? 1 / Math.pow(k, oddP) : evenG / Math.pow(k, evenP));

// RBJ biquad, applied in place on a Float64Array
function biquad(x, type, f, Q = 0.707, gainDb = 0) {
  const w = TAU * f / SR, c = Math.cos(w), s = Math.sin(w), al = s / (2 * Q), A = Math.pow(10, gainDb / 40);
  let b0, b1, b2, a0, a1, a2;
  if (type === 'lp') { b0 = (1 - c) / 2; b1 = 1 - c; b2 = b0; a0 = 1 + al; a1 = -2 * c; a2 = 1 - al; }
  else if (type === 'hp') { b0 = (1 + c) / 2; b1 = -(1 + c); b2 = b0; a0 = 1 + al; a1 = -2 * c; a2 = 1 - al; }
  else if (type === 'bp') { b0 = al; b1 = 0; b2 = -al; a0 = 1 + al; a1 = -2 * c; a2 = 1 - al; }
  else { b0 = 1 + al * A; b1 = -2 * c; b2 = 1 - al * A; a0 = 1 + al / A; a1 = -2 * c; a2 = 1 - al / A; }
  b0 /= a0; b1 /= a0; b2 /= a0; a1 /= a0; a2 /= a0;
  let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  for (let i = 0; i < x.length; i++) {
    const xi = x[i], y = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1; x1 = xi; y2 = y1; y1 = y; x[i] = y;
  }
  return x;
}
// Time-varying state-variable low-pass / band-pass (TPT form). fc and q per sample.
function svf(x, fcArr, Q, mode = 'lp') {
  const out = new Float64Array(x.length); let ic1 = 0, ic2 = 0; const k = 1 / Q;
  for (let i = 0; i < x.length; i++) {
    const g = Math.tan(Math.PI * clamp(fcArr[i], 20, 20000) / SR);
    const a1 = 1 / (1 + g * (g + k)), a2 = g * a1, a3 = g * a2;
    const v3 = x[i] - ic2, v1 = a1 * ic1 + a2 * v3, v2 = ic2 + a2 * ic1 + a3 * v3;
    ic1 = 2 * v1 - ic1; ic2 = 2 * v2 - ic2;
    out[i] = mode === 'lp' ? v2 : v1 * k;
  }
  return out;
}
const drive = (x, d) => { const n = Math.tanh(d); for (let i = 0; i < x.length; i++) x[i] = Math.tanh(d * x[i]) / n; return x; };
const mul = (x, e) => { for (let i = 0; i < x.length; i++) x[i] *= typeof e === 'function' ? e(i / SR) : e[i]; return x; };

// Gate envelope from note events [{t, len}], raised-cosine edges
function gate(n, events, atkS = 0.004, relS = 0.006, levelFn = () => 1) {
  const e = new Float64Array(n);
  for (const ev of events) {
    const a = S(ev.t), b = S(ev.t + ev.len), na = Math.max(1, S(ev.atk ?? atkS)), nr = Math.max(1, S(ev.rel ?? relS));
    const lv = ev.g ?? levelFn(ev.t);
    for (let i = a; i < b + nr && i < n; i++) {
      let v = 1;
      if (i - a < na) v = 0.5 - 0.5 * Math.cos(Math.PI * (i - a) / na);
      if (i >= b) v *= 0.5 + 0.5 * Math.cos(Math.PI * (i - b) / nr);
      e[i] = Math.max(e[i], v * lv);
    }
  }
  return e;
}
// Stereo ping-pong echo of a mono signal (wet only)
function echo(b, x, dl, dr, g, fb, lp = 3500, startT = 0) {
  const n = b.n, el = new Float64Array(n), er = new Float64Array(n), DL = S(dl), DR = S(dr), st = S(startT);
  for (let i = 0; i < n; i++) {
    const xl = i - DL >= st ? x[i - DL] : 0, xr = i - DR >= st ? x[i - DR] : 0;
    el[i] = g * xl + (i >= DL ? fb * er[i - DL] : 0);
    er[i] = g * xr + (i >= DR ? fb * el[i - DR] : 0);
  }
  biquad(el, 'lp', lp); biquad(er, 'lp', lp);
  for (let i = 0; i < n; i++) { b.L[i] += el[i]; b.R[i] += er[i]; }
}
// Per-sample frequency array built from f(t)
const curve = (n, f) => { const a = new Float64Array(n); for (let i = 0; i < n; i++) a[i] = f(i / SR); return a; };
// Morse SOS: dot 1, dash 3, intra 1, letter gap 3, word gap 7 => 34 units per repeat
function sosEvents(unit, reps, t0 = PAD) {
  const ev = [], marks = [1, 1, 1, 0, 3, 3, 3, 0, 1, 1, 1];
  for (let r = 0; r < reps; r++) {
    let t = t0 + r * 34 * unit;
    for (let i = 0; i < marks.length; i++) {
      const m = marks[i];
      if (m === 0) { t += 2 * unit; continue; } // letter gap: 1 already added + 2 = 3
      ev.push({ t, len: m * unit, rep: r }); t += (m + 1) * unit;
    }
  }
  return ev;
}

// ---------- mastering ----------
function kweight(x) {
  const y = new Float64Array(x.length);
  let x1 = 0, x2 = 0, y1 = 0, y2 = 0, z1 = 0, z2 = 0, w1 = 0, w2 = 0;
  for (let i = 0; i < x.length; i++) {
    const a = 1.53512485958697 * x[i] - 2.69169618940638 * x1 + 1.19839281085285 * x2 + 1.69065929318241 * y1 - 0.73248077421585 * y2;
    x2 = x1; x1 = x[i]; y2 = y1; y1 = a;
    const b = a - 2 * z1 + z2 + 1.99004745483398 * w1 - 0.99007225036621 * w2;
    z2 = z1; z1 = a; w2 = w1; w1 = b; y[i] = b;
  }
  return y;
}
// Integrated loudness (BS.1770) of one channel or two. R is null for a mono signal.
function lufs(L, R) {
  const kl = kweight(L), kr = R ? kweight(R) : null, blk = S(0.4), hop = S(0.1), z = [];
  for (let s = 0; s + blk <= L.length; s += hop) {
    let a = 0;
    for (let i = s; i < s + blk; i++) a += kl[i] * kl[i] + (kr ? kr[i] * kr[i] : 0);
    z.push(a / blk);
  }
  const ld = v => -0.691 + 10 * Math.log10(v);
  let g = z.filter(v => ld(v) > -70); if (!g.length) return -99;
  const rel = ld(g.reduce((a, b) => a + b, 0) / g.length) - 10;
  g = g.filter(v => ld(v) > rel);
  return ld(g.reduce((a, b) => a + b, 0) / g.length);
}
// 4x oversampled peak per sample (max over channels)
const SINC = (() => { const P = [0.25, 0.5, 0.75], T = 12, out = [];
  for (const p of P) { const c = []; for (let j = -T + 1; j <= T; j++) { const x = p - j, w = 0.5 + 0.5 * Math.cos(Math.PI * x / T); c.push((x === 0 ? 1 : Math.sin(Math.PI * x) / (Math.PI * x)) * w); } out.push(c); }
  return { out, T }; })();
function tpPeaks(L, R) {
  const n = L.length, pk = new Float64Array(n), { out, T } = SINC;
  for (const ch of [L, R]) for (let i = 0; i < n; i++) {
    let m = Math.abs(ch[i]);
    if (i >= T && i + T < n) for (const c of out) { let a = 0; for (let j = 0; j < c.length; j++) a += c[j] * ch[i - T + 1 + j]; if (Math.abs(a) > m) m = Math.abs(a); }
    if (m > pk[i]) pk[i] = m;
  }
  return pk;
}
function limit(L, R, gain, ceil) {
  const n = L.length, LA = 96, rel = 1 - Math.exp(-1 / (0.06 * SR));
  const l = new Float64Array(n), r = new Float64Array(n);
  for (let i = 0; i < n; i++) { l[i] = L[i] * gain; r[i] = R[i] * gain; }
  const pk = tpPeaks(l, r), req = new Float64Array(n);
  for (let i = 0; i < n; i++) req[i] = pk[i] > ceil ? ceil / pk[i] : 1;
  const a = new Float64Array(n); // min over [i, i+LA]
  for (let i = 0; i < n; i++) { let m = 1; for (let j = i; j <= i + LA && j < n; j++) if (req[j] < m) m = req[j]; a[i] = m; }
  const rr = new Float64Array(n); let prev = 1;
  for (let i = 0; i < n; i++) { prev = Math.min(a[i], prev + (1 - prev) * rel); rr[i] = prev; }
  let sum = 0; const g = new Float64Array(n);
  for (let i = 0; i < n; i++) { sum += rr[i]; if (i > LA) sum -= rr[i - LA - 1]; g[i] = sum / Math.min(i + 1, LA + 1); }
  for (let i = 0; i < n; i++) { l[i] *= g[i]; r[i] *= g[i]; }
  return [l, r];
}
// The fade out is longer than the fade in. A sound still loud at the pad, cut in 4 ms, left Opus's
// own DC filter decaying across the end silence (red alert's ogg pad settled at -75 dBFS); 20 ms
// takes the step out. The fade in stays short so the first hit keeps its attack.
function silenceEnds(L, R = null) {
  const n = L.length, p = S(PAD), f = S(0.004), fo = S(0.02);
  for (let i = 0; i < n; i++) {
    let g = 1;
    if (i < p || i >= n - p) g = 0;
    else if (i < p + f) g = 0.5 - 0.5 * Math.cos(Math.PI * (i - p) / f);
    else if (i >= n - p - fo) g = 0.5 - 0.5 * Math.cos(Math.PI * (n - p - i) / fo);
    L[i] *= g; if (R) R[i] *= g;
  }
}
// Short-term loudness (K-weighted mean square over a centred 3 s window) per sample, in LUFS.
// Mono or the sum of two channels, as lufs() does.
function shortTerm(L, R) {
  const kl = kweight(L), kr = R ? kweight(R) : null, n = L.length, h = S(1.5), sq = new Float64Array(n + 1);
  for (let i = 0; i < n; i++) sq[i + 1] = sq[i] + kl[i] * kl[i] + (kr ? kr[i] * kr[i] : 0);
  const out = new Float64Array(n);
  for (let i = 0; i < n; i++) { const a = Math.max(0, i - h), b = Math.min(n, i + h); out[i] = -0.691 + 10 * Math.log10((sq[b] - sq[a]) / S(3) || 1e-12); }
  return out;
}
// Shaping ahead of the limiter, so the sound gets loud without the limiter doing all the work:
// - presence: +3 dB around 3 kHz, where phone speakers and ears are most sensitive;
// - leveler: where the 3 s loudness sits more than LEVEL_LU under the whole sound (a sparse start,
//   the quiet end of a crescendo), a slow gain lifts it, up to LEVEL_MAX_DB. The build-up stays,
//   it just starts from a level nobody sleeps through;
// - parallel compression: half the signal through a 4:1 compressor with makeup, mixed back with
//   the dry half, so quiet notes and echo tails come up and the attacks keep their shape.
const LEVEL_LU = 3.5, LEVEL_MAX_DB = 8;
function shape(L, R) {
  const chans = R ? [L, R] : [L];
  for (const ch of chans) biquad(ch, 'pk', 3000, 0.8, 3);
  const st = shortTerm(L, R), I = lufs(L, R), sm = S(0.25), n = L.length, g = new Float64Array(n);
  for (let i = 0; i < n; i++) g[i] = clamp(I - LEVEL_LU - st[i], 0, LEVEL_MAX_DB);
  let acc = 0; const lv = new Float64Array(n); // 0.5 s moving average, so the lift never pumps
  for (let i = -sm; i < n + sm; i++) { if (i + sm < n) acc += g[Math.max(0, i + sm)]; if (i - sm - 1 >= 0) acc -= g[i - sm - 1]; if (i >= 0 && i < n) lv[i] = db(acc / (2 * sm + 1)); }
  for (const ch of chans) for (let i = 0; i < n; i++) ch[i] *= lv[i];
  let pk = 0; for (const ch of chans) for (let i = 0; i < n; i++) pk = Math.max(pk, Math.abs(ch[i]));
  const th = pk * db(-18), ratio = 4, makeup = db(6), att = 1 - Math.exp(-1 / (0.004 * SR)), rel = 1 - Math.exp(-1 / (0.16 * SR));
  let env = 0;
  for (let i = 0; i < n; i++) {
    const a = Math.max(Math.abs(L[i]), R ? Math.abs(R[i]) : 0);
    env += (a - env) * (a > env ? att : rel);
    const cg = env > th ? Math.pow(th / env, 1 - 1 / ratio) : 1, w = 0.5 + 0.5 * cg * makeup;
    L[i] *= w; if (R) R[i] *= w;
  }
}
// Soft clip at 4x: ffmpeg resamples to 192 kHz, rounds everything near the top with a tanh curve
// that never passes `threshold`, and comes back to 48 kHz. Run before the limiter, it cuts the
// crest factor so the limiter has less to do. Without it the limiter alone could not get the
// klaxon past -10 LUFS at any gain: it only follows the waveform's own peaks.
// The low-pass after it takes off the harmonics the clip adds above the master's 8.2 kHz band.
// Left in, AAC 64k decoded the klaxon 4.5 dB over its master and Opus kept the ceiling falling.
// The 120 Hz high-pass takes out the DC and slow drift a tanh puts on a lopsided waveform (red
// alert's m4a sat at +0.030). Opus strips DC and AAC keeps it, so the two files differed, and the
// ogg's end silence sat at -40 dBFS while the step decayed. 25 Hz removed the DC but left beeper
// tails at -67 dBFS; the master is already high-passed at 170 Hz, so 120 Hz costs no tone.
const CLIP_OVER_CEIL_DB = 1.5;
function softClip(chans, gain, thresholdDb) {
  const n = chans[0].length, C = chans.length, buf = Buffer.alloc(n * C * 8);
  for (let i = 0; i < n; i++) for (let c = 0; c < C; c++) buf.writeDoubleLE(chans[c][i] * gain, (i * C + c) * 8);
  const r = spawnSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-f', 'f64le', '-ar', String(SR), '-ac', String(C), '-i', '-',
    '-af', `aresample=192000,asoftclip=type=tanh:threshold=${db(thresholdDb)},aresample=${SR},lowpass=f=8500:p=2,lowpass=f=8500:p=2,highpass=f=120:p=2`, '-f', 'f64le', '-'], { input: buf, maxBuffer: 1 << 30 });
  if (r.status !== 0) throw new Error(r.stderr.toString());
  const out = chans.map(() => new Float64Array(n));
  for (let i = 0; i < n; i++) for (let c = 0; c < C; c++) out[c][i] = r.stdout.readDoubleLE((i * C + c) * 8);
  return out;
}
// Masters the bus to TARGET_LUFS under ceilDb (true peak) and returns its channels (one or two).
// Mono folds L and R to (L + R) / 2 BEFORE the limiter and the loudness match. Letting ffmpeg
// downmix the stereo master afterwards pushed true peaks past 0 dBTP and moved loudness by
// several LU, because the limiter never saw the summed signal. b is left untouched.
function master(b, channels = 2, ceilDb = CEIL_DBTP) {
  let L = Float64Array.from(b.L), R = Float64Array.from(b.R);
  if (channels === 1) { for (let i = 0; i < L.length; i++) L[i] = (L[i] + R[i]) / 2; R = null; }
  for (const ch of R ? [L, R] : [L]) { biquad(ch, 'hp', 170, 0.707); biquad(ch, 'hp', 170, 0.707); biquad(ch, 'lp', 8200, 0.707); biquad(ch, 'lp', 8200, 0.707); }
  silenceEnds(L, R);
  shape(L, R);
  let pk = 0; for (let i = 0; i < L.length; i++) pk = Math.max(pk, Math.abs(L[i]), R ? Math.abs(R[i]) : 0);
  let gain = db(-6) / pk, out, lv, ceil = db(ceilDb);
  // Secant search on the gain in dB. Once the limiter works hard, each dB of gain buys well under
  // 1 LU, so stepping by the shortfall alone stalls short of the target.
  let prev = null;
  for (let it = 0; it < 24; it++) {
    // limit() takes two channels; a mono signal goes in as the same array twice.
    const c = softClip(R ? [L, R] : [L], gain, ceilDb + CLIP_OVER_CEIL_DB);
    out = limit(c[0], c[1] || c[0], 1, ceil); lv = lufs(out[0], R ? out[1] : null);
    if (Math.abs(lv - TARGET_LUFS) < 0.05) break;
    const g = 20 * Math.log10(gain);
    let step = TARGET_LUFS - lv;
    if (prev && Math.abs(lv - prev.lv) > 1e-3 && g !== prev.g) step *= clamp((g - prev.g) / (lv - prev.lv), 0.5, 12);
    prev = { g, lv };
    gain = db(g + clamp(step, -12, 12));
  }
  if (Math.abs(lv - TARGET_LUFS) >= 0.05) throw new Error(`master reached ${lv.toFixed(2)} LUFS, not ${TARGET_LUFS}, under a ${ceilDb.toFixed(2)} dBTP ceiling`);
  const chans = R ? [out[0], out[1]] : [out[0]];
  silenceEnds(chans[0], chans[1] || null);
  return { chans, lufs: lv };
}
function writeWav24(path, chans) {
  const n = chans[0].length, C = chans.length, data = Buffer.alloc(n * 3 * C), h = Buffer.alloc(44);
  for (let i = 0; i < n; i++) for (let c = 0; c < C; c++) {
    const v = Math.round(clamp(chans[c][i], -1, 1) * 8388607);
    data.writeIntLE(v, (i * C + c) * 3, 3);
  }
  h.write('RIFF', 0); h.writeUInt32LE(36 + data.length, 4); h.write('WAVE', 8); h.write('fmt ', 12);
  h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(C, 22); h.writeUInt32LE(SR, 24);
  h.writeUInt32LE(SR * 3 * C, 28); h.writeUInt16LE(3 * C, 32); h.writeUInt16LE(24, 34); h.write('data', 36); h.writeUInt32LE(data.length, 40);
  writeFileSync(path, Buffer.concat([h, data]));
}

// ---------- the sounds ----------
const SOUNDS = {};

// 01 two-tone hi-lo: a fourth apart (1020 / 765 Hz), 0.45 s each, 18 cycles
SOUNDS['01'] = { slug: 'hilo', fn() {
  const P = 0.9, reps = 18, b = bus(P * reps), T = b.dur;
  const f = curve(b.n, t => { const u = (t % P) / P;
    const x = u < 0.5 ? smooth(u / 0.02) : 1 - smooth((u - 0.5) / 0.02); return 765 * Math.pow(1020 / 765, x); });
  const main = osc(b.n, f, MIX(1.25, 0.18, 1.5));
  mul(main, t => db(-6 + 6 * smooth(t / (T * 0.8))));
  add(b, main);
  const up = osc(b.n, curve(b.n, t => f[S(t)] * 2), SAW(2.2));
  mul(up, t => t > 12 * P ? db(-15) * smooth((t - 12 * P) / 1.5) : 0); add(b, up, 1, 0);
  echo(b, main, 0.225, 0.3375, 0.28, 0.25, 3200, 6 * P);
  return b; } };

// 02 wail: slow log sweep 480 to 1500 Hz, 4 s period, 4 periods; a second siren joins off-phase
SOUNDS['02'] = { slug: 'wail', fn() {
  const P = 4, b = bus(16), T = b.dur;
  const sweep = off => t => { const u = ((t + off) % P) / P; const x = u < 0.6 ? 1 - Math.pow(1 - u / 0.6, 2) : 1 - Math.pow((u - 0.6) / 0.4, 1.4); return 480 * Math.pow(1500 / 480, x); };
  const f = curve(b.n, sweep(0));
  const dark = osc(b.n, f, SAW(2.1)), bright = osc(b.n, f, MIX(1.1, 0.4, 1.4));
  const main = new Float64Array(b.n);
  for (let i = 0; i < b.n; i++) { const e = smooth(i / SR / T); main[i] = (dark[i] * (1 - e) + bright[i] * e * 0.8) * db(-5 + 5 * e); }
  add(b, main);
  const f2 = curve(b.n, t => sweep(2)(t) * 1.012);
  const s2 = osc(b.n, f2, SAW(1.8)); mul(s2, t => t > 7.8 ? db(-11) * smooth((t - 7.8) / 2) : 0);
  add(b, s2, 1, -0.55);
  echo(b, main, 0.29, 0.41, 0.22, 0.3, 3000, 4);
  return b; } };

// 03 yelp: fast 700 to 1700 Hz sweep, 0.33 s period, 48 periods
SOUNDS['03'] = { slug: 'yelp', fn() {
  const P = 0.33, b = bus(P * 48), T = b.dur;
  const f = curve(b.n, t => { const u = (t % P) / P; const x = u < 0.62 ? Math.sin(Math.PI / 2 * u / 0.62) : 1 - smooth((u - 0.62) / 0.38); return 700 * Math.pow(1700 / 700, x); });
  const main = osc(b.n, f, MIX(1.3, 0.3, 1.6)); mul(main, t => db(-6 + 6 * smooth(t / (T * 0.75)))); add(b, main);
  const dbl = osc(b.n, curve(b.n, t => f[S(t)] * 1.009), SAW(1.7)); mul(dbl, t => t > T * 0.6 ? db(-10) * smooth((t - T * 0.6) / 1) : 0);
  add(b, dbl, 1, 0.6);
  echo(b, main, 0.165, 0.248, 0.24, 0.2, 3000, T / 3);
  return b; } };

// 04 air-raid wind-up: a mechanical rotor siren winds up, holds, winds down, three times, each higher.
// A second rotor a major third up joins in the second and third cycles.
SOUNDS['04'] = { slug: 'windup', fn() {
  const P = 5.5, b = bus(P * 3), tops = [820, 900, 990];
  const spd = t => { const c = Math.floor(t / P), u = t - c * P; let s;
    if (u < 3) s = 0.18 + 0.82 * (1 - Math.exp(-u / 0.85)) / (1 - Math.exp(-3 / 0.85));
    else if (u < 4) s = 1 + 0.01 * Math.sin(TAU * 1.5 * (u - 3));
    else s = 0.25 + 0.75 * Math.exp(-(u - 4) / 0.55);
    return { c: Math.min(c, 2), s }; };
  const f = curve(b.n, t => { const { c, s } = spd(t); return tops[c] * s; });
  const amp = t => { const { s } = spd(t); return smooth((s - 0.15) / 0.7); };
  const rotor = osc(b.n, f, ODD(1.15)); const even = osc(b.n, f, k => (k % 2 ? 0 : 0.2 / k));
  const main = new Float64Array(b.n); for (let i = 0; i < b.n; i++) main[i] = (rotor[i] + even[i]) * amp(i / SR);
  // air: noise band riding the pitch
  const nz = new Float64Array(b.n); for (let i = 0; i < b.n; i++) nz[i] = rnd();
  const air = svf(nz, curve(b.n, t => f[S(t)] * 2), 6, 'bp'); mul(air, t => 0.25 * amp(t));
  for (let i = 0; i < b.n; i++) main[i] += air[i];
  mul(main, t => db(-4 + 4 * smooth(t / 14)));
  add(b, main);
  const r2 = osc(b.n, curve(b.n, t => f[S(t)] * 1.25), ODD(1.3)); mul(r2, t => t > P ? db(-7) * amp(t) * smooth((t - P) / 1) : 0);
  add(b, r2, 1, 0.3);
  echo(b, main, 0.31, 0.43, 0.25, 0.35, 2600, 0);
  return b; } };

// klaxon / horn voice: rich saw through brassy formants, a little drive
function hornVoice(n, f, f0, formants) {
  const x = osc(n, f, SAW(1.0), { maxK: 80 });
  for (const [fc, g, q] of formants) biquad(x, 'pk', fc, q, g);
  biquad(x, 'lp', 4500, 0.7);
  // phones cannot play the fundamental; keep the horn's weight in the 500 Hz to 4 kHz band
  biquad(x, 'hp', 520, 0.6); biquad(x, 'hp', 520, 0.6);
  let pk = 0; for (const v of x) pk = Math.max(pk, Math.abs(v));
  for (let i = 0; i < n; i++) x[i] /= pk;
  return drive(x, 1.8);
}
// 05 klaxon: electric "aa-oo" horn blasts that bend up into pitch; 2, then 3, then 4 blasts per bar
SOUNDS['05'] = { slug: 'klaxon', fn() {
  const bar = 2, b = bus(bar * 8), ev = [];
  for (let k = 0; k < 8; k++) {
    const t0 = k * bar + (k === 0 ? PAD : 0);
    const [starts, len] = k < 3 ? [[0, 1.0], 0.66] : k < 6 ? [[0, 0.62, 1.24], 0.5] : [[0, 0.48, 0.96, 1.44], 0.38];
    for (const s of starts) ev.push({ t: t0 + s, len: len - (k === 0 && s === 0 ? PAD : 0), bar: k });
  }
  const f = new Float64Array(b.n).fill(310);
  for (const e of ev) { const a = S(e.t); for (let i = 0; i < S(e.len + 0.03); i++) if (a + i < b.n) f[a + i] = 310 * (0.62 + 0.38 * smooth(i / SR / 0.2)); }
  const x = hornVoice(b.n, f, 310, [[1150, 9, 1.6], [2500, 6, 2.5], [600, -4, 1]]);
  mul(x, gate(b.n, ev, 0.012, 0.03, t => db(-5 + 5 * smooth(t / 12))));
  add(b, x);
  const up = hornVoice(b.n, curve(b.n, t => f[S(t)] * 2), 620, [[1800, 6, 2]]);
  mul(up, gate(b.n, ev.filter(e => e.bar >= 6), 0.012, 0.03, () => db(-10))); add(b, up, 1, -0.35);
  echo(b, x, 0.09, 0.13, 0.25, 0.15, 3000, 0);
  return b; } };

// 06 SOS beeper: clean 1650 Hz beep, unit 100 ms, five repeats, layers join each repeat
SOUNDS['06'] = { slug: 'sos-beeper', fn() {
  const u = 0.1, reps = 5, b = bus(34 * u * reps), ev = sosEvents(u, reps);
  const lvl = t => db(-6 + 6 * Math.min(1, Math.floor((t - PAD) / (34 * u)) / 3));
  const beep = osc(b.n, 1650, k => [1, 0.22, 0.08, 0.03][k - 1] || 0);
  mul(beep, gate(b.n, ev, 0.004, 0.006, lvl)); add(b, beep);
  const low = osc(b.n, 825, k => [1, 0.3, 0.12][k - 1] || 0);
  mul(low, gate(b.n, ev.filter(e => e.rep >= 2), 0.004, 0.006, () => db(-8))); add(b, low, 1, 0);
  const hi = osc(b.n, 3300, k => (k === 1 ? 1 : 0));
  mul(hi, gate(b.n, ev.filter(e => e.rep >= 4), 0.004, 0.006, () => db(-16))); add(b, hi);
  echo(b, beep, 0.15, 0.2, 0.3, 0.2, 3000, 34 * u);
  return b; } };

// 07 SOS ship horn: two-pipe horn (233 + 349 Hz), unit 170 ms, three repeats, harbour echo
SOUNDS['07'] = { slug: 'sos-horn', fn() {
  const u = 0.17, reps = 3, b = bus(34 * u * reps), ev = sosEvents(u, reps);
  const lv = t => db(-5 + 5 * Math.floor((t - PAD) / (34 * u)) / 2);
  const g = gate(b.n, ev, 0.03, 0.045, lv);
  const h1 = hornVoice(b.n, 233, 233, [[900, 8, 1.4], [2100, 6, 2]]);
  const h2 = hornVoice(b.n, 349, 349, [[1300, 6, 1.5]]);
  const main = new Float64Array(b.n); for (let i = 0; i < b.n; i++) main[i] = (h1[i] + 0.6 * h2[i]) * g[i];
  add(b, main);
  const oct = hornVoice(b.n, 466, 466, [[1800, 6, 2]]);
  mul(oct, gate(b.n, ev.filter(e => e.rep >= 2), 0.03, 0.045, () => db(-9))); add(b, oct, 1, 0.3);
  echo(b, main, 0.37, 0.52, 0.22, 0.32, 2200, 34 * u);
  return b; } };

// 08 rapid digital beeper: bip-bip pairs that tighten into a continuous two-pitch chatter
SOUNDS['08'] = { slug: 'rapid-beeper', fn() {
  const bar = 1.6, b = bus(bar * 10), A = [], B = [], low = [];
  for (let k = 0; k < 10; k++) {
    const t0 = k * bar;
    if (k < 6) { const step = k < 3 ? 0.4 : 0.2; for (let t = 0; t < bar - 1e-9; t += step) { A.push({ t: t0 + t + PAD, len: 0.05 }); A.push({ t: t0 + t + PAD + 0.1, len: 0.05 }); } }
    else for (let j = 0; j < 20; j++) (j % 2 ? B : A).push({ t: t0 + PAD + j * 0.08, len: 0.04 });
    if (k >= 8) for (let j = 0; j < 8; j++) low.push({ t: t0 + PAD + j * 0.2, len: 0.07 });
  }
  const lv = t => db(-6 + 6 * smooth(t / 12));
  const tone = (f, ev, g) => { const x = osc(b.n, f, k => [1, 0.12, 0.08][k - 1] || 0); return mul(x, gate(b.n, ev, 0.002, 0.004, g)); };
  const a = tone(2400, A, lv), bb = tone(2880, B, lv), lo = tone(1200, low, () => db(-9));
  add(b, a); add(b, bb); add(b, lo);
  const mix = new Float64Array(b.n); for (let i = 0; i < b.n; i++) mix[i] = a[i] + bb[i];
  echo(b, mix, 0.12, 0.18, 0.22, 0.1, 3500, 8 * bar);
  return b; } };

// 09 sci-fi red alert: buzzing whoop 330 to 720 Hz through a resonant filter that opens with it
SOUNDS['09'] = { slug: 'red-alert', fn() {
  const P = 1.25, reps = 13, b = bus(P * reps), ev = [];
  for (let r = 0; r < reps; r++) ev.push({ t: r * P + (r ? 0 : PAD), len: 0.95 - (r ? 0 : PAD), r });
  const f = curve(b.n, t => { const u = clamp((t % P) / 0.95, 0, 1); return 330 * Math.pow(720 / 330, Math.pow(u, 1.6)); });
  const voice = (fr) => {
    const src = osc(b.n, fr, MIX(1.0, 0.7, 1.0), { maxK: 80 });
    const y = svf(src, curve(b.n, t => fr[S(t)] * 4.2), 3.5, 'lp');
    biquad(y, 'hp', 420, 0.6);
    let pk = 0; for (const v of y) pk = Math.max(pk, Math.abs(v)); for (let i = 0; i < y.length; i++) y[i] /= pk;
    return drive(y, 2.2);
  };
  const main = voice(f); mul(main, gate(b.n, ev, 0.02, 0.05, t => db(-5 + 5 * smooth(t / 12)))); add(b, main);
  const fifth = voice(curve(b.n, t => f[S(t)] * 1.5));
  mul(fifth, gate(b.n, ev.filter(e => e.r >= 4), 0.02, 0.05, t => db(-10) * smooth((t - 4 * P) / 2)));
  // slight time offset between sides gives width without pulling the centre
  add(b, fifth, 1, -0.5); add(b, fifth.subarray(S(0.012)), 1, 0.5);
  echo(b, main, 0.21, 0.3, 0.2, 0.25, 2800, 8 * P);
  return b; } };

// 10 Shepard siren: octave-spaced partials glide up two octaves over the loop under a
// fixed bell curve (centre 1.3 kHz), so the pitch seems to climb forever. A pulse deepens over time.
SOUNDS['10'] = { slug: 'shepard', fn() {
  const T = 16, b = bus(T), K = 10, centre = Math.log2(1300), sig = 1.0;
  const L = new Float64Array(b.n), R = new Float64Array(b.n), ph = new Float64Array(K);
  for (let i = 0; i < b.n; i++) {
    const t = i / SR, sh = 2 * t / T, depth = 0.15 + 0.7 * smooth(t / 13);
    const pulse = 1 - depth * (0.5 - 0.5 * Math.cos(TAU * 4 * t + Math.PI));
    let l = 0, r = 0;
    for (let k = 0; k < K; k++) {
      const f = 40 * Math.pow(2, k + sh), w = Math.exp(-Math.pow(Math.log2(f) - centre, 2) / (2 * sig * sig));
      ph[k] += TAU * f / SR; if (ph[k] > TAU) ph[k] -= TAU;
      if (w < 1e-3 || f > 8000) continue;
      const s = w * (Math.sin(ph[k]) + 0.15 * Math.sin(2 * ph[k])), p = k % 2 ? 0.22 : -0.22;
      l += s * (1 - p); r += s * (1 + p);
    }
    L[i] = Math.tanh(1.4 * l * pulse); R[i] = Math.tanh(1.4 * r * pulse);
  }
  add(b, L, 1, -1); add(b, R, 1, 1);
  return b; } };

// 11 Risset beeper: layered beeps whose tempo doubles every loop while the layers cross-fade,
// so it seems to speed up forever. The beat grid lines up again at the wrap.
SOUNDS['11'] = { slug: 'risset', fn() {
  const T = 16, b = bus(T), n = 12, ev = [];
  for (let k = 0; k <= 6; k++) {
    const N = n * Math.pow(2, k);
    for (let m = 0; m < N; m++) {
      const t = T * Math.log2(1 + m / N); if (t < PAD || t > T - PAD - 0.03) continue;
      const w = Math.exp(-Math.pow(k + t / T - 3.2, 2) / 2); if (w < 0.02) continue;
      ev.push({ t, len: 0.022, g: w, k });
    }
  }
  const beep = osc(b.n, 1900, k => [1, 0.2, 0.1][k - 1] || 0);
  mul(beep, gate(b.n, ev, 0.002, 0.004));
  // overlapping beeps: sum envelopes rather than max
  add(b, beep);
  const tick = osc(b.n, 950, k => [1, 0.3][k - 1] || 0);
  mul(tick, gate(b.n, ev.filter(e => e.g > 0.6), 0.002, 0.01, () => 0.35)); add(b, tick);
  echo(b, beep, 0.07, 0.11, 0.18, 0.1, 3500, 0);
  return b; } };

// 12 proximity: beeps close in faster and faster until one solid tone, twice; the second pass is higher
SOUNDS['12'] = { slug: 'proximity', fn() {
  const C = 8, b = bus(C * 2);
  for (let c = 0; c < 2; c++) {
    const ev = [], t0 = c * C; let t = PAD, iv = c ? 0.45 : 0.55; // the second pass closes in faster
    while (t < 6.0) { ev.push({ t: t0 + t, len: 0.06 }); t += iv; iv = Math.max(0.075, iv * 0.9); }
    // The first solid tone holds into the second pass. With a 0.5 s gap there, the 3 s after it
    // (gap plus sparse beeps) measured -14.6 LUFS short-term, under the -14 floor.
    ev.push({ t: t0 + 6.05, len: c ? 1.5 : 1.85 });
    const f = c ? 2080 : 1850;
    const x = osc(b.n, f, k => [1, 0.18, 0.1, 0.04][k - 1] || 0);
    mul(x, gate(b.n, ev, 0.003, 0.008, tt => db(-5 + 4 * smooth((tt - t0) / 7) + c)));
    add(b, x);
    if (c) { const lo = osc(b.n, f / 2, k => [1, 0.3, 0.15][k - 1] || 0); mul(lo, gate(b.n, ev, 0.003, 0.008, () => db(-10))); add(b, lo, 1, 0.25);
      echo(b, x, 0.13, 0.19, 0.22, 0.15, 3500, C); }
  }
  return b; } };

// 13 alarm bell: electric fire-style bell, hammer at 17 strikes/s on a plate (modal synthesis).
// Short rings, then longer, then a second bell joins.
SOUNDS['13'] = { slug: 'bell', fn() {
  const b = bus(16);
  const ring = (f1, rings, pan, lvl) => {
    const x = new Float64Array(b.n);
    for (const [t0, len] of rings) for (let t = t0; t < t0 + len; t += 1 / 17) { const i = S(t); if (i < b.n) x[i] += lvl(t) * (0.85 + 0.15 * rnd()); }
    const modes = [[1, 0.55, 1], [1.594, 0.42, 0.7], [2.136, 0.33, 0.55], [2.296, 0.3, 0.45], [2.653, 0.24, 0.35], [3.156, 0.18, 0.25]];
    const y = new Float64Array(b.n);
    for (const [ratio, tau, g] of modes) {
      const w = TAU * f1 * ratio / SR; if (f1 * ratio > 7500) continue;
      const r = Math.exp(-1 / (tau * SR)), c1 = 2 * r * Math.cos(w), c2 = -r * r, s = Math.sin(w) * g;
      let y1 = 0, y2 = 0;
      for (let i = 0; i < b.n; i++) { const v = s * x[i] + c1 * y1 + c2 * y2; y2 = y1; y1 = v; y[i] += v; }
    }
    add(b, y, 1, pan); return y;
  };
  const rings = [[PAD, 1.45], [2, 1.45], [4, 1.45], [6, 1.45], [8, 2.6], [11, 2.6], [14, 1.25]];
  const lvl = t => db(-6 + 6 * smooth(t / 12));
  const main = ring(1150, rings, 0, lvl);
  ring(1385, rings.filter(r => r[0] >= 8).map(([t, l]) => [t + 0.029, l]), 0.45, t => db(-6) * lvl(t));
  echo(b, main, 0.17, 0.23, 0.18, 0.2, 3000, 4);
  return b; } };

// 14 ladder: eight-step stepped tone climbing 600 to 1650 Hz every 2 s; layers pile on each pair of ladders
SOUNDS['14'] = { slug: 'ladder', fn() {
  const L2 = 2, b = bus(L2 * 8), ev = [], st = 0.22;
  const f = new Float64Array(b.n).fill(600);
  for (let l = 0; l < 8; l++) for (let s = 0; s < 8; s++) {
    const t = l * L2 + s * st + (l === 0 && s === 0 ? PAD : 0), len = st - 0.03 - (l === 0 && s === 0 ? PAD : 0);
    const fs = 600 * Math.pow(1650 / 600, s / 7);
    ev.push({ t, len, l, s });
    const a = S(t); for (let i = 0; i < S(len + 0.03); i++) if (a + i < b.n) f[a + i] = fs * (1 + 0.035 * Math.exp(-i / SR / 0.012));
  }
  const lv = t => db(-6 + 6 * smooth(t / 13));
  const main = osc(b.n, f, ODD(1.45)); const ev2 = osc(b.n, f, k => (k % 2 ? 0 : 0.15 / k));
  for (let i = 0; i < b.n; i++) main[i] += ev2[i];
  const g = gate(b.n, ev, 0.004, 0.012, lv);
  // top steps on the last two ladders flutter
  for (const e of ev) if (e.l >= 6 && e.s >= 5) { const a = S(e.t); for (let i = 0; i < S(e.len); i++) g[a + i] *= 0.75 + 0.25 * Math.cos(TAU * 18 * i / SR); }
  mul(main, g); add(b, main);
  const oct = osc(b.n, curve(b.n, t => f[S(t)] * 2), SAW(2.4));
  mul(oct, gate(b.n, ev.filter(e => e.l >= 4), 0.004, 0.012, () => db(-12))); add(b, oct, 1, 0);
  echo(b, main, 0.11, 0.165, 0.22, 0.12, 3200, 2 * L2);
  return b; } };

// ---------- run ----------
const only = process.argv[2];
if (only && !SOUNDS[only] && !Object.values(IDS).includes(only)) {
  console.error(`unknown sound "${only}". Use 01 to 14 or one of: ${Object.values(IDS).join(', ')}`);
  process.exit(1);
}
// bitexact keeps encoder version strings and random Ogg serial numbers out of the files, so a
// second run writes the same bytes. map_metadata -1 drops the wav's tags.
const ff = args => {
  const r = spawnSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', ...args]);
  if (r.status !== 0) throw new Error(r.error ? String(r.error) : r.stderr.toString());
};
const same = ['-map_metadata', '-1', '-fflags', '+bitexact', '-flags:a', '+bitexact'];
// Integrated loudness and true peak (4x oversampled) of a file once decoded and folded to mono.
const decodedLevels = file => {
  const e = spawnSync('ffmpeg', ['-hide_banner', '-nostats', '-i', file, '-ac', '1', '-af', 'ebur128=peak=true', '-f', 'null', '-'], { encoding: 'utf8' }).stderr;
  const last = re => +e.match(re).pop().match(/-?[\d.]+/)[0];
  return { I: last(/I:\s+-?[\d.]+ LUFS/g), TP: last(/Peak:\s+-?[\d.]+ dBFS/g) };
};
const encode = (wav, platform, id) => {
  const e = ENCODING[platform], out = resolve(OUT, `${id}.${e.ext}`);
  ff(['-i', wav, ...same, '-ac', String(e.channels), '-ar', String(e.sampleRate), '-c:a', e.codec, '-b:a', e.bitrate, ...(e.opts || []), out]);
  return decodedLevels(out);
};
const tmp = mkdtempSync(join(tmpdir(), 'critalarm-emergency-'));
try {
  for (const [num, def] of Object.entries(SOUNDS).sort(([a], [b]) => a.localeCompare(b))) {
    const id = IDS[num];
    if (only && only !== num && only !== id) continue;
    seed = 7;
    const b = def.fn();
    // Same rule as generate.py: every bundled sound is 10 to 20 seconds long.
    if (b.dur < 10 || b.dur > 20) throw new Error(`${id} is ${b.dur.toFixed(2)} s, outside 10 to 20 s`);
    // One master per channel count the ENCODING block asks for, so ffmpeg never downmixes.
    // The ceiling drops until every decoded file reads under MAX_DECODED_TP.
    let ceil = CEIL_DBTP, masters, got;
    for (let round = 0; ; round++) {
      masters = {}; got = [];
      for (const platform of Object.keys(ENCODING)) {
        const c = ENCODING[platform].channels;
        if (!masters[c]) {
          const m = master(b, c, ceil), wav = join(tmp, `${id}-${c}ch.wav`);
          writeWav24(wav, m.chans);
          masters[c] = { wav, lufs: m.lufs };
        }
        got.push({ ext: ENCODING[platform].ext, ...encode(masters[c].wav, platform, id) });
      }
      const worst = Math.max(...got.map(g => g.TP));
      if (worst <= MAX_DECODED_TP) break;
      if (round === MAX_CEIL_ROUNDS - 1) throw new Error(`${id}: decoded true peak still ${worst.toFixed(1)} dBTP after ${MAX_CEIL_ROUNDS} rounds`);
      ceil -= worst - MAX_DECODED_TP + 0.05;
    }
    const levels = Object.entries(masters).map(([c, m]) => `${m.lufs.toFixed(2)} LUFS (${c} ch)`).join(', ');
    console.log(`${id.padEnd(26)} ${b.dur.toFixed(2)} s  ${levels}  ceiling ${ceil.toFixed(2)} dBTP  ${got.map(g => `${g.ext} ${g.I.toFixed(1)} LUFS ${g.TP.toFixed(1)} dBTP`).join(', ')}`);
  }
} finally {
  rmSync(tmp, { recursive: true, force: true });
}

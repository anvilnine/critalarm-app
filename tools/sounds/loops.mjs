// Crit Alarm seamless loops. Five Shepard-scale plus Risset-rhythm alarms, synthesized here.
// Run from the repo root:
//   node tools/sounds/loops.mjs                  (all five)
//   node tools/sounds/loops.mjs ascend           (one, by name)
//   node tools/sounds/loops.mjs loop_ascend      (one, by id)
// Writes one file for iOS and one for Android per loop into assets/sounds/, encoded as the
// ENCODING block below says (today: <id>.m4a AAC 64k and <id>.ogg Opus 48k, both 48 kHz mono).
// Needs Node 22 or later and ffmpeg with libopus on PATH. On macOS it uses Apple's afconvert for
// the m4a (see ENCODING). No samples, no network.
//
// Unlike every other bundled sound, these have no silence at the ends: the last sample leads
// straight into the first. Each file is exactly 1,382,400 samples (28.8 s at 48 kHz), and both
// app files must decode to exactly that length, or the loop drifts and clicks at the wrap.
//
// How a loop stays a loop:
// - Every layer level, swell, pan and harmony change is a function of time that is periodic in
//   the file length F (or a divisor of it), so nothing resets at the wrap.
// - Notes that ring past the end are written back onto the start (place()).
// - Delay, room, limiter and loudness all run on three copies in a row; the middle copy is kept.
// - The length is a whole number of MP3 (1152), AAC (1024) and Opus (960) frames.
// - After encoding, every app file is decoded and checked: exact length, no clipping, and a
//   join that looks like any other point in the file (joinCheck()). The run fails otherwise.
import { writeFileSync, readFileSync, mkdtempSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SR = 48000;
const OUT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..', 'assets', 'sounds');
const TAU = Math.PI * 2;
const FRAME = 46080;            // lcm of MP3 (1152), AAC (1024), Opus (960) frames at 48 kHz
const N = 30 * FRAME;           // 1,382,400 samples
const F = N / SR;               // 28.8 s
const NYQ_SAFE = 15000;         // partials above this are dropped (no aliasing, phone-friendly)

// ---------- ENCODING ----------
// Mono, AAC 64k in m4a for iOS, Opus 48k in ogg for Android, both 48 kHz. The master is folded
// to mono before the limiter and the loudness match, so ffmpeg never downmixes.
// iOS: on macOS the m4a comes from afconvert (Apple's AAC encoder), which writes the 2112-sample
// priming and the remainder where Core Audio trims them. Measured on the 28.8 s loops, afconvert
// and ffmpeg's aac both decode to 1,382,400 at 48 kHz through AVAssetReader and AVAudioFile, but
// resampled to 44.1 kHz (what SoundLibrary.convertToCAF does) the ffmpeg file comes out 304
// samples shorter than the same wav does, and the afconvert file matches the wav. Without
// afconvert (Linux, CI) the script falls back to ffmpeg aac with the flags below and says so.
// afconvert stamps the time into the mp4 header, so the script zeroes those stamps; the audio
// itself is identical from run to run.
// Byte-identical reruns assume the same macOS (afconvert) and the same ffmpeg and libopus. A
// different version can write different bytes, and the ffmpeg aac fallback writes a different m4a
// from the afconvert one. Either way the checks below still hold the length, peak and join.
// Android: the ogg uses the pre-roll and pre-skip trick in opusLoop(), so Android (which trims
// the pre-skip but not the end padding) and Apple/ffmpeg (which trim both) decode the same
// 1,382,400 samples. compression_level 5 is the emergency sounds' setting.
// Opus runs at 48k with a 16 kHz cutoff. Mastered loud (see master()), dread at 32k decoded 3.4 dB
// over its own master, and lowering the limiter ceiling only made the master denser and the
// overshoot worse: the run never got under -1.0 dBTP. At 48k it settles under -1.1 within the
// ceiling rounds. A 12 kHz cutoff left the ogg 5 to 8 dB under the m4a above 11.5 kHz; at 16 kHz
// it reads 1 to 4 dB over it, and the true peak search still settles.
const ENCODING = {
  ios: { ext: 'm4a', codec: 'aac', bitrate: '64k', sampleRate: 48000, channels: 1, opts: ['-aac_coder', 'fast'] },
  android: { ext: 'ogg', codec: 'libopus', bitrate: '48k', sampleRate: 48000, channels: 1, opts: ['-compression_level', '5', '-cutoff', '16000'] },
};
const MAX_DECODED_PEAK_DBFS = -0.1, MAX_DECODED_TP = -1.0;
const HAS_AFCONVERT = spawnSync('afconvert', ['-h']).error === undefined;

// Name in this file to the id the app stores against topics. Ids never change once shipped.
const IDS = {
  ascend: 'loop_ascend',
  dread: 'loop_dread',
  chiprun: 'loop_chiprun',
  glockslide: 'loop_glockslide',
  royalroad: 'loop_royalroad',
};

// ---------- shapes ----------

function bell(p, centre, width, taper = 0.06) {
  let w = Math.exp(-4 * ((p - centre) / width) ** 2);
  if (p < taper) w *= 0.5 * (1 - Math.cos(Math.PI * Math.max(0, p) / taper));
  if (p > 1 - taper) w *= 0.5 * (1 - Math.cos(Math.PI * Math.max(0, 1 - p) / taper));
  return Math.max(0, w);
}
// Gain that dips by `depth` dB and back, `div` times per file. Periodic in F by construction.
const swell = (t, depth, div = 1, ph = 0) => 10 ** (-depth * (0.5 - 0.5 * Math.cos(TAU * (t * div / F + ph))) / 20);
const posOf = (semis) => ((((semis / 12) % 1) + 1) % 1);
const scaleSemis = (S, d) => { const L = S.length, o = Math.floor(d / L); return S[((d % L) + L) % L] + 12 * o; };

// Risset rhythm over the whole file. Lap T must divide F. dir +1 accelerates, -1 decelerates
// (the time mirror). q = log2 tempo position, 0..R. rate = beats per second at the onset.
function risset(T, R, n, dir = 1) {
  const laps = Math.round(F / T);
  if (Math.abs(laps * T - F) > 1e-9 || Math.round(T * SR) * laps !== N) throw new Error('lap must divide file');
  const ev = [];
  for (let lap = 0; lap < laps; lap++)
    for (let j = 0; j < R; j++) {
      const per = n * 2 ** j;
      for (let m = 0; m < per; m++) {
        const tl = T * Math.log2(1 + m / per);
        const tt = dir > 0 ? tl : (T - tl) % T;
        const q = j + tl / T;  // tempo position of this onset; the mirror keeps it, so it falls through the lap
        ev.push({ t: lap * T + tt, q, j, m, lap, k: m + lap * per, rate: n * 2 ** q * Math.LN2 / T });
      }
    }
  return ev.sort((a, b) => a.t - b.t);
}

// ---------- timbres: [ratio, amp, extra decay 1/s] ----------
const MUSICBOX = [[1, 1, 0], [2, 0.16, 6], [4.2, 0.34, 26], [6.8, 0.1, 45]];
const CELESTA = [[1, 1, 0], [2, 0.22, 8], [3, 0.08, 16], [4, 0.07, 30]];
const GLOCK = [[1, 1, 0], [2.76, 0.42, 9], [5.4, 0.2, 20], [8.93, 0.07, 34]];
const MARIMBA = [[1, 1, 0], [3.93, 0.32, 32], [9.2, 0.07, 80]];
const KALIMBA = [[1, 1, 0], [5.9, 0.22, 36], [2, 0.07, 12]];
const PULSE = Array.from({ length: 14 }, (_, i) => [i + 1, Math.abs(Math.sin(Math.PI * (i + 1) / 4)) / (i + 1), 4 * i]);
const SQUARE = Array.from({ length: 7 }, (_, i) => [2 * i + 1, 1 / (2 * i + 1), 5 * i]);
const POP = [[1, 1, 0], [2, 0.2, 20]];
// Harmonic-only timbres for the glissando (whole ratios keep the relay phase-continuous).
const GLASS_H = [[1, 1], [2, 0.28], [3, 0.07]];
const BEEP_H = [[1, 1], [2, 0.3], [3, 0.22], [4, 0.06]];
const PULSE_H = PULSE.slice(0, 8).map(([r, a]) => [r, a]);

// ---------- voices ----------

// One Shepard tone: octave-spaced components under a spectral bell, each made of timbre partials.
// Decaying sines use an exact phasor (fast); pitch-drop pops use analytic phase.
function shepTone(pos, o) {
  const { fmin, K, centre, width, partials, decay = 0.3, attack = 0.002, drop, sustain } = o;
  const comps = [];
  for (let k = 0; k < K; k++) {
    const p = (k + pos) % K;
    const w = bell(p / K, centre, width, 0.08);
    if (w > 2e-4) comps.push({ f: fmin * 2 ** p, w });
  }
  const norm = comps.reduce((s, c) => s + c.w, 0) || 1;
  const dur = sustain ? sustain.dur : Math.min(o.maxDur ?? 1.6, attack + decay * 7);
  const len = Math.round(dur * SR), out = new Float32Array(len);
  for (const c of comps)
    for (const [r, a, d = 0] of partials) {
      const fr = c.f * r;
      if (fr > NYQ_SAFE) continue;
      const amp = c.w * a / norm;
      if (drop) {
        for (let i = 0; i < len; i++) {
          const t = i / SR;
          out[i] += amp * Math.exp(-d * t) * Math.sin(TAU * fr * (t + drop.a * drop.tau * (1 - Math.exp(-t / drop.tau))));
        }
      } else {
        const w = TAU * fr / SR, cw = Math.cos(w), sw = Math.sin(w), g = Math.exp(-d / SR);
        let s = 0, co = 1, A = amp;
        for (let i = 0; i < len; i++) { out[i] += A * s; const s2 = s * cw + co * sw; co = co * cw - s * sw; s = s2; A *= g; }
      }
    }
  const a = Math.max(1, Math.round(attack * SR)), rel = 96;
  for (let i = 0; i < len; i++) {
    let env;
    if (sustain) {
      const t = i / SR;
      env = 0.5 - 0.5 * Math.cos(Math.PI * Math.min(1, t / sustain.atk, (dur - t) / sustain.rel));
    } else env = (i < a ? i / a : 1) * Math.exp(-(i / SR) / decay) * (i > len - rel ? (len - i) / rel : 1);
    out[i] *= env;
  }
  return out;
}

// Short noise hit from a fixed-seed table, through a biquad. Starts and ends silent.
const NOISE = (() => { let s = 0x2f6e2b1; const a = new Float32Array(1 << 16); for (let i = 0; i < a.length; i++) { s = (s * 1664525 + 1013904223) >>> 0; a[i] = s / 2 ** 31 - 1; } return a; })();
function biquad(type, f, Q) {
  const w = TAU * f / SR, al = Math.sin(w) / (2 * Q), c = Math.cos(w);
  let b0, b1, b2;
  if (type === 'hp') { b0 = (1 + c) / 2; b1 = -(1 + c); b2 = (1 + c) / 2; } else { b0 = al; b1 = 0; b2 = -al; }
  const a0 = 1 + al, a1 = -2 * c, a2 = 1 - al;
  return [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0];
}
function noiseHit(seed, o) {
  const { dur, type = 'hp', f = 7000, Q = 0.7, decay = 0.012 } = o;
  const len = Math.round(dur * SR), out = new Float32Array(len);
  const [b0, b1, b2, a1, a2] = biquad(type, f, Q);
  let x1 = 0, x2 = 0, y1 = 0, y2 = 0, off = (seed * 7919) & 0xffff;
  for (let i = 0; i < len; i++) {
    const x = NOISE[(off + i) & 0xffff] * Math.exp(-(i / SR) / decay) * Math.min(1, i / 24);
    const y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1; x1 = x; y2 = y1; y1 = y; out[i] = y * (i > len - 48 ? (len - i) / 48 : 1);
  }
  return out;
}

// Soft round thump: a sine with a short pitch drop, 4 ms attack. Quiet by design.
function thump(f0, decay = 0.09) {
  const len = Math.round((decay * 6 + 0.01) * SR), out = new Float32Array(len), a = Math.round(0.004 * SR);
  for (let i = 0; i < len; i++) {
    const t = i / SR, ph = TAU * f0 * (t + 0.6 * 0.02 * (1 - Math.exp(-t / 0.02)));
    out[i] = (Math.sin(ph) + 0.25 * Math.sin(2 * ph)) * Math.min(1, i / a) * Math.exp(-t / decay) * (i > len - 96 ? (len - i) / 96 : 1);
  }
  return out;
}

// Continuous Shepard-Risset glissando, analytic phase + relay trick, one octave per lap Tp.
// Periodic in Tp for any whole-sample Tp. gainAt(n) gives a per-sample gain (gate, duck, swell).
function glissando(T, o, gainAt) {
  const { fmin, K, centre, width, partials, dir = 1 } = o;
  const out = new Float32Array(N);
  const base = TAU * fmin * T / Math.LN2, lap = Math.round(T * SR);
  const phi0 = [];
  for (let i = 0; i < K; i++) phi0.push(dir > 0 ? base * (2 ** i - 1) : base * (2 ** (K - 1) - 2 ** i));
  for (let n = 0; n < N; n++) {
    const g = gainAt(n);
    if (g < 1e-5) continue;
    const tl = (n % lap) / SR, s = dir * tl / T, p2 = 2 ** s;
    let x = 0, wsum = 0;
    for (let i = 0; i < K; i++) {
      const p = (((i + s) % K) + K) % K;
      const w = bell(p / K, centre, width, 0.08);
      if (w < 1e-5) continue;
      const ph = phi0[i] + base * 2 ** i * (p2 - 1) / dir, f = fmin * 2 ** p;
      for (const [r, a] of partials) if (f * r < NYQ_SAFE) x += w * a * Math.sin(r * ph);
      wsum += w;
    }
    out[n] = g * x / (wsum || 1);
  }
  return out;
}

// ---------- buffers ----------

const stereo = () => ({ L: new Float32Array(N), R: new Float32Array(N) });
function place(buf, mono, t, gain, pan = 0) {
  const s0 = ((Math.round(t * SR) % N) + N) % N, gl = Math.cos((pan + 1) * Math.PI / 4) * Math.SQRT2, gr = Math.sin((pan + 1) * Math.PI / 4) * Math.SQRT2;
  for (let i = 0; i < mono.length; i++) { const k = (s0 + i) % N; buf.L[k] += mono[i] * gain * gl; buf.R[k] += mono[i] * gain * gr; }
}
// Beat envelope (0..1), circular: drives ducking and gates.
function beatEnv(hits, tauFn) {
  const env = new Float32Array(N);
  for (const h of hits) {
    const s0 = Math.round(h.t * SR), tau = tauFn(h), len = Math.round(tau * 6 * SR);
    for (let i = 0; i < len; i++) env[(s0 + i) % N] += h.w * Math.min(1, i / 96) * Math.exp(-i / SR / tau);
  }
  let m = 0; for (const x of env) m = Math.max(m, x);
  for (let i = 0; i < N; i++) env[i] = Math.min(1, env[i] / (0.7 * m));
  return env;
}
const tile3 = (x) => { const t = new Float32Array(x.length * 3); for (let r = 0; r < 3; r++) t.set(x, r * x.length); return t; };

// Stereo ping-pong delay on three copies, middle kept. Input goes to the left line first.
function pingPong(send, tl, tr, fb, mix) {
  const x = tile3(send), dl = Math.round(tl * SR), dr = Math.round(tr * SR);
  const lineL = new Float32Array(dl), lineR = new Float32Array(dr), yl = new Float32Array(x.length), yr = new Float32Array(x.length);
  let kl = 0, kr = 0, lpl = 0, lpr = 0;
  for (let i = 0; i < x.length; i++) {
    const ol = lineL[kl], or = lineR[kr];
    lpl = 0.55 * ol + 0.45 * lpl; lpr = 0.55 * or + 0.45 * lpr;
    lineL[kl] = x[i] + fb * lpr; lineR[kr] = fb * lpl;
    yl[i] = ol; yr[i] = or; kl = (kl + 1) % dl; kr = (kr + 1) % dr;
  }
  return { L: yl.subarray(N, 2 * N).map((v) => v * mix), R: yr.subarray(N, 2 * N).map((v) => v * mix) };
}
// Schroeder room on three copies, middle kept.
function room(L, R, mix, size = 1) {
  const combs = [1557, 1617, 1491, 1422].map((d) => Math.round(d * size));
  const aps = [225, 556, 441];
  const run = (x, spread) => {
    const y = new Float32Array(x.length);
    for (const d0 of combs) {
      const d = d0 + spread, line = new Float32Array(d);
      let k = 0, lp = 0;
      for (let i = 0; i < x.length; i++) { const o = line[k]; lp = o * 0.6 + lp * 0.4; line[k] = x[i] + lp * 0.8; y[i] += o * 0.25; k = (k + 1) % d; }
    }
    for (const d of aps) {
      const line = new Float32Array(d); let k = 0;
      for (let i = 0; i < y.length; i++) { const b = line[k], v = y[i] + b * 0.5; line[k] = v; y[i] = b - v * 0.5; k = (k + 1) % d; }
    }
    return y;
  };
  const wl = run(tile3(L), 0).subarray(N, 2 * N), wr = run(tile3(R), 23).subarray(N, 2 * N);
  for (let i = 0; i < N; i++) { L[i] += mix * wl[i]; R[i] += mix * wr[i]; }
}

// ---------- output ----------

// 32-bit float wav, one array per channel.
function writeWav(path, chans) {
  const n = chans[0].length, ch = chans.length;
  const b = Buffer.alloc(44 + n * ch * 4);
  b.write('RIFF', 0); b.writeUInt32LE(36 + n * ch * 4, 4); b.write('WAVEfmt ', 8);
  b.writeUInt32LE(16, 16); b.writeUInt16LE(3, 20); b.writeUInt16LE(ch, 22);
  b.writeUInt32LE(SR, 24); b.writeUInt32LE(SR * ch * 4, 28); b.writeUInt16LE(ch * 4, 32);
  b.writeUInt16LE(32, 34); b.write('data', 36); b.writeUInt32LE(n * ch * 4, 40);
  let o = 44;
  for (let i = 0; i < n; i++) for (let c = 0; c < ch; c++) { b.writeFloatLE(chans[c][i], o); o += 4; }
  writeFileSync(path, b);
}
// bitexact keeps encoder version strings and random Ogg serial numbers out of the files, so a
// second run writes the same bytes. map_metadata -1 drops the wav's tags.
const same = ['-map_metadata', '-1', '-fflags', '+bitexact', '-flags:a', '+bitexact'];
const ff = (args) => { const r = spawnSync('ffmpeg', ['-hide_banner', '-v', 'error', '-y', ...args], { encoding: 'utf8' }); if (r.status) throw new Error(r.stderr); return r; };
const lufs = (f) => {
  const e = spawnSync('ffmpeg', ['-nostats', '-i', f, '-af', 'ebur128=peak=true', '-f', 'null', '-'], { encoding: 'utf8' }).stderr;
  const last = (re) => +e.match(re).pop().match(/-?[\d.]+/)[0];
  return { I: last(/I:\s+-?[\d.]+ LUFS/g), TP: last(/Peak:\s+-?[\d.]+ dBFS/g), LRA: last(/LRA:\s+[\d.]+ LU/g) };
};
// Decoded mono 48 kHz samples, the way ffmpeg plays the file (it trims priming and padding).
const decode = (f) => {
  const r = spawnSync('ffmpeg', ['-hide_banner', '-v', 'error', '-i', f, '-f', 'f32le', '-ac', '1', '-ar', String(SR), '-'], { maxBuffer: 1 << 28 });
  if (r.status) throw new Error(r.stderr.toString());
  return new Float32Array(r.stdout.buffer, r.stdout.byteOffset, r.stdout.length / 4);
};

// Ogg CRC (poly 0x04c11db7, no reflection).
const CRC = (() => { const t = new Uint32Array(256); for (let i = 0; i < 256; i++) { let r = i << 24; for (let k = 0; k < 8; k++) r = r & 0x80000000 ? ((r << 1) ^ 0x04c11db7) >>> 0 : (r << 1) >>> 0; t[i] = r >>> 0; } return t; })();
function oggCrc(buf) { let c = 0; for (const x of buf) c = ((c << 8) ^ CRC[((c >>> 24) ^ x) & 0xff]) >>> 0; return c >>> 0; }

// Opus loop: libopus adds 312 samples of pre-skip, and Android's MediaPlayer path does not trim the
// end padding, so a plain encode of N = k*960 samples plays 648 extra samples on Android.
// Fix: feed the encoder k*960 + 648 samples (the loop's last 648 samples as pre-roll, then the
// loop), then patch the OpusHead pre-skip from 312 to 960. The decoder drops 960 samples (encoder
// delay + the pre-roll), the packets total exactly 960 + N samples with zero end padding, and both
// Apple/ffmpeg (granule trim) and Android (no end trim) decode exactly N samples, starting on loop
// sample 0. The pre-roll also primes the encoder with the audio that really precedes sample 0.
function opusLoop(wav, out, e) {
  const pre = 648;
  ff(['-i', wav, ...same, '-filter_complex', `[0]atrim=start_sample=${N - pre},asetpts=N/SR/TB[a];[0]asetpts=N/SR/TB[b];[a][b]concat=n=2:v=0:a=1`,
    '-ac', String(e.channels), '-ar', String(e.sampleRate), '-c:a', e.codec, '-b:a', e.bitrate, ...e.opts, out]);
  const b = readFileSync(out);
  if (b.toString('latin1', 0, 4) !== 'OggS') throw new Error('not ogg');
  const nseg = b[26], hl = 27 + nseg, p = hl;
  if (b.toString('latin1', p, p + 8) !== 'OpusHead') throw new Error('no OpusHead');
  const old = b.readUInt16LE(p + 10);
  if (old !== 312) throw new Error(`unexpected pre-skip ${old}`);
  b.writeUInt16LE(old + pre, p + 10);
  let plen = 0; for (let i = 0; i < nseg; i++) plen += b[27 + i];
  b.writeUInt32LE(0, 22);
  b.writeUInt32LE(oggCrc(b.subarray(0, hl + plen)), 22);
  writeFileSync(out, b);
}

// Reads the Ogg pages directly: pre-skip, last granule, and every packet's length from its TOC
// byte. Apple and ffmpeg play (granule - pre-skip) samples. Android's MediaPlayer plays
// (packet total - pre-skip), because it does not trim the end. Both must be N.
function oggLengths(path) {
  const b = readFileSync(path), packets = [];
  let pos = 0, cur = [], gran = 0n;
  while (pos < b.length) {
    if (b.toString('latin1', pos, pos + 4) !== 'OggS') throw new Error(`${path}: bad page at ${pos}`);
    const g = b.readBigInt64LE(pos + 6), nseg = b[pos + 26];
    let p = pos + 27 + nseg;
    for (let i = 0; i < nseg; i++) {
      const s = b[pos + 27 + i];
      cur.push(b.subarray(p, p + s)); p += s;
      if (s < 255) { packets.push(Buffer.concat(cur)); cur = []; }
    }
    if (g >= 0n) gran = g;
    pos = p;
  }
  const preskip = packets[0].readUInt16LE(10);
  let total = 0;
  for (const pk of packets.slice(2)) {
    const cfg = pk[0] >> 3, c = pk[0] & 3;
    const fs = cfg < 12 ? [480, 960, 1920, 2880][cfg % 4] : cfg < 16 ? [480, 960][cfg % 2] : [120, 240, 480, 960][cfg % 4];
    total += fs * (c === 0 ? 1 : c < 3 ? 2 : pk[1] & 0x3f);
  }
  return { preskip, granule: Number(gran), packetTotal: total, apple: Number(gran) - preskip, android: total - preskip };
}

// afconvert writes the encode time into mvhd, tkhd and mdhd. Zero them so a rerun writes the
// same bytes, as ffmpeg's bitexact does.
function zeroMp4Times(path) {
  const b = readFileSync(path);
  const walk = (o, end) => {
    while (o + 8 <= end) {
      const size = b.readUInt32BE(o), type = b.toString('latin1', o + 4, o + 8);
      if (size < 8) throw new Error(`${path}: box ${type} has size ${size}`);
      if (['moov', 'trak', 'mdia'].includes(type)) walk(o + 8, o + size);
      if (['mvhd', 'tkhd', 'mdhd'].includes(type)) b.fill(0, o + 12, o + 12 + (b[o + 8] === 1 ? 16 : 8));
      o += size;
    }
  };
  walk(0, b.length);
  writeFileSync(path, b);
}
function encodeM4a(wav, out, e) {
  if (HAS_AFCONVERT) {
    const r = spawnSync('afconvert', ['-f', 'm4af', '-d', `aac@${e.sampleRate}`, '-c', String(e.channels),
      '-b', String(parseInt(e.bitrate, 10) * 1000), wav, out], { encoding: 'utf8' });
    if (r.status) throw new Error(`afconvert: ${r.stderr}`);
    zeroMp4Times(out);
  } else {
    ff(['-i', wav, ...same, '-ac', String(e.channels), '-ar', String(e.sampleRate), '-c:a', e.codec, '-b:a', e.bitrate, ...e.opts, out]);
  }
}
// Valid frames Core Audio reports for a file (priming and remainder already taken off), or null
// off macOS.
function afinfoFrames(path) {
  const r = spawnSync('afinfo', [path], { encoding: 'utf8' });
  if (r.error) return null;
  const m = r.stdout.match(/(\d+) valid frames \+ (\d+) priming \+ (\d+) remainder/);
  if (!m) throw new Error(`afinfo gave no frame count for ${path}`);
  return { valid: +m[1], priming: +m[2], remainder: +m[3] };
}

// Join test on a decoded file played on repeat. The join (last sample into the first) has to
// look like any other point in the file:
//   gap    samples of near-silence (under -60 dBFS) at the two ends. One or two are a zero
//          crossing landing on the join; a real gap is hundreds. Fails at 1 ms (48 samples).
//   jump   sample step across the join / the file's 99.9th-percentile step
//   jumpP  percentile of the join step among 400 fixed interior steps
//   hfP    percentile of the 5 ms high-frequency window centred on the join among every window
//   lvl    level change, 50 ms after vs 50 ms before the join, in dB
//   lvlP   percentile of |lvl| at the join among |lvl| at the same 400 interior points
function joinCheck(x) {
  const n = x.length, d = new Float64Array(n);
  for (let k = 0; k < n; k++) d[k] = x[k] - x[(k - 1 + n) % n];   // d[0] is the join step
  const pct = (vals, v) => 100 * vals.filter((u) => u < v).length / vals.length;
  const steps = []; for (let k = 1; k < n; k += 7) steps.push(Math.abs(d[k]));
  steps.sort((a, b) => a - b);
  const jump = Math.abs(d[0]) / (steps[Math.floor(steps.length * 0.999)] || 1e-9);
  const sq = new Float64Array(n + 1); for (let k = 0; k < n; k++) sq[k + 1] = sq[k] + d[k] * d[k];
  const w = Math.round(0.005 * SR), e = [];
  for (let k = 0; k < n - w; k += w / 2) e.push(sq[k + w] - sq[k]);
  const hfP = pct(e, (sq[n] - sq[n - w / 2]) + sq[w / 2]);
  const m = Math.round(0.05 * SR), x2 = new Float64Array(n + 1);
  for (let k = 0; k < n; k++) x2[k + 1] = x2[k] + x[k] * x[k];
  const energy = (a, len) => { a = ((a % n) + n) % n; return a + len <= n ? x2[a + len] - x2[a] : (x2[n] - x2[a]) + x2[a + len - n]; };
  const lvlAt = (k) => 10 * Math.log10((energy(k, m) || 1e-18) / (energy(k - m, m) || 1e-18));
  let s = 7; const pts = [];
  for (let i = 0; i < 400; i++) { s = (s * 1103515245 + 12345) % 2147483648; pts.push(m + (s % (n - 2 * m))); }
  const lv = pts.map(lvlAt).sort((a, b) => a - b), lvl = lvlAt(0);
  const th = 10 ** (-60 / 20);
  let i = 0; while (i < n && Math.abs(x[i]) < th) i++;
  let j = n - 1; while (j > 0 && Math.abs(x[j]) < th) j--;
  return {
    len: n, gap: i + (n - 1 - j), jump, jumpP: pct(pts.map((k) => Math.abs(d[k])), Math.abs(d[0])), hfP,
    lvl, lvlP: pct(lv.map(Math.abs), Math.abs(lvl)), lvlRange: [lv[Math.floor(0.05 * lv.length)], lv[Math.floor(0.95 * lv.length)]],
  };
}

// Every check an app file has to pass. Throws on the first failure.
function checkFile(path, ext) {
  const x = decode(path);
  if (x.length !== N) throw new Error(`${path} decodes to ${x.length} samples, not ${N}`);
  let pk = 0; for (const v of x) pk = Math.max(pk, Math.abs(v));
  const peak = 20 * Math.log10(pk);
  if (peak > MAX_DECODED_PEAK_DBFS) throw new Error(`${path} decodes to a ${peak.toFixed(2)} dBFS peak and would clip`);
  const tp = lufs(path).TP; // true peak, 4x oversampled by ffmpeg's ebur128
  if (tp > MAX_DECODED_TP) throw new Error(`${path} decodes to a ${tp.toFixed(1)} dBTP true peak, over ${MAX_DECODED_TP}`);
  const j = joinCheck(x);
  if (j.gap >= SR / 1000 || j.jump >= 1 || j.jumpP >= 99 || j.hfP >= 99 || j.lvlP >= 99)
    throw new Error(`${path}: the join stands out: ${JSON.stringify(j)}`);
  const extra = {};
  if (ext === 'ogg') {
    const o = oggLengths(path);
    if (o.preskip !== 960 || o.apple !== N || o.android !== N) throw new Error(`${path}: Ogg lengths wrong: ${JSON.stringify(o)}`);
    extra.ogg = o;
  }
  const af = afinfoFrames(path);
  if (af && af.valid !== N) throw new Error(`${path}: afinfo reports ${af.valid} valid frames, not ${N}`);
  if (af) extra.afinfo = af;
  return { peak, tp, join: j, ...extra };
}

// Shape, then gain to target loudness, then a 4x-oversampled limiter, all on 3 copies, keeping
// the middle copy. The ceiling drops until both app files read under -1.0 dBTP. M is already mono.
// Writes <id>.m4a and <id>.ogg into OUT; the master wav stays in tmp.
//
// Every bundled sound has to read at least -9 LUFS on the mono app file: an alarm that is not
// loud is not doing its job. TARGET is -8.5, so the AAC and Opus files still land above -9 after
// encoding. Plain gain into the limiter got these loops to -10 only by crushing them to 0.7 LU
// and making Opus overshoot, so the master shapes the sound first (SHAPE):
// - presence: a broad lift around 3 kHz, where phone speakers and ears are most sensitive;
// - parallel compression: half the signal through a compressor with makeup, mixed back with the
//   dry half, so quiet notes and tails come up and the attacks keep their shape;
// - soft clip at 4x (192 kHz): a tanh curve a little above the limiter ceiling rounds the
//   loudest transients, so the limiter has less to do and pumps less.
// Each step only remembers a few hundred ms, far less than one lap, so the middle copy is still
// an exact steady-state loop.
const TARGET_LUFS = -8.5;
const SHAPE = {
  presence: 'equalizer=f=3000:t=q:w=0.9:g=3',
  parallel: 'acompressor=threshold=0.1:ratio=4:attack=4:release=160:knee=4:makeup=2.5:mix=0.5',
  clipOverCeilDb: 1.5,
  // The clip puts DC on a lopsided waveform (chiprun's m4a sat at -0.009). Opus strips it and AAC
  // keeps it, so the two files differed. 25 Hz keeps the thumps.
  dcBlock: 'highpass=f=25:p=2',
};
function master(tmp, id, M, target = TARGET_LUFS) {
  const t3 = join(tmp, `${id}-x3.wav`), wav = join(tmp, `${id}.wav`);
  writeWav(t3, [tile3(M)]);
  const files = Object.fromEntries(Object.entries(ENCODING).map(([k, e]) => [k, resolve(OUT, `${id}.${e.ext}`)]));
  const mid = `atrim=start_sample=${N}:end_sample=${2 * N},asetpts=N/SR/TB`;
  let gain = 0, ceil = -2.0, m, tps;
  const chain = () => [
    `volume=${gain}dB`, SHAPE.presence, SHAPE.parallel, 'aresample=192000',
    `asoftclip=type=tanh:threshold=${10 ** ((ceil + SHAPE.clipOverCeilDb) / 20)}`, SHAPE.dcBlock,
    `alimiter=limit=${10 ** (ceil / 20)}:attack=1.5:release=90:asc=1:level=false`, `aresample=${SR}`, mid,
  ].join(',');
  for (let round = 0; round < 8; round++) {
    for (let pass = 0; pass < 8; pass++) {
      ff(['-i', t3, '-af', chain(), '-c:a', 'pcm_s24le', wav]);
      m = lufs(wav);
      if (Math.abs(m.I - target) < 0.2) break;
      gain += target - m.I;
    }
    encodeM4a(wav, files.ios, ENCODING.ios);
    opusLoop(wav, files.android, ENCODING.android);
    tps = Object.fromEntries(Object.entries(files).map(([k, f]) => [ENCODING[k].ext, lufs(f).TP]));
    tps.wav = m.TP;
    const worst = Math.max(...Object.values(tps));
    if (worst <= -1.1) break;
    if (round === 7) throw new Error(`${id}: true peak still ${worst.toFixed(2)} dBTP after 8 rounds: ${JSON.stringify(tps)}`);
    ceil -= worst + 1.15;
  }
  const checks = Object.fromEntries(Object.entries(files).map(([k, f]) => [ENCODING[k].ext, checkFile(f, ENCODING[k].ext)]));
  return { ...m, tps, ceil, checks };
}

// ---------- variants ----------
// Each returns { layers: [{ name, buf, db, send }], room, delay, rot } where rot is a time to start
// the file at (a gap between strong onsets, so the wrap lands on an ordinary moment).

const MAJOR = [0, 2, 4, 5, 7, 9, 11];
const HMINOR = [0, 2, 3, 5, 7, 8, 11];

function gapNear(times, target) {
  const s = [...times].map((t) => ((t % F) + F) % F).sort((a, b) => a - b);
  let best = target, bd = Infinity;
  for (let i = 0; i < s.length; i++) {
    const a = s[i], b = i + 1 < s.length ? s[i + 1] : s[0] + F, mid = (a + b) / 2;
    if (b - a > 0.05 && Math.abs(mid - target) < bd) { bd = Math.abs(mid - target); best = mid % F; }
  }
  return best;
}

const VARIANTS = {
  // D major music box arpeggios on diatonic seventh chords that climb a scale step every 1.37 s,
  // forever, while the Risset rhythm speeds up forever.
  ascend() {
    const V = { fmin: 73.42, K: 8, centre: 0.56, width: 0.34 };
    const T = F / 3, Tp = F / 3, R = 6, n = 5;
    const ev = risset(T, R, n, 1);
    const deg = (t) => Math.floor(t / Tp * 7);
    const motif = [0, 2, 4, 6];
    const mbox = stereo(), cel = stereo(), hats = stereo(), th = stereo(), main = [];
    for (const e of ev) {
      const w = bell(e.q / R, 0.6, 0.42);
      const d0 = deg(e.t), pan = 0.18 * Math.sin(TAU * e.q / 2);
      if (w > 0.01) {
        const tone = d0 + motif[e.k % 4];
        place(mbox, shepTone(posOf(scaleSemis(MAJOR, tone)), { ...V, partials: MUSICBOX, decay: Math.min(0.32, 1.4 / e.rate) }), e.t, w * swell(e.t, 4, 1, 0.1), pan);
        if (w > 0.3) main.push(e.t);
      }
      const w2 = bell(e.q / R, 0.7, 0.3);
      if (w2 > 0.02 && e.m % 2 === 0) {
        const tone = d0 + motif[e.k % 4] + 2;
        place(cel, shepTone(posOf(scaleSemis(MAJOR, tone)), { ...V, centre: 0.6, partials: CELESTA, decay: Math.min(0.4, 1.6 / e.rate) }), e.t, w2 * swell(e.t, 26, 1, 0.55), -pan);
      }
      const w3 = bell(e.q / R, 0.82, 0.28);
      if (w3 > 0.02) place(hats, noiseHit(e.k + 31 * e.j, { dur: 0.03, f: 7500, decay: 0.008 }), e.t, w3 * swell(e.t, 14, 1, 0.35), 0.25 * Math.cos(TAU * e.q));
      const w4 = bell(e.q / R, 0.38, 0.18);
      if (w4 > 0.05) place(th, thump(146.83), e.t, w4 * swell(e.t, 6, 2, 0), 0);
    }
    const duck = beatEnv(ev.filter((e) => bell(e.q / R, 0.6, 0.42) > 0.1).map((e) => ({ t: e.t, w: bell(e.q / R, 0.6, 0.42) })), (h) => 0.1);
    const pad = glissando(Tp, { ...V, centre: 0.5, width: 0.36, partials: GLASS_H, dir: 1 }, (i) => swell(i / SR, 9, 2, 0.25) * (1 - 0.5 * duck[i]));
    return {
      layers: [
        { name: 'music box', buf: mbox, db: 0, send: 0.3 },
        { name: 'celesta thirds', buf: cel, db: -3, send: 0.4 },
        { name: 'glass gliss', buf: { L: pad, R: pad }, db: -10, send: 0 },
        { name: 'hats', buf: hats, db: -18, send: 0 },
        { name: 'thump', buf: th, db: -15, send: 0 },
      ],
      delay: [0.165, 0.247, 0.38, 0.16], room: 0.14, rot: gapNear(main, 0.41 * F),
    };
  },

  // A harmonic minor marimba falling a scale step every 2.06 s (augmented and diminished chords
  // pass by), against a kalimba line that climbs chromatically and a glass glissando that rises.
  // The rhythm speeds up forever. Falling pitch plus accelerating rhythm: dread.
  dread() {
    const V = { fmin: 55, K: 8, centre: 0.57, width: 0.32 };
    const T = F / 6, Tp = F / 2, Tc = F / 3, R = 6, n = 2;
    const ev = risset(T, R, n, 1);
    const deg = (t) => -Math.floor(t / Tp * 7);
    const motif = [0, 2, 4, 2];
    const mar = stereo(), kal = stereo(), tick = stereo(), th = stereo(), main = [];
    for (const e of ev) {
      const w = bell(e.q / R, 0.6, 0.4), d0 = deg(e.t), pan = 0.15 * Math.sin(TAU * e.q / 2 + 1);
      if (w > 0.01) {
        const tone = d0 + motif[e.k % 4];
        place(mar, shepTone(posOf(scaleSemis(HMINOR, tone)), { ...V, partials: MARIMBA, attack: 0.004, decay: Math.min(0.22, 1.2 / e.rate) }), e.t, w * swell(e.t, 4, 2, 0.6), pan);
        if (w > 0.3) main.push(e.t);
      }
      const w2 = bell(e.q / R, 0.52, 0.3);
      if (w2 > 0.02 && e.m % 2 === 1) {
        const c = Math.floor(e.t / Tc * 12);
        place(kal, shepTone(posOf(c + 6), { ...V, centre: 0.62, partials: KALIMBA, attack: 0.001, decay: 0.3 }), e.t, w2 * swell(e.t, 24, 1, 0.5), -0.3);
      }
      const w3 = bell(e.q / R, 0.8, 0.28);
      if (w3 > 0.02) place(tick, noiseHit(e.k + 17 * e.j, { dur: 0.02, type: 'bp', f: 3200, Q: 3, decay: 0.004 }), e.t, w3 * swell(e.t, 12, 2, 0.1), 0.2 * Math.sin(TAU * e.q));
      const w4 = bell(e.q / R, 0.34, 0.16);
      if (w4 > 0.05) { place(th, thump(110), e.t, w4, 0); place(th, thump(98, 0.07), e.t + 0.14, 0.55 * w4, 0); }
    }
    const duck = beatEnv(ev.filter((e) => bell(e.q / R, 0.6, 0.4) > 0.1).map((e) => ({ t: e.t, w: bell(e.q / R, 0.6, 0.4) })), () => 0.12);
    const pad = glissando(Tc, { ...V, centre: 0.52, width: 0.34, partials: GLASS_H, dir: 1 }, (i) => swell(i / SR, 12, 1, 0.05) * (1 - 0.45 * duck[i]));
    return {
      layers: [
        { name: 'marimba', buf: mar, db: 0, send: 0.3 },
        { name: 'kalimba chromatic', buf: kal, db: -4, send: 0.45 },
        { name: 'glass gliss up', buf: { L: pad, R: pad }, db: -9, send: 0 },
        { name: 'clock ticks', buf: tick, db: -17, send: 0 },
        { name: 'heartbeat', buf: th, db: -13, send: 0 },
      ],
      delay: [0.31, 0.465, 0.45, 0.2], room: 0.2, rot: gapNear(main, 0.27 * F),
    };
  },

  // E chip leads: a pulse lead plays minor arpeggios on a chromatic line that rises a semitone
  // every 0.48 s; a square lead answers on a line that falls the same way (contrary motion, the
  // two wedge apart and back). Fast Risset rhythm, bouncy pops, a gated pulse glissando.
  chiprun() {
    const V = { fmin: 82.41, K: 7, centre: 0.6, width: 0.3 };
    const T = F / 10, Tp = F / 5, R = 5, n = 4;
    const ev = risset(T, R, n, 1);
    const up = (t) => Math.floor(t / Tp * 12), down = (t) => 7 - Math.floor(t / Tp * 12);
    const arp = [0, 7, 3, 7];
    const v1 = stereo(), v2 = stereo(), pops = stereo(), hats = stereo(), th = stereo(), main = [];
    for (const e of ev) {
      const w = bell(e.q / R, 0.46, 0.4), pan = 0.12 * Math.sin(TAU * e.q / 2);
      if (w > 0.01) {
        place(v1, shepTone(posOf(up(e.t) + arp[e.k % 4]), { ...V, partials: PULSE, attack: 0.001, decay: Math.min(0.09, 0.5 / e.rate) }), e.t, w * swell(e.t, 3, 3, 0.2), pan);
        if (w > 0.3) main.push(e.t);
      }
      const w2 = bell(e.q / R, 0.5, 0.3);
      if (w2 > 0.02 && e.m % 2 === 0)
        place(v2, shepTone(posOf(down(e.t)), { ...V, centre: 0.55, partials: SQUARE, attack: 0.001, decay: Math.min(0.12, 0.7 / e.rate) }), e.t, w2 * swell(e.t, 22, 2, 0.25), -0.25);
      const w3 = bell(e.q / R, 0.4, 0.26);
      if (w3 > 0.02 && e.m % 2 === 1)
        place(pops, shepTone(posOf(up(e.t) + (e.k % 4 < 2 ? 0 : 7)), { ...V, centre: 0.62, partials: POP, attack: 0.001, decay: 0.05, drop: { a: 0.7, tau: 0.014 } }), e.t, w3 * swell(e.t, 9, 1, 0.65), 0.3 * Math.cos(TAU * e.q / 2));
      const w4 = bell(e.q / R, 0.76, 0.34);
      if (w4 > 0.02) place(hats, noiseHit(e.k + 13 * e.j, { dur: 0.02, f: 8500, decay: 0.006 }), e.t, w4 * swell(e.t, 10, 2, 0.5), 0.25 * Math.sin(TAU * e.q));
      const w5 = bell(e.q / R, 0.28, 0.16);
      if (w5 > 0.05) place(th, thump(164.8, 0.07), e.t, w5, 0);
    }
    const gate = beatEnv(ev.filter((e) => bell(e.q / R, 0.46, 0.4) > 0.05).map((e) => ({ t: e.t, w: bell(e.q / R, 0.46, 0.4) })), (h) => 0.05);
    const gl = glissando(Tp, { ...V, centre: 0.55, width: 0.32, partials: PULSE_H, dir: 1 }, (i) => swell(i / SR, 24, 1, 0.0) * gate[i]);
    return {
      layers: [
        { name: 'pulse lead (up)', buf: v1, db: 0, send: 0.2 },
        { name: 'square lead (down)', buf: v2, db: -3, send: 0.35 },
        { name: 'pops', buf: pops, db: -6, send: 0.1 },
        { name: 'gated pulse gliss', buf: { L: gl, R: gl }, db: -11, send: 0 },
        { name: 'hats', buf: hats, db: -17, send: 0 },
        { name: 'thump', buf: th, db: -16, send: 0 },
      ],
      delay: [0.12, 0.18, 0.3, 0.12], room: 0.08, rot: gapNear(main, 0.58 * F),
    };
  },

  // F: a bright Shepard-Risset glissando that climbs one octave every 7.2 s, chopped by a Risset
  // rhythm that keeps slowing down (yet never gets slower). Glockenspiel plays augmented triads on
  // whole-tone steps that follow the glide up. Dreamy and uneasy.
  glockslide() {
    const V = { fmin: 87.31, K: 8, centre: 0.56, width: 0.32 };
    const T = F / 8, Tp = F / 4, R = 6, n = 3;
    const ev = risset(T, R, n, -1);
    const wt = (t) => 2 * Math.floor(t / Tp * 6);
    const aug = [0, 4, 8];
    const gk = stereo(), gk2 = stereo(), hats = stereo(), th = stereo(), main = [];
    for (const e of ev) {
      const pan = 0.18 * Math.sin(TAU * e.q / 2 + 2);
      const w = bell(e.q / R, 0.42, 0.32);
      if (w > 0.01) place(gk, shepTone(posOf(wt(e.t) + aug[e.k % 3]), { ...V, centre: 0.6, partials: GLOCK, attack: 0.001, decay: Math.min(0.35, 1.8 / e.rate) }), e.t, w * swell(e.t, 5, 3, 0.15), pan);
      const w2 = bell(e.q / R, 0.6, 0.3);
      if (w2 > 0.02 && e.m % 2 === 1) place(gk2, shepTone(posOf(wt(e.t) + 2 + aug[e.k % 3]), { ...V, centre: 0.64, partials: GLOCK, attack: 0.001, decay: Math.min(0.25, 1.2 / e.rate) }), e.t, w2 * swell(e.t, 26, 1, 0.5), -pan);
      const wg = bell(e.q / R, 0.55, 0.4);
      if (wg > 0.3) main.push(e.t);
      const w3 = bell(e.q / R, 0.8, 0.3);
      if (w3 > 0.02) place(hats, noiseHit(e.k + 11 * e.j, { dur: 0.025, f: 7000, decay: 0.007 }), e.t, w3 * swell(e.t, 10, 1, 0.8), 0.2 * Math.cos(TAU * e.q));
      const w4 = bell(e.q / R, 0.3, 0.16);
      if (w4 > 0.05) place(th, thump(174.6, 0.08), e.t, w4, 0);
    }
    const gate = beatEnv(ev.filter((e) => bell(e.q / R, 0.55, 0.4) > 0.05).map((e) => ({ t: e.t, w: bell(e.q / R, 0.55, 0.4), rate: e.rate })), (h) => Math.min(0.08, 0.5 / h.rate));
    const floor = (t) => 0.06 + 0.4 * (0.5 - 0.5 * Math.cos(TAU * t / F));
    const gl = glissando(Tp, { ...V, partials: BEEP_H, dir: 1 }, (i) => { const fl = floor(i / SR); return fl + (1 - fl) * gate[i]; });
    return {
      layers: [
        { name: 'gated gliss lead', buf: { L: gl, R: gl }, db: 0, send: 0.15 },
        { name: 'glock augmented', buf: gk, db: -2, send: 0.35 },
        { name: 'glock answer', buf: gk2, db: -5, send: 0.4 },
        { name: 'hats', buf: hats, db: -18, send: 0 },
        { name: 'thump', buf: th, db: -15, send: 0 },
      ],
      delay: [0.2, 0.3, 0.4, 0.15], room: 0.18, rot: gapNear(main, 0.66 * F),
    };
  },

  // C major "royal road" (IVmaj7 - V7 - iii7 - vi7), one chord per 7.2 s, so the whole file is one
  // turn of the progression and it comes back round. Kalimba arpeggios spiral up through each chord
  // forever (Shepard), pops bounce on the off-beats, celesta sings the sevenths, a soft chord pad
  // crossfades between chords and ducks under the beats.
  royalroad() {
    const V = { fmin: 65.41, K: 8, centre: 0.57, width: 0.34 };
    const T = F / 9, R = 6, n = 3, seg = F / 4;
    const ev = risset(T, R, n, 1);
    const CH = [[0, 4, 5, 9], [2, 5, 7, 11], [2, 4, 7, 11], [0, 4, 7, 9]]; // pitch classes, ascending
    const ROOT = [5, 7, 4, 9], SEV = [4, 5, 2, 7], THIRD = [9, 11, 7, 0];
    const chordAt = (t) => Math.floor(((t % F) + F) % F / seg) % 4;
    const kal = stereo(), pops = stereo(), cel = stereo(), hats = stereo(), th = stereo(), padb = stereo(), main = [];
    for (const e of ev) {
      const c = chordAt(e.t), pan = 0.15 * Math.sin(TAU * e.q / 2);
      const w = bell(e.q / R, 0.55, 0.42);
      if (w > 0.01) {
        place(kal, shepTone(posOf(CH[c][e.k % 4]), { ...V, partials: KALIMBA, attack: 0.001, decay: Math.min(0.3, 1.4 / e.rate) }), e.t, w * swell(e.t, 4, 2, 0.3), pan);
        if (w > 0.3) main.push(e.t);
      }
      const w2 = bell(e.q / R, 0.72, 0.3);
      if (w2 > 0.02 && e.m % 2 === 1) place(pops, shepTone(posOf(e.k % 4 < 2 ? ROOT[c] : ROOT[c] + 7), { ...V, centre: 0.62, partials: POP, attack: 0.001, decay: 0.05, drop: { a: 0.7, tau: 0.015 } }), e.t, w2 * swell(e.t, 10, 2, 0.2), -pan * 1.5);
      const w3 = bell(e.q / R, 0.38, 0.22);
      if (w3 > 0.03 && e.m % 2 === 0) place(cel, shepTone(posOf(e.k % 4 < 2 ? SEV[c] : THIRD[c]), { ...V, centre: 0.62, partials: CELESTA, decay: 0.45 }), e.t, w3 * swell(e.t, 18, 1, 0.6), 0);
      const w4 = bell(e.q / R, 0.82, 0.28);
      if (w4 > 0.02) place(hats, noiseHit(e.k + 7 * e.j, { dur: 0.025, f: 8000, decay: 0.007 }), e.t, w4 * swell(e.t, 12, 1, 0.1), 0.25 * Math.sin(TAU * e.q));
      const w5 = bell(e.q / R, 0.32, 0.16);
      if (w5 > 0.05) place(th, thump(65.41 * 2 ** (1 + ROOT[c] / 12), 0.08), e.t, w5, 0);
    }
    for (let c = 0; c < 4; c++)
      for (const pc of CH[c]) place(padb, shepTone(posOf(pc), { ...V, centre: 0.5, width: 0.36, partials: [[1, 1, 0], [2, 0.25, 0], [3, 0.06, 0]], sustain: { dur: seg + 0.6, atk: 0.6, rel: 0.6 } }), c * seg - 0.3, 1, 0);
    const duck = beatEnv(ev.filter((e) => bell(e.q / R, 0.55, 0.42) > 0.1).map((e) => ({ t: e.t, w: bell(e.q / R, 0.55, 0.42) })), () => 0.1);
    for (let i = 0; i < N; i++) { const g = (1 - 0.5 * duck[i]) * swell(i / SR, 8, 2, 0.7); padb.L[i] *= g; padb.R[i] *= g; }
    return {
      layers: [
        { name: 'kalimba spiral', buf: kal, db: 0, send: 0.3 },
        { name: 'pops', buf: pops, db: -5, send: 0.15 },
        { name: 'celesta sevenths', buf: cel, db: -4, send: 0.4 },
        { name: 'chord pad', buf: padb, db: -10, send: 0 },
        { name: 'hats', buf: hats, db: -18, send: 0 },
        { name: 'thump', buf: th, db: -15, send: 0 },
      ],
      delay: [0.18, 0.27, 0.38, 0.15], room: 0.16, rot: gapNear(main, 0.13 * F),
    };
  },
};

function render(slug, tmp) {
  const v = VARIANTS[slug]();
  const L = new Float32Array(N), R = new Float32Array(N), send = new Float32Array(N);
  for (const ly of v.layers) {
    let ss = 0; for (let i = 0; i < N; i++) ss += ly.buf.L[i] ** 2 + ly.buf.R[i] ** 2;
    const g = 0.1 * 10 ** (ly.db / 20) / Math.sqrt(ss / (2 * N) || 1e-12);
    for (let i = 0; i < N; i++) { L[i] += g * ly.buf.L[i]; R[i] += g * ly.buf.R[i]; send[i] += ly.send * g * 0.5 * (ly.buf.L[i] + ly.buf.R[i]); }
  }
  const [tl, tr, fb, mix] = v.delay;
  const d = pingPong(send, tl, tr, fb, mix);
  for (let i = 0; i < N; i++) { L[i] += d.L[i]; R[i] += d.R[i]; }
  room(L, R, v.room);
  // Start the file at an ordinary moment between strong onsets (any rotation of a loop is a
  // loop), and fold to mono here, before mastering, so the limiter sees what ships.
  const rot = Math.round(v.rot * SR) % N;
  const M = new Float32Array(N);
  for (let i = 0; i < N; i++) M[i] = (L[(i + rot) % N] + R[(i + rot) % N]) / 2;
  return master(tmp, IDS[slug], M);
}

const want = process.argv.slice(2).map((a) => a.replace(/^loop_/, ''));
for (const w of want) if (!VARIANTS[w]) { console.error(`unknown loop "${w}". Use one of: ${Object.keys(IDS).join(', ')} (or loop_<name>)`); process.exit(1); }
if (!HAS_AFCONVERT) console.error('afconvert not found: encoding the m4a with ffmpeg aac instead. See ENCODING.');
const tmp = mkdtempSync(join(tmpdir(), 'critalarm-loops-'));
try {
  for (const slug of Object.keys(VARIANTS)) {
    if (want.length && !want.includes(slug)) continue;
    const t0 = Date.now(), r = render(slug, tmp), id = IDS[slug];
    console.log(`${id.padEnd(16)} ${(N / SR).toFixed(1)} s  ${r.I.toFixed(1)} LUFS  true peak ${Object.entries(r.tps).map(([k, v]) => `${k} ${v.toFixed(1)}`).join(', ')} dBTP  (${((Date.now() - t0) / 1000).toFixed(1)} s)`);
    for (const [ext, c] of Object.entries(r.checks)) {
      const j = c.join;
      const len = ext === 'ogg' ? `ogg pre-skip ${c.ogg.preskip}, granule ${c.ogg.granule}, packets ${c.ogg.packetTotal}: plays ${c.ogg.apple} (Apple/ffmpeg) / ${c.ogg.android} (Android)` : `ffmpeg ${j.len}`;
      const af = c.afinfo ? `, afinfo ${c.afinfo.valid} valid + ${c.afinfo.priming} priming + ${c.afinfo.remainder} remainder` : '';
      console.log(`  ${ext}  ${len}${af}`);
      console.log(`       peak ${c.peak.toFixed(2)} dBFS, true peak ${c.tp.toFixed(1)} dBTP  join: gap ${j.gap} samples, jump ${j.jump.toFixed(2)} (P${j.jumpP.toFixed(0)}), hf P${j.hfP.toFixed(0)}, lvl ${j.lvl >= 0 ? '+' : ''}${j.lvl.toFixed(2)} dB (P${j.lvlP.toFixed(0)}, interior ${j.lvlRange.map((v) => v.toFixed(1)).join('..')})`);
    }
  }
} finally {
  rmSync(tmp, { recursive: true, force: true });
}

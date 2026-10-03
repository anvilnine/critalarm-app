// Crit Alarm library sound pack. Prepares 23 CC0 and public domain recordings as alarm sounds and
// writes them into the store-hosted pack `sound_pack_library`.
//
// Run from the repo root, pointing at a folder that holds the original downloads under the file
// names in the SOUNDS table below:
//   node tools/sounds/library_pack.mjs /path/to/originals
//
// The originals are never committed. Each one's source page is in the table, so anyone can fetch
// them again and get the same output.
//
// Writes:
// - android/sound_pack_library/src/main/assets/sounds/<id>.ogg   (Play Asset Delivery, on demand)
// - ios/SoundPacks/sound_pack_library/sounds/<id>.m4a            (Apple-hosted Background Assets)
// - LICENSES.md next to both, crediting every sound
// - lib/core/sound/library_pack_sounds.dart, the ids, names, lengths and credits the app shows
//
// Every sound goes through the same chain the bundled emergency sounds use (emergency.mjs):
// - decoded to 48 kHz mono and trimmed of dead air at both ends;
// - repeated to a whole number of passes when shorter than 10 s, so it lasts 10 to 30 s;
// - high-passed (which also takes out DC), shaped, soft clipped and limited to -8.5 LUFS on the
//   master, so the decoded files read at least -9 LUFS with a true peak under -1.0 dBTP;
// - encoded with the same ENCODING block: mono AAC 64k m4a for iOS, mono Opus 48k ogg for Android.
// The short-term loudness (3 s window) is printed too. The bundled sounds keep it above -14 LUFS;
// a sound with long gaps of its own may not, and the run says which.
//
// Needs ffmpeg with libopus on PATH. No network.
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const SR = 48000, TAU = Math.PI * 2;
const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
const PACK_ID = 'sound_pack_library';
const OUT = {
  android: resolve(ROOT, 'android', PACK_ID, 'src', 'main', 'assets'),
  ios: resolve(ROOT, 'ios', 'SoundPacks', PACK_ID),
};
const DART_OUT = resolve(ROOT, 'lib', 'core', 'sound', 'library_pack_sounds.dart');

// Same as emergency.mjs. Read the notes there before changing a value.
const ENCODING = {
  ios: { ext: 'm4a', codec: 'aac', bitrate: '64k', sampleRate: 48000, channels: 1, opts: ['-aac_coder', 'fast'] },
  android: { ext: 'ogg', codec: 'libopus', bitrate: '48k', sampleRate: 48000, channels: 1, opts: ['-compression_level', '5', '-cutoff', '12000'] },
};
const MAX_DECODED_TP = -1.1, MAX_ROUNDS = 16;
const PAD = 0.06; // digital silence at each end, seconds
const TARGET_LUFS = -8.5, CEIL_DBTP = -1.9;
const MIN_DECODED_LUFS = -9.0, MAX_TP = -1.0, SHORT_TERM_FLOOR = -14;
const MIN_LEN = 10, MAX_LEN = 30;
// iOS swaps a notification sound of 30 s or more for the default. Stay clear of it.
const IOS_MAX_LEN = 29.5;
// Dead air is anything this far under the loudest sample.
const TRIM_DB = -45;

const CC0 = { name: 'CC0 1.0', url: 'https://creativecommons.org/publicdomain/zero/1.0/' };
const PD_NAVY = { name: 'Public domain (PD-USGov-Military-Navy)', url: 'https://commons.wikimedia.org/wiki/Template:PD-USGov-Military-Navy' };
const PD_AUTHOR = { name: 'Public domain (PD-author, via pdsounds.org)', url: 'https://commons.wikimedia.org/wiki/Template:PD-author' };
const PD_SELF = { name: 'Public domain (PD-self)', url: 'https://commons.wikimedia.org/wiki/Template:PD-self' };
const BSB = 'Joseph SARDIN (BigSoundBank)';

// id (stored against topics, never changes) | English name | original file | title on the source
// page | author | source URL | licence | options:
// - gap: seconds of silence after each pass when a short sound is repeated, for a single hit that
//   would otherwise run into itself, and for SOS, which needs the seven-unit Morse word gap
//   (0.7 s at its 0.1 s dot) between one SOS and the next;
// - lp: the master's low-pass, 8200 Hz as in emergency.mjs unless a sound needs less. The digital
//   watch beeps at about 4.1 kHz with a strong 8.2 kHz partial, on for a fifth of the time. Both
//   encoders shift the two partials against each other and the decoded peak lands 2.5 dB over
//   the master, which pushed the limiter ceiling down until the file read -10 LUFS. Taking the
//   partial off at 4200 Hz keeps the beep and lets it reach -8.6 LUFS;
// - hp: the master's high-pass, 170 Hz unless a sound needs more. The beep-beep alarm is a 94 Hz
//   buzz, below what a phone speaker plays. Clipped and high-passed again inside the soft clip it
//   turned spiky, and the limiter held it at -11 LUFS. Starting at 500 Hz keeps the part a phone
//   plays and gets it to -9.2;
// - end: seconds into the original where the sound is cut, with a 0.5 s fade. The long-ring
//   clock stops ringing at 10.0 s and then holds 3 s of ticks and decay, which left a
//   near-silent stretch in every loop (short-term -26 LUFS). Cut at 11.0 s it keeps about 1 s
//   of decay;
// - minLufs: the loudness the decoded files must reach, -9 unless listed. Only the beep-beep
//   alarm is under it: its buzz tops out at -9.2 LUFS through this chain at every setting tried.
// Six candidates are left out on purpose: bsb-1464 (ambulance siren), bsb-3513 and bsb-3514
// (pager tones designed by the pager maker), commons Alarm_-_Collision and Alarm_-_Diving_-_H8
// (provenance through a hobby site) and oga aquinn siren_0 (may hold a civil-defence wail).
const SOUNDS = [
  ['pack_library_buzzer_1', 'Electronic buzzer 1', 'bsb-0035-ALRMClok_Electronic alarm buzzer 1 (ID 0035)_BigSoundBank.com.wav', 'Electronic Alarm (Buzzer) #1', BSB, 'https://bigsoundbank.com/electronic-alarm-buzzer-1-s0035.html', CC0],
  ['pack_library_buzzer_2', 'Electronic buzzer 2', 'bsb-0089-ALRMClok_Electronic alarm buzzer 2 (ID 0089)_BigSoundBank.com.wav', 'Electronic alarm (buzzer) #2', BSB, 'https://bigsoundbank.com/electronic-alarm-buzzer-2-s0089.html', CC0],
  ['pack_library_buzzer_3', 'Electronic buzzer 3', 'bsb-0173-ALRMClok_Electronic alarm buzzer 3 (ID 0173)_BigSoundBank.com.wav', 'Electronic Alarm (Buzzer) #3', BSB, 'https://bigsoundbank.com/electronic-alarm-buzzer-3-s0173.html', CC0],
  ['pack_library_clock_ring_11', 'Wind-up clock', 'bsb-2814-ALRMClok_Mechanical alarm clock ringtone 11 (ID 2814)_BigSoundBank.com.wav', 'Mechanical Alarm Clock, Ringtone #11', BSB, 'https://bigsoundbank.com/mechanical-alarm-clock-ringtone-11-s2814.html', CC0],
  ['pack_library_clock_ring_8', 'Wind-up clock, short', 'bsb-2811-ALRMClok_Mechanical alarm clock ringtone 8 (ID 2811)_BigSoundBank.com.wav', 'Mechanical alarm clock, ringtone #8', BSB, 'https://bigsoundbank.com/mechanical-alarm-clock-ringtone-8-s2811.html', CC0],
  ['pack_library_clock_long_ring', 'Wind-up clock, long ring', 'bsb-1375-ALRMClok_Mechanical alarm clock long ring 2 (ID 1375)_BigSoundBank.com.wav', 'Mechanical alarm clock, long ring #2', BSB, 'https://bigsoundbank.com/mechanical-alarm-clock-long-ring-2-s1375.html', CC0, { end: 11.0 }],
  ['pack_library_digital_watch', 'Digital watch', 'bsb-2256-BEEPTimer_Digital watch alarm (ID 2256)_BigSoundBank.com.wav', 'Digital watch, alarm', BSB, 'https://bigsoundbank.com/digital-watch-alarm-s2256.html', CC0, { lp: 4200 }],
  ['pack_library_piezo_1', 'Piezo alarm 1', 'bsb-1592-ALRMElec_Piezo alarm 1 (ID 1592)_BigSoundBank.com.wav', 'Piezo Alarm #1', BSB, 'https://bigsoundbank.com/piezo-alarm-1-s1592.html', CC0],
  ['pack_library_piezo_3', 'Piezo alarm 3', 'bsb-1996-ALRMElec_Piezo alarm 3 (ID 1996)_BigSoundBank.com.wav', 'Piezo alarm #3', BSB, 'https://bigsoundbank.com/piezo-alarm-3-s1996.html', CC0],
  ['pack_library_buzzer_4', 'Buzzer', 'bsb-1586-ALRMBuzr_Buzzer 4 (ID 1586)_BigSoundBank.com.wav', 'Buzzer #4', BSB, 'https://bigsoundbank.com/buzzer-4-s1586.html', CC0, { gap: 0.3 }],
  ['pack_library_industrial_doorbell', 'Industrial doorbell', 'bsb-1269-BELLDoor_Industrial doorbell (ID 1269)_BigSoundBank.com.wav', 'Industrial Doorbell #1', BSB, 'https://bigsoundbank.com/industrial-doorbell-s1269.html', CC0],
  ['pack_library_boxing_bell', 'Boxing bell', 'bsb-1927-BELLHand_Boxing bell 2 (ID 1927)_BigSoundBank.com.wav', 'Boxing Bell #2', BSB, 'https://bigsoundbank.com/boxing-bell-2-s1927.html', CC0],
  ['pack_library_dive_klaxon', 'Dive klaxon', 'commons-WWII_submarine_dive_klaxon.ogg', 'WWII submarine dive klaxon', 'United States Navy', 'https://commons.wikimedia.org/wiki/File:WWII_submarine_dive_klaxon.ogg', PD_NAVY],
  ['pack_library_school_bell', 'School bell', 'commons-Old_school_bell_1.ogg', 'Old school bell - 1', 'ezwa (pdsounds.org)', 'https://commons.wikimedia.org/wiki/File:Old_school_bell_1.ogg', PD_AUTHOR],
  ['pack_library_school_bell_short', 'School bell, short', 'commons-Old_school_bell_4.ogg', 'Old school bell - 4', 'ezwa (pdsounds.org)', 'https://commons.wikimedia.org/wiki/File:Old_school_bell_4.ogg', PD_AUTHOR],
  ['pack_library_buzzwire', 'Buzzwire', 'commons-Buzzer.wav', 'Buzzer (buzzwire tutorial)', 'David Pride', 'https://commons.wikimedia.org/wiki/File:Buzzer.wav', CC0, { gap: 0.3 }],
  ['pack_library_sos_morse', 'SOS in Morse', 'commons-SOS_morse_code.ogg', 'SOS in Morse code (synthesized in Audacity)', 'Hydrargyrum', 'https://commons.wikimedia.org/wiki/File:SOS_morse_code.ogg', PD_SELF, { gap: 0.7 }],
  ['pack_library_toy_siren', 'Toy fire engine', 'commons-Toy_siren_alarm.ogg', 'Toy Siren Alarm (toy fire engine)', 'stephan (pdsounds.org)', 'https://commons.wikimedia.org/wiki/File:Toy_siren_alarm.ogg', PD_AUTHOR],
  ['pack_library_heart_monitor', 'Heart monitor', 'commons-Heart_Monitor_Beep--freesound.org.oga', 'Heart Monitor Beep', 'samfk360 (Freesound 148897)', 'https://commons.wikimedia.org/wiki/File:Heart_Monitor_Beep--freesound.org.oga', CC0],
  ['pack_library_beep_beep', 'Beep beep beep', 'commons-Alarm_or_siren.ogg', 'Alarm or Siren (synthesized beep-beep-beep)', 'stephan (pdsounds.org)', 'https://commons.wikimedia.org/wiki/File:Alarm_or_siren.ogg', PD_AUTHOR, { hp: 500, minLufs: -9.5 }],
  ['pack_library_game_alarm', 'Game alarm', 'oga-frenchyboy-alarm_0.wav', 'Alarm', 'Frenchyboy (OpenGameArt)', 'https://opengameart.org/content/alarm-2', CC0],
  ['pack_library_synth_alarm', 'Synth alarm', 'oga-bonzille-alarm_2.wav', 'Alarm sound effect (made with jfxr)', 'bonzille (OpenGameArt)', 'https://opengameart.org/content/alarm-sound-effect', CC0],
  ['pack_library_short_alarm', 'Short alarm', 'oga-yd-alarm_0.ogg', 'Short alarm', 'yd (OpenGameArt)', 'https://opengameart.org/content/short-alarm', CC0],
].map(([id, name, file, title, author, url, licence, opts = {}]) => ({ id, name, file, title, author, url, licence, gap: 0, lp: 8200, hp: 170, end: 0, minLufs: MIN_DECODED_LUFS, ...opts }));

if (SOUNDS.length !== 23 || new Set(SOUNDS.map(s => s.id)).size !== 23) throw new Error('the table must hold 23 distinct ids');

// ---------- small helpers ----------
const clamp = (x, a, b) => Math.max(a, Math.min(b, x));
const db = d => Math.pow(10, d / 20);
const S = t => Math.round(t * SR);

// ---------- mastering, copied from emergency.mjs so both stay byte for byte the same chain ----------
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
  // ceil is one level, or one per sample (see the round loop below).
  for (let i = 0; i < n; i++) { const c = typeof ceil === 'number' ? ceil : ceil[i]; req[i] = pk[i] > c ? c / pk[i] : 1; }
  const a = new Float64Array(n);
  for (let i = 0; i < n; i++) { let m = 1; for (let j = i; j <= i + LA && j < n; j++) if (req[j] < m) m = req[j]; a[i] = m; }
  const rr = new Float64Array(n); let prev = 1;
  for (let i = 0; i < n; i++) { prev = Math.min(a[i], prev + (1 - prev) * rel); rr[i] = prev; }
  let sum = 0; const g = new Float64Array(n);
  for (let i = 0; i < n; i++) { sum += rr[i]; if (i > LA) sum -= rr[i - LA - 1]; g[i] = sum / Math.min(i + 1, LA + 1); }
  for (let i = 0; i < n; i++) { l[i] *= g[i]; r[i] *= g[i]; }
  return [l, r];
}
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
function shortTerm(L, R) {
  const kl = kweight(L), kr = R ? kweight(R) : null, n = L.length, h = S(1.5), sq = new Float64Array(n + 1);
  for (let i = 0; i < n; i++) sq[i + 1] = sq[i] + kl[i] * kl[i] + (kr ? kr[i] * kr[i] : 0);
  const out = new Float64Array(n);
  for (let i = 0; i < n; i++) { const a = Math.max(0, i - h), b = Math.min(n, i + h); out[i] = -0.691 + 10 * Math.log10((sq[b] - sq[a]) / S(3) || 1e-12); }
  return out;
}
const LEVEL_LU = 3.5, LEVEL_MAX_DB = 8;
function shape(L, R) {
  const chans = R ? [L, R] : [L];
  for (const ch of chans) biquad(ch, 'pk', 3000, 0.8, 3);
  const st = shortTerm(L, R), I = lufs(L, R), sm = S(0.25), n = L.length, g = new Float64Array(n);
  for (let i = 0; i < n; i++) g[i] = clamp(I - LEVEL_LU - st[i], 0, LEVEL_MAX_DB);
  let acc = 0; const lv = new Float64Array(n);
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
// Mono only here: every library sound is folded to mono when it is decoded.
// ceil is the limiter ceiling per sample, linear. It starts at CEIL_DBTP everywhere and only
// drops where an encoded file overshot (see the round loop). The soft clip stays at the base level.
function master(x, ceil, lp = 8200, target = TARGET_LUFS, hp = 170) {
  const L = Float64Array.from(x);
  biquad(L, 'hp', hp, 0.707); biquad(L, 'hp', hp, 0.707); biquad(L, 'lp', lp, 0.707); biquad(L, 'lp', lp, 0.707);
  silenceEnds(L);
  shape(L, null);
  let pk = 0; for (let i = 0; i < L.length; i++) pk = Math.max(pk, Math.abs(L[i]));
  let gain = db(-6) / pk, out, lv, prev = null;
  const ceilDb = CEIL_DBTP;
  // More rounds than emergency.mjs allows: a recording's crest factor moves more with gain than
  // a synthesized tone's, so the search can take longer to settle.
  for (let it = 0; it < 48; it++) {
    const c = softClip([L], gain, ceilDb + CLIP_OVER_CEIL_DB);
    out = limit(c[0], c[0], 1, ceil); lv = lufs(out[0], null);
    if (Math.abs(lv - target) < 0.05) break;
    const g = 20 * Math.log10(gain);
    let step = target - lv;
    if (prev && Math.abs(lv - prev.lv) > 1e-3 && g !== prev.g) step *= clamp((g - prev.g) / (lv - prev.lv), 0.5, 12);
    prev = { g, lv };
    gain = db(g + clamp(step, -12, 12));
  }
  // A sparse sound can fall short under a low ceiling. The decoded files are checked against
  // MIN_DECODED_LUFS after encoding, which is the rule that matters.
  const y = out[0];
  silenceEnds(y);
  return { y, lufs: lv };
}
function writeWav24(path, y) {
  const n = y.length, data = Buffer.alloc(n * 3), h = Buffer.alloc(44);
  for (let i = 0; i < n; i++) data.writeIntLE(Math.round(clamp(y[i], -1, 1) * 8388607), i * 3, 3);
  h.write('RIFF', 0); h.writeUInt32LE(36 + data.length, 4); h.write('WAVE', 8); h.write('fmt ', 12);
  h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22); h.writeUInt32LE(SR, 24);
  h.writeUInt32LE(SR * 3, 28); h.writeUInt16LE(3, 32); h.writeUInt16LE(24, 34); h.write('data', 36); h.writeUInt32LE(data.length, 40);
  writeFileSync(path, Buffer.concat([h, data]));
}

// ---------- preparing a recording ----------
// Decodes anything ffmpeg reads to 48 kHz mono, folding stereo to (L + R) / 2.
function decode(path) {
  const r = spawnSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-i', path, '-ac', '1', '-ar', String(SR), '-f', 'f64le', '-'], { maxBuffer: 1 << 30 });
  if (r.status !== 0) throw new Error(`could not decode ${path}: ${r.stderr}`);
  const out = new Float64Array(r.stdout.length / 8);
  for (let i = 0; i < out.length; i++) out[i] = r.stdout.readDoubleLE(i * 8);
  return out;
}
// Cuts the original at `end` seconds, fading out over the last 0.5 s.
function cutAt(x, end) {
  if (!end) return x;
  const n = Math.min(x.length, S(end)), f = Math.min(S(0.5), n), y = x.slice(0, n);
  for (let i = 0; i < f; i++) y[n - 1 - i] *= i / f;
  return y;
}
// Cuts the dead air off both ends: everything quieter than TRIM_DB under the loudest sample, after
// a 20 Hz high-pass so a DC offset does not count as sound. Keeps 5 ms before the first sound and
// 20 ms after the last, with short fades so the cut never clicks.
function trim(x) {
  const hp = biquad(Float64Array.from(x), 'hp', 20, 0.707);
  let pk = 0; for (const v of hp) pk = Math.max(pk, Math.abs(v));
  const th = pk * db(TRIM_DB);
  let a = 0; while (a < hp.length && Math.abs(hp[a]) < th) a++;
  let b = hp.length - 1; while (b > a && Math.abs(hp[b]) < th) b--;
  a = Math.max(0, a - S(0.005)); b = Math.min(hp.length, b + S(0.02));
  const y = hp.slice(a, b), f = Math.min(S(0.005), y.length >> 2);
  for (let i = 0; i < f; i++) { const g = i / f; y[i] *= g; y[y.length - 1 - i] *= g; }
  return y;
}
// Repeats a short sound to a whole number of passes that lasts at least MIN_LEN, with `gap`
// seconds of silence after each pass. Adds PAD of silence at each end for the master.
function build(y, gap) {
  const pass = y.length + S(gap), passLen = pass / SR;
  const reps = passLen + 2 * PAD >= MIN_LEN ? 1 : Math.ceil((MIN_LEN - 2 * PAD) / passLen);
  const body = reps === 1 ? y.length : pass * reps;
  const out = new Float64Array(body + 2 * S(PAD));
  for (let r = 0; r < reps; r++) out.set(y, S(PAD) + r * pass);
  return { x: out, reps };
}

// ---------- encode and measure ----------
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
// True peak per sample (4x oversampled) of a file once decoded to 48 kHz mono, so the round loop
// can see where an encoder pushed past the ceiling.
const decodedPeaks = file => {
  const y = decode(file);
  return tpPeaks(y, y);
};
const encode = (wav, platform, id) => {
  const e = ENCODING[platform];
  const dir = platform === 'ios' ? join(OUT.ios, 'sounds') : join(OUT.android, 'sounds');
  const out = join(dir, `${id}.${e.ext}`);
  ff(['-i', wav, ...same, '-ac', String(e.channels), '-ar', String(e.sampleRate), '-c:a', e.codec, '-b:a', e.bitrate, ...(e.opts || []), out]);
  return { file: out, ...decodedLevels(out), peaks: decodedPeaks(out) };
};

// ---------- credits and the Dart table ----------
function licensesMd(rows) {
  const lines = [
    '# Library sound pack credits',
    '',
    `The ${rows.length} sounds in the \`${PACK_ID}\` pack are recordings by other people, released as CC0 or`,
    'public domain. None of them asks for credit. Crit Alarm credits every one anyway.',
    '',
    'Each file was trimmed, repeated where short, levelled and re-encoded by',
    '`tools/sounds/library_pack.mjs` in the critalarm-app repo. The prepared files are released under',
    'the same terms as their source.',
    '',
    '| Id | Name | Title on the source page | Author | Source | Licence |',
    '|---|---|---|---|---|---|',
    ...rows.map(s => `| \`${s.id}\` | ${s.name} | ${s.title} | ${s.author} | <${s.url}> | [${s.licence.name}](${s.licence.url}) |`),
    '',
  ];
  return lines.join('\n');
}
const dartString = s => `'${s.replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$')}'`;
function dartTable(rows) {
  return [
    '// Written by tools/sounds/library_pack.mjs. Do not edit by hand: change the',
    '// table in the script and run it again.',
    '',
    "import 'package:critalarm/core/sound/sound_pack.dart';",
    '',
    '/// The sounds in the library pack, in the order the picker lists them.',
    'const libraryPackSounds = <PackSoundInfo>[',
    ...rows.map(s => [
      '  PackSoundInfo(',
      `    id: ${dartString(s.id)},`,
      `    englishName: ${dartString(s.name)},`,
      `    duration: Duration(milliseconds: ${s.ms}),`,
      `    title: ${dartString(s.title)},`,
      `    author: ${dartString(s.author)},`,
      `    sourceUrl: ${dartString(s.url)},`,
      `    licence: ${dartString(s.licence.name)},`,
      '  ),',
    ].join('\n')),
    '];',
    '',
  ].join('\n');
}

// ---------- run ----------
const [src, only] = process.argv.slice(2);
if (!src || (only && !SOUNDS.some(s => s.id === only))) {
  console.error('usage: node tools/sounds/library_pack.mjs <folder with the original downloads> [id]');
  console.error('With an id, only that sound is rebuilt and the credits and the Dart table are left alone.');
  process.exit(1);
}
for (const dir of [join(OUT.android, 'sounds'), join(OUT.ios, 'sounds')]) {
  if (!only) rmSync(dir, { recursive: true, force: true });
  mkdirSync(dir, { recursive: true });
}
const tmp = mkdtempSync(join(tmpdir(), 'critalarm-library-'));
const done = [], belowFloor = [];
try {
  for (const s of SOUNDS) {
    if (only && s.id !== only) continue;
    const trimmed = trim(cutAt(decode(join(src, s.file)), s.end));
    const { x, reps } = build(trimmed, s.gap);
    const dur = x.length / SR;
    if (dur < MIN_LEN || dur > Math.min(MAX_LEN, IOS_MAX_LEN)) throw new Error(`${s.id} is ${dur.toFixed(2)} s, outside ${MIN_LEN} to ${IOS_MAX_LEN} s`);
    // Two things can send a sound round again, at most MAX_ROUNDS times in all:
    // - a decoded true peak over MAX_DECODED_TP lowers the limiter ceiling by the overshoot, only
    //   in the 10 ms frames where it happened plus 20 ms either side. emergency.mjs drops the
    //   ceiling for the whole sound instead; on a recording the overshoot sits on a handful of
    //   attacks, and a global drop cost the beep-beep alarm 2.5 LU for two bad frames;
    // - a decoded file under MIN_DECODED_LUFS raises the master's target by the shortfall. AAC
    //   reads a steady pure tone (the 440 Hz SOS) a full 1 LU under its master.
    const ceil = new Float64Array(x.length).fill(db(CEIL_DBTP)), FR = S(0.01), SPREAD = S(0.02);
    let target = TARGET_LUFS, m, got;
    for (let round = 0; ; round++) {
      m = master(x, ceil, s.lp, target, s.hp);
      const wav = join(tmp, `${s.id}.wav`);
      writeWav24(wav, m.y);
      got = Object.keys(ENCODING).map(p => ({ platform: p, ...encode(wav, p, s.id) }));
      const worst = Math.max(...got.map(g => g.TP));
      const quietest = Math.min(...got.map(g => g.I));
      if (process.env.DEBUG) console.log(`  round ${round} ${got.map(g => `${g.platform} ${g.I.toFixed(2)}/${g.TP.toFixed(2)}`).join(' ')}`);
      if (worst <= MAX_DECODED_TP && quietest >= s.minLufs) break;
      if (round === MAX_ROUNDS - 1) throw new Error(`${s.id}: decoded ${quietest.toFixed(1)} LUFS and ${worst.toFixed(1)} dBTP after ${MAX_ROUNDS} rounds`);
      if (worst > MAX_DECODED_TP) {
        const limitLin = db(MAX_DECODED_TP - 0.05);
        for (let f = 0; f < x.length; f += FR) {
          let over = 0;
          for (const g of got) for (let i = f; i < Math.min(f + FR, g.peaks.length); i++) over = Math.max(over, g.peaks[i]);
          if (over <= limitLin) continue;
          for (let i = Math.max(0, f - SPREAD); i < Math.min(x.length, f + FR + SPREAD); i++) ceil[i] *= limitLin / over;
        }
      }
      if (quietest < s.minLufs) target += s.minLufs - quietest + 0.2;
    }
    for (const g of got) {
      if (g.I < s.minLufs) throw new Error(`${s.id} ${g.platform} decodes at ${g.I} LUFS, under ${s.minLufs}`);
      if (g.TP > MAX_TP) throw new Error(`${s.id} ${g.platform} true peak ${g.TP} dBTP, over ${MAX_TP}`);
    }
    const st = shortTerm(m.y, null).slice(S(1.5), m.y.length - S(1.5));
    const minShort = st.reduce((a, b) => Math.min(a, b), Infinity);
    if (minShort < SHORT_TERM_FLOOR) belowFloor.push(`${s.id} ${minShort.toFixed(1)}`);
    const ms = Math.round(dur * 1000);
    done.push({ ...s, ms });
    console.log(`${s.id.padEnd(34)} ${dur.toFixed(2).padStart(5)} s  x${reps}  master ${m.lufs.toFixed(2)} LUFS (target ${target.toFixed(1)})  lowest ceiling ${(20 * Math.log10(ceil.reduce((a, b) => Math.min(a, b), 1))).toFixed(2)} dBTP  short-term min ${minShort.toFixed(1)} LUFS  ${got.map(g => `${g.platform === 'ios' ? 'm4a' : 'ogg'} ${g.I.toFixed(1)} LUFS ${g.TP.toFixed(1)} dBTP`).join(', ')}`);
  }
} finally {
  rmSync(tmp, { recursive: true, force: true });
}
if (only) process.exit(0);
const md = licensesMd(done);
writeFileSync(join(OUT.android, 'LICENSES.md'), md);
writeFileSync(join(OUT.ios, 'LICENSES.md'), md);
writeFileSync(DART_OUT, dartTable(done));
// The repo formats Dart through fvm. Without it the table still compiles, it just needs a format.
const fmt = spawnSync('fvm', ['dart', 'format', DART_OUT], { cwd: ROOT, encoding: 'utf8' });
const dartRel = DART_OUT.slice(ROOT.length + 1);
console.log(`${done.length} sounds written.${fmt.status === 0 ? '' : ` Run "fvm dart format ${dartRel}" next.`}`);
if (belowFloor.length) console.log(`Short-term loudness dips under ${SHORT_TERM_FLOOR} LUFS (the source has gaps of its own): ${belowFloor.join(', ')}`);

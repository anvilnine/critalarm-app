#!/usr/bin/env python3
"""Build the first eight bundled alarm sounds.

The 14 emergency sounds come from tools/sounds/emergency.mjs instead.

Every sound is written here from scratch with the Python standard library, so
all eight are our own work and carry no third-party licence. Run this and the
files under assets/sounds/ are rebuilt byte for byte the same way.

    python3 tools/sounds/generate.py

Needs ffmpeg on PATH for the mp3 and ogg encodes. The ogg files hold Opus, see
the note in encode() for why.

Two rules every sound follows, checked at the end of the run:

1. It starts and ends with silence. mp3 encoders add a little padding at both
   ends, so a sound that begins mid-tone clicks every time the loop wraps.
   Silence at the seam hides that padding.
2. It is 10 to 20 seconds long and holds a whole number of pattern repeats, so
   the wrap lands where a repeat would have landed anyway.

Every sound is also mastered loud (see build()), and both decoded files must
read under -1.0 dBTP true peak. A sound whose plain render is already loud gets
gain only, so nothing is added to its waveform. A quiet one is shaped up to
-8.5 LUFS.
"""

import array
import math
import re
import struct
import subprocess
import sys
from pathlib import Path

SAMPLE_RATE = 44100
PEAK = 0.89
EDGE_SILENCE_S = 0.06
OUT_DIR = Path(__file__).resolve().parents[2] / "assets" / "sounds"

# Loudness. An alarm that is not loud is not doing its job: every bundled sound
# has to read at least -9 LUFS on its decoded mono app file. The master aims at
# -8.5 so the mp3 and Opus encodes still land above -9.
TARGET_LUFS = -8.5
# Decoded true peak limit, with 0.1 dB of room under -1.0 dBTP.
MAX_DECODED_TP = -1.1
FIRST_CEIL_DBTP = -1.5
MAX_CEIL_ROUNDS = 8
# A sound whose plain render already reads TARGET_LUFS or more takes the clean
# path: gain only, turned down until both decoded files read under
# MAX_DECODED_TP. Nothing is added to the waveform. Shaping a pure sine for a
# fraction of a LU put 8 % THD on the pager beep, which is worse than the
# fraction. The turn-down costs 0.15 to 0.65 LU; the run fails past
# MAX_GIVE_LU. A clean 4x limiter was tried for the square waves instead: it
# could not hold even 0.5 LU under their plain level.
MAX_GIVE_LU = 0.7
# Shaping ahead of the limiter, for sounds under TARGET_LUFS. The same chain as
# tools/sounds/loops.mjs:
# - presence: a broad +3 dB around 3 kHz, where phone speakers and ears are
#   most sensitive;
# - parallel compression: half the signal through a 4:1 compressor with
#   makeup, mixed back with the dry half, so decaying notes and quiet beeps
#   come up and the attacks keep their shape;
# - soft clip at 4x (176.4 kHz): a tanh curve a little above the limiter
#   ceiling rounds the loudest transients;
# - a 25 Hz high-pass right after the clip: a tanh on a lopsided waveform shifts
#   it off zero, and Opus strips that DC while mp3 keeps it, so the two files
#   differed and the Opus file's end silence never settled;
# - limiter at 4x, so it catches peaks between samples.
PRESENCE = "equalizer=f=3000:t=q:w=0.9:g=3"
PARALLEL = "acompressor=threshold=0.1:ratio=4:attack=4:release=160:knee=4:makeup=2.5:mix=0.5"
CLIP_OVER_CEIL_DB = 1.5
OVERSAMPLED = SAMPLE_RATE * 4
# bitexact keeps encoder version strings and random Ogg serial numbers out of
# the files, so a second run writes the same bytes. map_metadata -1 drops the
# wav's tags. Without these, every rerun changed every file.
SAME = ["-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact"]


def square(phase, harmonics=9):
    """Square-ish wave built from odd harmonics, so it does not alias."""
    total = 0.0
    for k in range(1, harmonics * 2, 2):
        total += math.sin(phase * k) / k
    return total * (4 / math.pi) / 1.27


def saw(phase, harmonics=12):
    total = 0.0
    for k in range(1, harmonics + 1):
        total += math.sin(phase * k) / k
    return total * (2 / math.pi) / 1.0


def edge_fade(t, length, ramp=0.006):
    """Short in and out ramp so a burst does not click at its own edges."""
    if t < ramp:
        return t / ramp
    if t > length - ramp:
        return max(0.0, (length - t) / ramp)
    return 1.0


def burst(t, start, length, freq, wave_fn=math.sin, gain=1.0):
    """One tone that lives inside [start, start + length) and is silent outside."""
    local = t - start
    if local < 0 or local >= length:
        return 0.0
    return gain * edge_fade(local, length) * wave_fn(2 * math.pi * freq * local)


# --- the eight patterns -------------------------------------------------
# Each returns one sample for time t inside one repeat of the pattern.


def classic_siren(t, period=4.0):
    """Up-and-down wail, then a short rest."""
    lead, blast = 0.1, 3.5
    if t < lead or t >= lead + blast:
        return 0.0
    t -= lead
    # Frequency runs 600 Hz up to 1400 Hz and back. Phase is the integral of it.
    phase = 2 * math.pi * (
        600 * t + 400 * (t - (blast / (2 * math.pi)) * math.sin(2 * math.pi * t / blast))
    )
    return edge_fade(t, blast, 0.05) * (0.75 * math.sin(phase) + 0.25 * math.sin(2 * phase))


def pulsing_klaxon(t, period=1.0):
    """Hard on-off honk, the sound a ship's klaxon makes."""
    return burst(t, 0.1, 0.35, 440.0, square, 0.95)


def marimba_escalator(t, period=2.6):
    """Six wooden notes climbing a pentatonic ladder."""
    steps = [392.0, 440.0, 523.25, 587.33, 659.25, 783.99]
    slot = 0.4
    t -= 0.1
    if t < 0 or t >= slot * len(steps):
        return 0.0
    index = min(int(t / slot), len(steps) - 1)
    local = t - index * slot
    freq = steps[index]
    decay = math.exp(-local * 7.0)
    body = math.sin(2 * math.pi * freq * local) + 0.35 * math.sin(4 * math.pi * freq * local)
    return edge_fade(local, slot, 0.004) * decay * body * 0.7


def soft_to_loud_ramp(t, period=15.0):
    """Same beep over and over, starting quiet and ending loud.

    A pure 880 Hz sine, so it takes gain only, never shaping. To reach the
    loudness target that way, each beep is 0.4 s of every 0.5 s (it was
    0.22 s), and the level climbs in even dB steps from -16 dB to full over
    the first 8 s, then holds. The first 3 s read about -18 LUFS short-term.
    """
    slot, on, rise = 0.5, 0.4, 8.0
    if t < 0.1:
        return 0.0
    index = int((t - 0.1) / slot)
    local = (t - 0.1) - index * slot
    if local >= on or t > period - 0.5:
        return 0.0
    level = 10 ** (-16.0 * (1.0 - min(1.0, (t - 0.1) / rise)) / 20)
    return edge_fade(local, on, 0.008) * level * math.sin(2 * math.pi * 880.0 * local)


def pager_beep(t, period=2.0):
    """Three thin high beeps, like an old hospital pager."""
    out = 0.0
    for i in range(3):
        out += burst(t, 0.12 + i * 0.15, 0.08, 2600.0, math.sin, 0.9)
    return out


def submarine_dive_horn(t, period=5.0):
    """Two low blasts from the bottom of a hull."""
    def horn(local, length):
        body = (math.sin(2 * math.pi * 165.0 * local) * 0.6 +
                math.sin(2 * math.pi * 330.0 * local) * 0.25 +
                math.sin(2 * math.pi * 82.5 * local) * 0.3)
        return edge_fade(local, length, 0.08) * body
    if 0.1 <= t < 2.1:
        return horn(t - 0.1, 2.0)
    if 2.6 <= t < 3.6:
        return horn(t - 2.6, 1.0)
    return 0.0


def rising_synth_sweep(t, period=2.5):
    """A saw that climbs and cuts out at the top."""
    length = 2.1
    if t < 0.08 or t >= 0.08 + length:
        return 0.0
    local = t - 0.08
    low, high = 220.0, 1760.0
    ratio = high / low
    # Exponential sweep. The phase is the integral of the frequency.
    phase = 2 * math.pi * low * length / math.log(ratio) * (ratio ** (local / length) - 1)
    envelope = edge_fade(local, length, 0.05) * (0.25 + 0.75 * (local / length))
    return envelope * saw(phase) * 0.75


def plain_loud_beep(t, period=1.0):
    """No character at all. Just a loud beep with a gap."""
    return burst(t, 0.1, 0.5, 1000.0, square, 1.0)


SOUNDS = [
    ("classic_siren", "Classic siren", classic_siren, 4.0, 4),
    ("pulsing_klaxon", "Pulsing klaxon", pulsing_klaxon, 1.0, 12),
    ("marimba_escalator", "Marimba escalator", marimba_escalator, 2.6, 6),
    ("soft_to_loud_ramp", "Soft to loud ramp", soft_to_loud_ramp, 15.0, 1),
    ("pager_beep", "Pager beep", pager_beep, 2.0, 7),
    ("submarine_dive_horn", "Submarine dive horn", submarine_dive_horn, 5.0, 3),
    ("rising_synth_sweep", "Rising synth sweep", rising_synth_sweep, 2.5, 6),
    ("plain_loud_beep", "Plain loud beep", plain_loud_beep, 1.0, 12),
]


def render(fn, period, repeats):
    total = period * repeats
    count = int(round(total * SAMPLE_RATE))
    samples = []
    for i in range(count):
        t = i / SAMPLE_RATE
        samples.append(fn(t % period, period))
    high = max(abs(s) for s in samples)
    if high == 0:
        raise SystemExit("a sound rendered to pure silence")
    scale = PEAK / high
    return [s * scale for s in samples], total


def check_edges(name, samples):
    """Both ends must be silent, or the loop clicks once per wrap."""
    window = int(EDGE_SILENCE_S * SAMPLE_RATE)
    head = max(abs(s) for s in samples[:window])
    tail = max(abs(s) for s in samples[-window:])
    if head > 0.002 or tail > 0.002:
        raise SystemExit(
            f"{name}: needs {EDGE_SILENCE_S * 1000:.0f} ms of silence at both "
            f"ends, found head={head:.4f} tail={tail:.4f}"
        )


def write_wav(path, samples):
    """32-bit float mono wav."""
    data = array.array("f", samples)
    if sys.byteorder != "little":
        data.byteswap()
    body = data.tobytes()
    header = (b"RIFF" + struct.pack("<I", 36 + len(body)) + b"WAVEfmt "
              + struct.pack("<IHHIIHH", 16, 3, 1, SAMPLE_RATE, SAMPLE_RATE * 4, 4, 32)
              + b"data" + struct.pack("<I", len(body)))
    path.write_bytes(header + body)


def ffmpeg(args, **kw):
    return subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *args],
                          check=True, **kw)


def levels(path):
    """Integrated LUFS and true peak (dBTP) of a file decoded and folded to mono."""
    # The summary rounds to 0.1 LU, too coarse for the gain search, so the
    # loudness comes from the last frame's metadata, which is not rounded.
    run = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-i", str(path), "-ac", "1",
         "-af", "ebur128=peak=true:metadata=1,ametadata=mode=print:key=lavfi.r128.I:file=/dev/stdout",
         "-f", "null", "-"],
        check=True, capture_output=True, text=True)
    lufs = float(re.findall(r"lavfi\.r128\.I=(-?[\d.]+)", run.stdout)[-1])
    peak = float(re.findall(r"Peak:\s+(-?[\d.]+|-inf) dBFS", run.stderr)[-1])
    return lufs, peak


def shape_and_limit(src, dst, gain_db, ceil_db):
    """Gain, presence, parallel compression, then soft clip, DC block and limiter at 4x."""
    chain = ",".join([
        f"volume={gain_db:.4f}dB", PRESENCE, PARALLEL, f"aresample={OVERSAMPLED}",
        f"asoftclip=type=tanh:threshold={10 ** ((ceil_db + CLIP_OVER_CEIL_DB) / 20):.6f}",
        "highpass=f=25:p=2", "lowpass=f=18000:p=2,lowpass=f=18000:p=2",
        f"alimiter=limit={10 ** (ceil_db / 20):.6f}:attack=1.5:release=90:asc=1:level=false",
        f"aresample={SAMPLE_RATE}",
    ])
    ffmpeg(["-i", str(src), "-af", chain, "-c:a", "pcm_f32le", str(dst)])


def read_wav(path):
    raw = ffmpeg(["-i", str(path), "-f", "f32le", "-ac", "1", "-"], capture_output=True).stdout
    data = array.array("f")
    data.frombytes(raw)
    if sys.byteorder != "little":
        data.byteswap()
    return data


def master(raw_wav, out_wav, ceil_db, target):
    """Find the gain that puts the shaped, limited master at `target` LUFS.

    Secant search on the gain in dB: once the limiter works hard, each dB of
    gain buys well under 1 LU, so stepping by the shortfall alone stalls.
    """
    gain, prev = 0.0, None
    for _ in range(24):
        shape_and_limit(raw_wav, out_wav, gain, ceil_db)
        lufs, _ = levels(out_wav)
        if abs(lufs - target) < 0.05:
            return lufs
        step = target - lufs
        if prev and abs(lufs - prev[1]) > 1e-3 and gain != prev[0]:
            step *= min(12.0, max(0.5, (gain - prev[0]) / (lufs - prev[1])))
        prev = (gain, lufs)
        gain += min(12.0, max(-12.0, step))
    raise SystemExit(f"{out_wav.name}: master reached {lufs:.2f} LUFS, not {target}")


def encode(wav_path, stem):
    mp3 = OUT_DIR / f"{stem}.mp3"
    ogg = OUT_DIR / f"{stem}.ogg"
    ffmpeg(["-i", str(wav_path), *SAME, "-codec:a", "libmp3lame", "-q:a", "2",
            "-ar", "44100", "-ac", "1", str(mp3)])
    # Ogg holding Opus, not Vorbis. Homebrew's ffmpeg ships no libvorbis and its
    # own Vorbis encoder smears short beeps. Android has played Ogg/Opus since
    # API 21 and this app's floor is API 28, so nothing is lost.
    ffmpeg(["-i", str(wav_path), *SAME, "-codec:a", "libopus", "-b:a", "96k",
            "-ar", "48000", "-ac", "1", str(ogg)])
    return mp3, ogg


def encode_checked(stem, wav):
    check_edges(stem, read_wav(wav))
    mp3, ogg = encode(wav, stem)
    decoded = {p.suffix[1:]: levels(p) for p in (mp3, ogg)}
    return decoded, max(tp for _, tp in decoded.values()), mp3, ogg


def build(stem, samples, work):
    """Master and encode one sound. Returns what happened, for the log line.

    Clean path (plain render at TARGET_LUFS or more): gain only, turned down
    until both decoded files read under MAX_DECODED_TP, at most MAX_GIVE_LU.
    Shaped path (quieter sounds): shaped and limited to TARGET_LUFS, and the
    limiter ceiling drops until both decoded files read under the limit.
    """
    raw = work / f"{stem}-raw.wav"
    wav = work / f"{stem}.wav"
    write_wav(raw, samples)
    plain, _ = levels(raw)
    if plain >= TARGET_LUFS:
        gain = 0.0
        for _ in range(MAX_CEIL_ROUNDS):
            scale = 10 ** (gain / 20)
            write_wav(wav, [v * scale for v in samples])
            decoded, worst, mp3, ogg = encode_checked(stem, wav)
            if worst <= MAX_DECODED_TP:
                break
            gain -= worst - MAX_DECODED_TP + 0.05
        else:
            raise SystemExit(f"{stem}: decoded true peak still {worst:.1f} dBTP on gain alone")
        if -gain > MAX_GIVE_LU:
            raise SystemExit(f"{stem}: gain alone costs {-gain:.2f} dB, over {MAX_GIVE_LU}")
        return f"clean, gain {gain:+.2f} dB", plain, decoded, mp3, ogg
    ceil = FIRST_CEIL_DBTP
    for _ in range(MAX_CEIL_ROUNDS):
        master(raw, wav, ceil, TARGET_LUFS)
        decoded, worst, mp3, ogg = encode_checked(stem, wav)
        if worst <= MAX_DECODED_TP:
            return f"shaped, ceiling {ceil:.2f} dBTP", plain, decoded, mp3, ogg
        ceil -= worst - MAX_DECODED_TP + 0.05
    raise SystemExit(f"{stem}: decoded true peak still {worst:.1f} dBTP after {MAX_CEIL_ROUNDS} rounds")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    work = OUT_DIR / ".wav"
    work.mkdir(exist_ok=True)
    rows = []
    only = sys.argv[1:]
    for stem, title, fn, period, repeats in SOUNDS:
        if only and stem not in only:
            continue
        samples, total = render(fn, period, repeats)
        if not 10.0 <= total <= 20.0:
            raise SystemExit(f"{stem}: {total:.1f}s is outside the 10-20 s range")
        check_edges(stem, samples)
        how, plain, decoded, mp3, ogg = build(stem, samples, work)
        rows.append((stem, title, total, mp3.stat().st_size, ogg.stat().st_size))
        got = "  ".join(f"{ext} {i:5.1f} LUFS {tp:5.1f} dBTP" for ext, (i, tp) in decoded.items())
        print(f"{stem:20s} {total:4.1f}s  plain {plain:5.1f}  {got}  ({how})  "
              f"mp3 {mp3.stat().st_size:>7d} B  ogg {ogg.stat().st_size:>7d} B")
    for path in work.glob("*.wav"):
        path.unlink()
    work.rmdir()
    print(f"\n{len(rows)} sounds written to {OUT_DIR}")


if __name__ == "__main__":
    sys.exit(main())

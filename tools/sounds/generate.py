#!/usr/bin/env python3
"""Build the eight bundled alarm sounds.

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
"""

import math
import struct
import subprocess
import sys
import wave
from pathlib import Path

SAMPLE_RATE = 44100
PEAK = 0.89
EDGE_SILENCE_S = 0.06
OUT_DIR = Path(__file__).resolve().parents[2] / "assets" / "sounds"


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
    """Same beep over and over, starting almost inaudible and ending loud."""
    slot = 0.5
    if t < 0.1:
        return 0.0
    index = int((t - 0.1) / slot)
    local = (t - 0.1) - index * slot
    if local >= 0.22 or t > period - 0.5:
        return 0.0
    level = 0.04 + 0.96 * min(1.0, (t / (period - 1.0)) ** 1.6)
    return edge_fade(local, 0.22, 0.008) * level * math.sin(2 * math.pi * 880.0 * local)


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
    frames = b"".join(
        struct.pack("<h", max(-32768, min(32767, int(s * 32767)))) for s in samples
    )
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(frames)


def encode(wav_path, stem):
    mp3 = OUT_DIR / f"{stem}.mp3"
    ogg = OUT_DIR / f"{stem}.ogg"
    subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav_path),
         "-codec:a", "libmp3lame", "-q:a", "2", "-ar", "44100", "-ac", "1", str(mp3)],
        check=True,
    )
    # Ogg holding Opus, not Vorbis. Homebrew's ffmpeg ships no libvorbis and its
    # own Vorbis encoder smears short beeps. Android has played Ogg/Opus since
    # API 21 and this app's floor is API 28, so nothing is lost.
    subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wav_path),
         "-codec:a", "libopus", "-b:a", "96k", "-ar", "48000", "-ac", "1", str(ogg)],
        check=True,
    )
    return mp3, ogg


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    work = OUT_DIR / ".wav"
    work.mkdir(exist_ok=True)
    rows = []
    for stem, title, fn, period, repeats in SOUNDS:
        samples, total = render(fn, period, repeats)
        if not 10.0 <= total <= 20.0:
            raise SystemExit(f"{stem}: {total:.1f}s is outside the 10-20 s range")
        check_edges(stem, samples)
        wav_path = work / f"{stem}.wav"
        write_wav(wav_path, samples)
        mp3, ogg = encode(wav_path, stem)
        rows.append((stem, title, total, mp3.stat().st_size, ogg.stat().st_size))
        print(f"{stem:24s} {total:5.1f}s  mp3 {mp3.stat().st_size:>7d} B  ogg {ogg.stat().st_size:>7d} B")
    for path in work.glob("*.wav"):
        path.unlink()
    work.rmdir()
    print(f"\n{len(rows)} sounds written to {OUT_DIR}")


if __name__ == "__main__":
    sys.exit(main())

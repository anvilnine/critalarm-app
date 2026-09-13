# Bundled alarm sounds

Eight sounds ship with the app. Each one is here twice: `.mp3` for iOS and
`.ogg` for Android.

## Where they came from

All eight are written by Anvil Nine from scratch. None of them samples, mixes
or derives from anyone else's recording, so there is no third-party licence to
carry and no attribution anyone is owed.

They are released under **CC0 1.0 Universal** (public domain dedication):
<https://creativecommons.org/publicdomain/zero/1.0/>

| File | Name | Length | Source |
|---|---|---|---|
| `classic_siren` | Classic siren | 16.0 s | Self-generated, CC0 |
| `pulsing_klaxon` | Pulsing klaxon | 12.0 s | Self-generated, CC0 |
| `marimba_escalator` | Marimba escalator | 15.6 s | Self-generated, CC0 |
| `soft_to_loud_ramp` | Soft to loud ramp | 15.0 s | Self-generated, CC0 |
| `pager_beep` | Pager beep | 14.0 s | Self-generated, CC0 |
| `submarine_dive_horn` | Submarine dive horn | 15.0 s | Self-generated, CC0 |
| `rising_synth_sweep` | Rising synth sweep | 15.0 s | Self-generated, CC0 |
| `plain_loud_beep` | Plain loud beep | 12.0 s | Self-generated, CC0 |

## Rebuilding them

```
python3 tools/sounds/generate.py
```

The script needs `ffmpeg` on PATH and nothing else. It writes the waveform
sample by sample with the Python standard library, then encodes each one twice.
Run it again and you get the same files.

## Two rules the script enforces

1. **Every sound is 10 to 20 seconds long.** The script fails the build if one
   is not.
2. **Every sound starts and ends with at least 60 ms of silence.** mp3 encoders
   add a little padding at both ends of a file. A sound that starts mid-tone
   clicks each time the loop wraps. Silence at the seam hides the padding, so
   these loop cleanly on both platforms.

## Why the ogg files hold Opus

The `.ogg` files are Ogg containers holding Opus, not Vorbis. Homebrew's ffmpeg
ships without `libvorbis`, and ffmpeg's own Vorbis encoder smears short beeps.
Android has decoded Ogg/Opus since API 21 and this app's floor is API 28, so
nothing is lost.

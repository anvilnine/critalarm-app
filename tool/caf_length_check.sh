#!/bin/sh
# Proves the iOS caf conversion keeps the exact decoded length, on this Mac.
#
# Compiles ios/Runner/GaplessCaf.swift with a small checker, converts the
# bundled mp3s and a set of mp3, m4a, wav and aiff fixtures, and compares
# each caf against ffmpeg's decode of the same file. ffmpeg honours the LAME
# tag and the m4a edit list, so its sample count is the true length.
#
# Needs swiftc (Xcode or the command line tools), ffmpeg and afconvert.
# macOS and iOS share the AVFoundation decoders, but this runs on macOS.
set -eu
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

swiftc -O ios/Runner/GaplessCaf.swift tool/caf_length_check/main.swift -o "$work/check"

# Fixtures from a PCM master: the bundled siren, and the 750 Hz test loop
# (64 samples a period, 96000 frames at 48 kHz).
ffmpeg -v error -i assets/sounds/classic_siren.mp3 -ac 1 "$work/siren44.wav"
ffmpeg -v error -i "$work/siren44.wav" -ar 48000 "$work/siren48.wav"
ffmpeg -v error -f lavfi -i "sine=frequency=750:sample_rate=48000" -t 2 -ac 1 "$work/sine750.wav"
afconvert -f m4af -d aac "$work/siren44.wav" "$work/siren44_afconvert.m4a"
afconvert -f m4af -d aac "$work/siren48.wav" "$work/siren48_afconvert.m4a"
afconvert -f m4af -d aac "$work/sine750.wav" "$work/sine750_afconvert.m4a"
ffmpeg -v error -i "$work/siren44.wav" -c:a aac -b:a 128k "$work/siren44_ffmpeg.m4a"
ffmpeg -v error -i "$work/siren48.wav" -c:a libmp3lame -b:a 192k "$work/siren48_lame.mp3"
ffmpeg -v error -i "$work/sine750.wav" -c:a libmp3lame -b:a 192k "$work/sine750_lame.mp3"
afconvert -f AIFF -d BEI16 "$work/siren44.wav" "$work/siren44.aiff"
# An mp3 with cover art that pushes the first frame past 256 KB.
ffmpeg -v error -f lavfi -i "color=s=700x700" -vf "noise=alls=100:allf=t" -frames:v 1 "$work/cover.png"
ffmpeg -v error -i assets/sounds/classic_siren.mp3 -i "$work/cover.png" -map 0 -map 1 -c copy \
  -id3v2_version 3 -metadata:s:v comment="Cover (front)" "$work/siren44_cover_lame.mp3"

set --
for source in assets/sounds/*.mp3 "$work"/*.m4a "$work"/*_lame.mp3 "$work/siren48.wav" "$work/siren44.aiff"; do
  expected="$work/$(basename "$source").f32"
  ffmpeg -v error -i "$source" -ac 1 -f f32le "$expected"
  set -- "$@" "$source" "$expected"
done
mkdir -p "$work/out"
"$work/check" "$work/out" "$@"

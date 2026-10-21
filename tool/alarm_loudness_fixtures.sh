#!/bin/sh
# Writes the loudness of every bundled Android alarm sound, one RMS value per
# 20 ms window, the loudest window at 1, for the vibration pattern test
# (HapticPatternTest). Run it again after adding or changing a sound in
# assets/sounds.
#
# ffmpeg does the decode and the RMS, so the test checks the app's pattern
# against loudness worked out by something other than the app.
#
# Needs ffmpeg.
set -eu
cd "$(dirname "$0")/.."
out=android/app/src/test/resources/alarm_loudness
mkdir -p "$out"
rm -f "$out"/*.txt

for sound in assets/sounds/*.ogg; do
  id=$(basename "$sound" .ogg)
  # 960 samples at 48 kHz is 20 ms. The last window may be shorter.
  ffmpeg -v error -i "$sound" \
    -af "aresample=48000,aformat=channel_layouts=mono,asetnsamples=n=960:p=0,astats=metadata=1:reset=1,ametadata=print:key=lavfi.astats.Overall.RMS_level:file=-" \
    -f null - |
    awk -F= '/RMS_level/ { v = ($2 == "-inf") ? 0 : exp($2 / 20 * log(10)); a[n++] = v; if (v > m) m = v }
      END { for (i = 0; i < n; i++) printf "%.4f\n", (m > 0 ? a[i] / m : 0) }' > "$out/$id.txt"
  echo "$id $(wc -l < "$out/$id.txt" | tr -d ' ') windows"
done

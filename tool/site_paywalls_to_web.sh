#!/bin/sh
# Turns the frames from tool/capture_site_paywalls.sh into web assets.
#
#   sh tool/site_paywalls_to_web.sh <out-dir>
#   sh tool/site_paywalls_to_web.sh ../critalarm-site/public/pricing/paywall
#
# Per id, in <out-dir>: <id>.mp4 (H.264), <id>.webm (VP9), <id>.webp (poster,
# the first frame) and <id>.still.webp (660 wide, the settled frame). Clips are
# 540 wide, 30 fps, no sound, trimmed half a second after the last change.
# Env: SITE_OUT (frames folder, default build/site_paywalls), SITE_ONLY
# (comma list of ids). Needs ffmpeg and cwebp.
set -eu
cd "$(dirname "$0")/.."
: "${SITE_OUT:=$PWD/build/site_paywalls}"
out="${1:?usage: sh tool/site_paywalls_to_web.sh <out-dir>}"
mkdir -p "$out"
command -v ffmpeg >/dev/null || { echo "ffmpeg is not on the PATH" >&2; exit 1; }
command -v cwebp >/dev/null || { echo "cwebp is not on the PATH" >&2; exit 1; }
for dir in "$SITE_OUT"/*/; do
  id="$(basename "$dir")"
  if [ -n "${SITE_ONLY:-}" ]; then
    case ",$SITE_ONLY," in *",$id,"*) ;; *) continue ;; esac
  fi
  total="$(ls "$dir/frames" | wc -l | tr -d ' ')"
  last="$(sed -n 's/.*"last_change_frame":\([0-9]*\).*/\1/p' "$dir/meta.json")"
  fps="$(sed -n 's/.*"fps":\([0-9]*\).*/\1/p' "$dir/meta.json")"
  keep=$((last + fps / 2)); [ "$keep" -gt "$total" ] && keep="$total"
  src="-framerate $fps -i $dir/frames/%04d.png -frames:v $keep -vf scale=540:-2 -an"
  # shellcheck disable=SC2086
  ffmpeg -y -loglevel error $src -c:v libx264 -crf 28 -pix_fmt yuv420p -movflags +faststart "$out/$id.mp4"
  # shellcheck disable=SC2086
  ffmpeg -y -loglevel error $src -c:v libvpx-vp9 -crf 36 -b:v 0 -pix_fmt yuv420p "$out/$id.webm"
  ffmpeg -y -loglevel error -i "$dir/frames/0000.png" -vf scale=540:-2 /tmp/_sp_poster.png
  cwebp -quiet -q 78 /tmp/_sp_poster.png -o "$out/$id.webp"
  ffmpeg -y -loglevel error -i "$dir/still.png" -vf scale=660:-2 /tmp/_sp_still.png
  cwebp -quiet -q 82 /tmp/_sp_still.png -o "$out/$id.still.webp"
  echo "$id: $keep frames"
done
rm -f /tmp/_sp_poster.png /tmp/_sp_still.png

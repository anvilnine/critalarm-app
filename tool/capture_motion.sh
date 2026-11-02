#!/bin/sh
# Records the motion clips of the real app for videos, off the device, in
# MOCK mode. Writes into the content pipeline's ui-motion folder, next to
# the main checkout of this repo, or into MOTION_OUT.
#
#   sh tool/capture_motion.sh                              every clip
#   MOTION_ONLY=alarm.arrive sh tool/capture_motion.sh     some clips
#   MOTION_LIST=1 sh tool/capture_motion.sh                list the ids
#   MOTION_THEME=dark MOTION_OUT=/abs/path sh tool/capture_motion.sh
#                                                          dark, somewhere else
#   MOTION_W=886 MOTION_H=1920 MOTION_RATIO=2.3627 MOTION_OUT=/abs/path \
#     sh tool/capture_motion.sh                            App Store preview size
#
# MOTION_W and MOTION_H are the frame in pixels (1080 x 1920 when unset) and
# MOTION_RATIO the pixels per point (2.625 when unset). Drags in the clips
# are written in points, so they land on a narrower phone too.
#
# Clips are recorded in the app's light theme. Videos show the app in light
# mode, so the library holds light clips only. Dark is there for a check by
# hand: it needs MOTION_THEME=dark and a MOTION_OUT of its own, and never
# writes into the library.
#
# Needs ffmpeg on the PATH, and `make gen` and `make l10n` run once.
set -eu
cd "$(dirname "$0")/.."
common="$(git rev-parse --path-format=absolute --git-common-dir)"
: "${MOTION_THEME:=light}"
case "$MOTION_THEME" in
  light) ;;
  dark)
    if [ -z "${MOTION_OUT:-}" ]; then
      echo "MOTION_THEME=dark needs MOTION_OUT: the ui-motion library is light only" >&2
      exit 1
    fi
    ;;
  *) echo "MOTION_THEME is light or dark, not '$MOTION_THEME'" >&2; exit 1 ;;
esac
: "${MOTION_OUT:=$(cd "$common/../.." && pwd)/critalarm-content-pipeline/ui-motion}"
mkdir -p "$MOTION_OUT"
command -v ffmpeg >/dev/null || { echo "ffmpeg is not on the PATH" >&2; exit 1; }
GIT_SHA="$(git rev-parse --short HEAD)"
GIT_DIRTY="$(test -z "$(git status --porcelain -- lib assets pubspec.yaml)" && echo false || echo true)"
export MOTION_OUT MOTION_THEME GIT_SHA GIT_DIRTY
export MOTION_FEATURES="${MOTION_FEATURES:-$(cd "$common/../.." && pwd)/critalarm-planning/features.md}"
# SKIP_PAYWALL turns the developer plan switches on, which is how a clip
# holds Pro to draw a paid look. MOCK is switched on inside the tool.
exec fvm flutter test tool/capture_motion.dart \
  --dart-define=SKIP_PAYWALL=true --reporter=expanded

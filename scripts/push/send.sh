#!/usr/bin/env bash
# Delivers one of the APNs fixtures in this folder to a booted simulator.
#
#   scripts/push/send.sh p5              # one payload
#   scripts/push/send.sh all             # every payload, two seconds apart
#   scripts/push/send.sh --device <UDID> content-none
#
# The extension resolves content-none.apns against the mock server. Start it
# first, in another terminal:
#
#   fvm dart run scripts/push/mock_server.dart
#
# Stop that server and send content-none.apns again to watch the fallback.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
device="booted"
bundle="app.critalarm"

while [ $# -gt 0 ]; do
  case "$1" in
    --device) device="$2"; shift 2 ;;
    --bundle) bundle="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) break ;;
  esac
done

if [ $# -lt 1 ]; then
  echo "usage: send.sh [--device UDID] [--bundle ID] <p3|p4|p5|content-none|all>" >&2
  exit 2
fi

send_one() {
  payload="$here/$1.apns"
  if [ ! -f "$payload" ]; then
    echo "no such payload: $payload" >&2
    exit 1
  fi
  echo "--> $1.apns"
  xcrun simctl push "$device" "$bundle" "$payload"
}

if [ "$1" = "all" ]; then
  for name in p3 p4 p5 content-none; do
    send_one "$name"
    sleep 2
  done
else
  for name in "$@"; do send_one "$name"; done
fi

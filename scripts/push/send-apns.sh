#!/usr/bin/env bash
# Sends one of the fixtures in this folder to a real device through APNs.
#
#   scripts/push/send-apns.sh p5
#   scripts/push/send-apns.sh all
#   scripts/push/send-apns.sh --production content-none
#   scripts/push/send-apns.sh alarm          # the trigger, Part A
#   scripts/push/send-apns.sh la-start       # the acknowledge card, Part B
#
# send.sh is the simulator path. This one is the real thing: it signs a JWT
# with the team's APNs auth key and posts to Apple, which is the only way to
# see a Notification Service Extension run (api.md §5.1).
#
# Settings live in scripts/push/apns.env, which is git-ignored. Copy
# apns.env.example and fill it in. The .p8 stays outside the repo.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
host="https://api.sandbox.push.apple.com"

while [ $# -gt 0 ]; do
  case "$1" in
    --sandbox) host="https://api.sandbox.push.apple.com"; shift ;;
    --production) host="https://api.push.apple.com"; shift ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) break ;;
  esac
done

if [ $# -lt 1 ]; then
  echo "usage: send-apns.sh [--sandbox|--production] <p3|p4|p5|alarm|content-none|la-start|la-update|la-end|all>" >&2
  exit 2
fi

config="$here/apns.env"
if [ ! -f "$config" ]; then
  echo "missing $config. Copy apns.env.example and fill it in." >&2
  exit 1
fi
# shellcheck disable=SC1090
. "$config"

for required in APNS_KEY_PATH APNS_KEY_ID APNS_TEAM_ID APNS_BUNDLE_ID APNS_DEVICE_TOKEN; do
  if [ -z "${!required:-}" ]; then
    echo "$required is not set in $config" >&2
    exit 1
  fi
done
if [ ! -f "$APNS_KEY_PATH" ]; then
  echo "no auth key at $APNS_KEY_PATH" >&2
  exit 1
fi

# Critical Alerts is a separate Apple entitlement. Without it a payload asking
# for the critical level is rejected, so the level drops to time-sensitive and
# the critical sound goes back to the default. Set this to 1 once the
# entitlement is on the App ID.
critical_alerts="${APNS_CRITICAL_ALERTS:-0}"

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

# ES256, which is the only algorithm APNs accepts. openssl signs in DER;
# a JWT wants the raw r and s, each padded to 32 bytes.
jwt() {
  local header claims signing_input der r_len r s_len s sig
  header=$(printf '{"alg":"ES256","kid":"%s"}' "$APNS_KEY_ID" | b64url)
  claims=$(printf '{"iss":"%s","iat":%s}' "$APNS_TEAM_ID" "$(date +%s)" | b64url)
  signing_input="$header.$claims"

  der=$(printf '%s' "$signing_input" \
    | openssl dgst -sha256 -sign "$APNS_KEY_PATH" \
    | xxd -p | tr -d '\n')

  # 30 <total> 02 <rlen> <r> 02 <slen> <s>
  r_len=$((16#${der:6:2}))
  r=${der:8:$((r_len * 2))}
  s_len=$((16#${der:$((8 + r_len * 2 + 2)):2}))
  s=${der:$((8 + r_len * 2 + 4)):$((s_len * 2))}

  # Drop the sign byte DER adds, then left-pad each half back to 32 bytes.
  r=$(printf '%064s' "${r#00}" | tr ' ' '0')
  s=$(printf '%064s' "${s#00}" | tr ' ' '0')

  sig=$(printf '%s%s' "$r" "$s" | xxd -r -p | b64url)
  printf '%s.%s' "$signing_input" "$sig"
}

send_one() {
  local name="$1" source payload incident collapse expiry body status
  source="$here/$name.apns"
  if [ ! -f "$source" ]; then
    echo "no such payload: $source" >&2
    exit 1
  fi

  # The simulator fixtures point at loopback and ask for the critical level.
  # A real handset needs a reachable host, and without the entitlement the
  # critical level has to come down.
  payload=$(jq -c \
    --arg server "${APNS_SERVER:-}" \
    --argjson critical "$critical_alerts" '
      del(.["Simulator Target Bundle"])
      | if $server != "" and has("server") then .server = $server else . end
      | if $critical == 0 and .aps["interruption-level"] == "critical"
        then .aps["interruption-level"] = "time-sensitive"
             | .aps.sound = "default"
        else . end
    ' "$source")

  incident=$(jq -r '.incident_id // empty' <<<"$payload")
  expiry=$(( $(date +%s) + ${APNS_EXPIRATION_S:-1800} ))

  # A Live Activity push is a different push type on a different topic, and it
  # goes to a Live Activity token rather than the device token. `start` uses the
  # push-to-start token (one per install); `update` and `end` use the token that
  # belongs to the one card.
  push_type="alert"
  apns_topic="$APNS_BUNDLE_ID"
  target="$APNS_DEVICE_TOKEN"
  case "$name" in
    la-*)
      push_type="liveactivity"
      apns_topic="$APNS_BUNDLE_ID.push-type.liveactivity"
      if [ "$name" = "la-start" ]; then
        target="${APNS_LA_START_TOKEN:-}"
        if [ -z "$target" ]; then
          echo "    APNS_LA_START_TOKEN is not set in $config" >&2
          return 0
        fi
      else
        target="${APNS_LA_UPDATE_TOKEN:-}"
        if [ -z "$target" ]; then
          echo "    APNS_LA_UPDATE_TOKEN is not set in $config" >&2
          return 0
        fi
      fi
      # The timestamp has to be now, or the system drops the push as stale.
      payload=$(jq -c --argjson now "$(date +%s)" '.aps.timestamp = $now' <<<"$payload")
      ;;
  esac

  # macOS ships bash 3.2, where an empty array under `set -u` is an error, so
  # the expansion below guards for it.
  collapse=()
  if [ -n "$incident" ]; then collapse=(-H "apns-collapse-id: $incident"); fi

  echo "--> $name.apns  type=$push_type  level=$(jq -r '.aps["interruption-level"] // "-"' <<<"$payload")"

  body=$(curl -sS --http2 -X POST \
    -H "authorization: bearer $(jwt)" \
    -H "apns-push-type: $push_type" \
    -H "apns-priority: 10" \
    -H "apns-topic: $apns_topic" \
    -H "apns-expiration: $expiry" \
    ${collapse[@]+"${collapse[@]}"} \
    -w '\n%{http_code}' \
    -d "$payload" \
    "$host/3/device/$target")

  status=$(tail -n1 <<<"$body")
  if [ "$status" = "200" ]; then
    echo "    accepted"
  else
    echo "    APNs said $status: $(sed '$d' <<<"$body")" >&2
  fi
}

if [ "$1" = "all" ]; then
  for name in p3 p4 p5 alarm content-none; do
    send_one "$name"
    sleep 2
  done
else
  for name in "$@"; do send_one "$name"; done
fi

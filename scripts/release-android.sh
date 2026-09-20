#!/usr/bin/env bash
#
# Build the Android app bundle and send it to Google Play in one command.
#
# Same shape as release-ios.sh: gates, build, validate, upload. The upload
# itself is scripts/play_upload.py, which talks to the Play Developer API with
# nothing but the Python standard library and openssl.
#
#   ./scripts/release-android.sh              build and push to internal testing
#   ./scripts/release-android.sh --bump       same, after bumping the build number
#   ./scripts/release-android.sh --build-only just build the aab
#   ./scripts/release-android.sh --dry-run    do everything except commit
#   ./scripts/release-android.sh --track closed
#   ./scripts/release-android.sh --track production --rollout 0.1
#
# WHAT YOU NEED ONCE
#
# A service account that may publish, all the way to production. The RevenueCat
# service account already in secrets/ must not be given this power: it is held
# by a third party, and publish rights would let them ship the app.
#
# Two different consoles, and mixing them up is the usual stumble. Google Cloud
# creates the account and holds the key. Play Console decides what it may do.
# The permissions below are PLAY CONSOLE permissions. They will never appear in
# the Google Cloud role picker, however you spell them.
#
# In Google Cloud Console:
#
#   1. Project crit-alarm, IAM and Admin, Service Accounts
#   2. Create a service account, for example crit-alarm-publisher
#   3. Skip the "grant this service account access to project" step. It needs
#      no Google Cloud role at all. Its whole job is to hold a key.
#   4. Keys, Add key, Create new key, JSON. Save it as
#      secrets/play-publisher.json, and copy the account email while you are
#      there. It looks like
#      crit-alarm-publisher@crit-alarm.iam.gserviceaccount.com
#
# In Play Console:
#
#   5. Users and permissions, Invite new users, paste that email
#   6. Under App permissions add Crit Alarm, then tick these three, and nothing
#      more:
#
#        View app information and download bulk reports (read-only)
#          Reading the app and its edits. Nothing works without it.
#
#        Release apps to testing tracks
#          Internal, closed and open testing.
#
#        Release to production, exclude devices, and use Play App Signing
#          Production. Also what lets Play re-sign the bundle with the app
#          signing key, which every upload needs.
#
#      App permissions on Crit Alarm, not account permissions. There are three
#      apps on this developer account and an account permission hands the key
#      all of them.
#
#   7. Play Console, Setup, API access, and confirm the account is listed. If
#      it is not, the Google Cloud project is not linked to this Play account
#      yet, and that link is a one time thing on the same page.
#
# Not needed, and deliberately not granted:
#   Manage store presence      only if a script should ever edit the listing
#   Manage production releases, exclude devices, and use Play App Signing
#                              the wider variant, covers apps this one should
#                              not touch
#   Manage orders and subscriptions, View financial data
#                              RevenueCat's job, not the publisher's
#
# Google warns that new Play service credentials can take up to 36 hours to
# start working. It is usually minutes. Saving any product description in Play
# Console tends to wake them up straight away.
#
# TRACKS
#
#   internal   up to 100 testers, live in minutes, no review
#   closed     the track that counts toward the 12 testers for 14 days rule
#   open       public beta
#   production the real thing. Locked until the closed testing rule is
#              satisfied, and this script makes you type the word production
#              before it will go there.

set -euo pipefail

cd "$(dirname "$0")/.."
repo_root="$(pwd)"
secrets_dir="$(cd ../secrets 2>/dev/null && pwd || true)"

package="app.critalarm"
track="internal"
bump=0
skip_gates=0
build_only=0
dry_run=0
allow_dirty=0
status="completed"
rollout=""
assume_yes=0

while [ $# -gt 0 ]; do
  case "$1" in
    --bump) bump=1 ;;
    --skip-gates) skip_gates=1 ;;
    --build-only) build_only=1 ;;
    --dry-run) dry_run=1 ;;
    --allow-dirty) allow_dirty=1 ;;
    --draft) status="draft" ;;
    --rollout) shift; rollout="${1:?--rollout needs a fraction, for example 0.1}" ;;
    --yes) assume_yes=1 ;;
    --track) shift; track="${1:?--track needs a value}" ;;
    -h|--help) awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
    *) echo "release-android: unknown option $1" >&2; exit 2 ;;
  esac
  shift
done

say() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
die() { printf '\033[31mrelease-android: %s\033[0m\n' "$1" >&2; exit 1; }

case "$track" in
  internal|closed|open|production) ;;
  *) die "unknown track '$track'. Use internal, closed, open or production." ;;
esac

# Production is the whole world. A typo in --track should not ship the app, so
# it asks, unless somebody said --yes on purpose.
if [ "$track" = "production" ] && [ "$dry_run" -eq 0 ] && [ "$assume_yes" -eq 0 ]; then
  if [ -n "$rollout" ]; then
    printf '\n\033[31mThis will release to PRODUCTION, rolling out to %s of users.\033[0m\n' "$rollout"
  else
    printf '\n\033[31mThis will release to PRODUCTION, to everyone, at once.\033[0m\n'
  fi
  printf 'Type the word production to continue: '
  read -r confirm
  [ "$confirm" = "production" ] || die "stopped."
fi

# ---------------------------------------------------------------- preconditions

command -v fvm >/dev/null || die "fvm is not on PATH."
command -v python3 >/dev/null || die "python3 is not on PATH."
[ -f .env ] || die ".env is missing. Copy .env.example and fill it in."

# Without this the release build dies at :app:processReleaseGoogleServices, and
# the error does not say the file is missing.
[ -f android/app/google-services.json ] || \
  die "android/app/google-services.json is missing. It is kept out of this public repo."

# A release bundle has to be signed with the upload key, or Play refuses it.
[ -e android/key.properties ] || \
  die "android/key.properties is missing. It is a symlink into the secrets folder."

branch="$(git rev-parse --abbrev-ref HEAD)"
if [ "$branch" != "main" ]; then
  echo "release-android: on branch $branch, not main. Continuing anyway."
fi

if [ "$allow_dirty" -eq 0 ]; then
  dirty="$(git status --porcelain | grep -v 'Package.resolved' || true)"
  [ -z "$dirty" ] || die "working tree has uncommitted changes. Commit them, or pass --allow-dirty.
$dirty"
fi

# ------------------------------------------------------------------ build number

version_line="$(grep -E '^version:' pubspec.yaml)"
current="${version_line#version: }"
name="${current%%+*}"
number="${current##*+}"

if [ "$bump" -eq 1 ]; then
  number=$((number + 1))
  # Play refuses a version code it has already seen, and it refuses it after the
  # whole bundle has finished uploading.
  perl -pi -e "s/^version: .*/version: $name+$number/" pubspec.yaml
  say "Build number is now $name+$number"
else
  say "Building $name+$number. Pass --bump if Play already has this version code."
fi

# ------------------------------------------------------------------------- gates

if [ "$skip_gates" -eq 0 ]; then
  say "Running the gates"
  make test
  make analyze
  make check-layers
else
  echo "release-android: skipping gates."
fi

# ------------------------------------------------------------------------- build

say "Building the app bundle"
# No SKIP_PAYWALL. That flag fakes a subscription and hides the paywall, which
# is the screen a reviewer looks hardest at.
fvm flutter build appbundle --release

aab="build/app/outputs/bundle/release/app-release.aab"
[ -f "$aab" ] || die "no bundle at $aab. The build printed why."
say "Built $(basename "$aab") ($(du -h "$aab" | cut -f1))"

if [ "$build_only" -eq 1 ]; then
  echo "release-android: --build-only, stopping here."
  echo "  $repo_root/$aab"
  exit 0
fi

# ------------------------------------------------------------------------ upload

[ -n "$secrets_dir" ] || die "cannot find the secrets directory next to this repo."

key_file="$secrets_dir/play-publisher.json"
[ -f "$key_file" ] || die "missing $key_file.
  See the header of this script for how to make one. The RevenueCat service
  account is not it and must not be used."

extra=""
[ "$dry_run" -eq 1 ] && extra="--validate-only"
[ -n "$rollout" ] && extra="$extra --rollout $rollout"

# shellcheck disable=SC2086
python3 scripts/play_upload.py \
  --aab "$aab" \
  --package "$package" \
  --key "$key_file" \
  --track "$track" \
  --status "$status" \
  $extra

if [ "$dry_run" -eq 0 ]; then
  say "Uploaded $name+$number to the $track track"
fi

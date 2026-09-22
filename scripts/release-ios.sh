#!/usr/bin/env bash
#
# Build the iOS app and send it to App Store Connect in one command.
#
# Why this exists: the upload used to mean opening Xcode Organizer or
# Transporter, picking the right archive by eye, and typing an Apple ID
# password past a two factor prompt. That is slow, and it is the step nobody
# wants to do twice in an evening.
#
# Auth is an App Store Connect API key, never a password. No two factor prompt,
# nothing interactive, and the same call works from a laptop or from CI.
#
#   ./scripts/release-ios.sh              build, validate and upload
#   ./scripts/release-ios.sh --bump       same, after bumping the build number
#   ./scripts/release-ios.sh --build-only just build the ipa
#   ./scripts/release-ios.sh --dry-run    build and validate, never upload
#
# WHAT YOU NEED ONCE
#
# An App Store Connect API key with the App Manager role. The three Apple keys
# already in secrets/ (the push key, the sign-in key and the subscription key)
# cannot do this job: none of them uploads a build. Their ids are not written
# in this public repo. They live in the .p8 file names inside secrets/, a folder
# next to this checkout that git never sees, and the upload key id comes from
# the env file below.
#
#   1. App Store Connect, Users and Access, Integrations, App Store Connect API
#   2. Generate a key with the App Manager role
#   3. Download the .p8 once. Apple never shows it again.
#   4. Put it in secrets/ named exactly AuthKey_<KEYID>.p8
#   5. Write secrets/appstoreconnect-api.env:
#
#        APP_STORE_CONNECT_KEY_ID=ABCD123456
#        APP_STORE_CONNECT_ISSUER_ID=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
#
# The issuer id is on the same App Store Connect page, above the key list. It
# is the same for every key on the account.

set -euo pipefail

cd "$(dirname "$0")/.."
repo_root="$(pwd)"
secrets_dir="$(cd ../secrets 2>/dev/null && pwd || true)"

bump=0
skip_gates=0
build_only=0
dry_run=0
allow_dirty=0

while [ $# -gt 0 ]; do
  case "$1" in
    --bump) bump=1 ;;
    --skip-gates) skip_gates=1 ;;
    --build-only) build_only=1 ;;
    --dry-run) dry_run=1 ;;
    --allow-dirty) allow_dirty=1 ;;
    -h|--help) awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
    *) echo "release-ios: unknown option $1" >&2; exit 2 ;;
  esac
  shift
done

say() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
die() { printf '\033[31mrelease-ios: %s\033[0m\n' "$1" >&2; exit 1; }

# ---------------------------------------------------------------- preconditions

command -v fvm >/dev/null || die "fvm is not on PATH."
[ -f .env ] || die ".env is missing. Copy .env.example and fill it in."

branch="$(git rev-parse --abbrev-ref HEAD)"
if [ "$branch" != "main" ]; then
  echo "release-ios: on branch $branch, not main. Continuing anyway."
fi

if [ "$allow_dirty" -eq 0 ]; then
  # Package.resolved drifts on its own every time Xcode resolves packages, and
  # STATUS.md has said to leave it alone for a while. It is not a reason to
  # refuse a release.
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
  # Keep the marketing version, move only the build number. Apple rejects a
  # build number it has seen before for this version, and that rejection lands
  # after the whole upload has finished.
  perl -pi -e "s/^version: .*/version: $name+$number/" pubspec.yaml
  say "Build number is now $name+$number"
else
  say "Building $name+$number. Pass --bump if Apple already has this build number."
fi

# ------------------------------------------------------------------------- gates

if [ "$skip_gates" -eq 0 ]; then
  say "Running the gates"
  make test
  make analyze
  make check-layers
else
  echo "release-ios: skipping gates."
fi

# ------------------------------------------------------------------------- build

say "Generating Google.xcconfig"
./scripts/gen-google-xcconfig.sh

say "Building the ipa"
# No SKIP_PAYWALL here on purpose. That flag fakes a Pro subscription and hides
# the paywall, which is the one screen App Review looks hardest at.
fvm flutter build ipa --release

ipa="$(ls -t build/ios/ipa/*.ipa 2>/dev/null | head -n 1 || true)"
[ -n "$ipa" ] || die "no .ipa under build/ios/ipa. The build printed why."
say "Built $(basename "$ipa") ($(du -h "$ipa" | cut -f1))"

if [ "$build_only" -eq 1 ]; then
  echo "release-ios: --build-only, stopping here."
  echo "  $repo_root/$ipa"
  exit 0
fi

# -------------------------------------------------------------------------- auth

[ -n "$secrets_dir" ] || die "cannot find the secrets directory next to this repo."

env_file="$secrets_dir/appstoreconnect-api.env"
[ -f "$env_file" ] || die "missing $env_file. See the header of this script for what goes in it."

# shellcheck disable=SC1090
. "$env_file"

: "${APP_STORE_CONNECT_KEY_ID:?APP_STORE_CONNECT_KEY_ID is not set in $env_file}"
: "${APP_STORE_CONNECT_ISSUER_ID:?APP_STORE_CONNECT_ISSUER_ID is not set in $env_file}"

key_file="$secrets_dir/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
[ -f "$key_file" ] || die "missing $key_file.
  altool finds the key by name, so the file has to be called
  AuthKey_<KEYID>.p8 and sit in the secrets directory."

# altool looks for the .p8 in a few fixed places. This points it at secrets/ so
# the key never has to be copied into the home directory or into this repo.
export API_PRIVATE_KEYS_DIR="$secrets_dir"

# ---------------------------------------------------------------------- validate

say "Validating with App Store Connect"
# Validation catches the cheap rejections, a missing privacy manifest, a bad
# entitlement, a duplicate build number, before spending minutes on an upload.
xcrun altool --validate-app \
  -f "$ipa" \
  -t ios \
  --apiKey "$APP_STORE_CONNECT_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"

if [ "$dry_run" -eq 1 ]; then
  say "Validated. --dry-run, so nothing was uploaded."
  exit 0
fi

# ------------------------------------------------------------------------ upload

say "Uploading"
xcrun altool --upload-app \
  -f "$ipa" \
  -t ios \
  --apiKey "$APP_STORE_CONNECT_KEY_ID" \
  --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"

say "Uploaded $name+$number"
cat <<'NEXT'
Apple processes the build before it appears. Usually a few minutes, sometimes
longer. You will get an email either way.

Then:
  TestFlight, Internal Testing. Internal testers need no review, so the build
  is installable as soon as processing finishes.

  External testers trigger a one time Beta App Review for the first build of a
  version.

  App Store Connect, Distribution, to submit for full review.
NEXT

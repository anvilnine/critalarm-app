#!/usr/bin/env sh
# Get every git worktree ready to compile, without being asked twice.
#
# A fresh worktree only gets tracked files. In this repo that is not enough to
# build: .dart_tool/ is missing, *.g.dart and *.freezed.dart are git-ignored, and
# lib/gen/locale_keys.g.dart comes from a separate generator. So a new worktree
# does not compile until pub get, `make gen` and `make l10n` have all run.
#
# This scans every worktree instead of reading the command that triggered it, so
# it also repairs worktrees made before the hook existed. Safe to run on every
# tool call: a worktree with a .worktree-ready marker is skipped.
#
# The slow part runs detached, because a hook has seconds and codegen has
# minutes. Progress lands in <worktree>/.worktree-prep.log.
set -u

common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
main=$(dirname "$common")

started=""
while read -r wt; do
  [ "$wt" = "$main" ] && continue
  [ -d "$wt" ] || continue
  # Only worktrees this repo's tooling owns, i.e. under <main>/worktrees/.
  # Worktrees somebody parked elsewhere are left alone.
  case "$wt" in "$main/worktrees/"*) ;; *) continue ;; esac
  # Marker means finished. Lock means a prep is already running.
  [ -f "$wt/.worktree-ready" ] && continue
  [ -d "$wt/.worktree-prep.lock" ] && continue
  mkdir "$wt/.worktree-prep.lock" 2>/dev/null || continue

  # Carry over the files git cannot: all git-ignored, all machine-local.
  # google-services.json and GoogleService-Info.plist are kept out of this
  # public repo on purpose, and without them an Android release build fails at
  # :app:processReleaseGoogleServices. Google.xcconfig is generated, not
  # tracked, and is regenerated below from the copied .env anyway; it is in this
  # list only so a worktree made without a .env still inherits a working one.
  for f in .env .env.local .claude/settings.local.json \
           android/app/google-services.json \
           android/key.properties \
           ios/Runner/GoogleService-Info.plist \
           ios/Flutter/Google.xcconfig; do
    if [ -f "$main/$f" ] && [ ! -e "$wt/$f" ]; then
      mkdir -p "$(dirname "$wt/$f")"
      cp "$main/$f" "$wt/$f"
    fi
  done

  nohup sh -c '
    cd "$1" || exit 1
    {
      echo "prep started $(date -u +%Y-%m-%dT%H:%M:%SZ)"
      # iOS only. Info.plist reads GOOGLE_REVERSED_CLIENT_ID from this file to
      # register the URL scheme Google Sign-In needs, and it is gitignored, so a
      # fresh worktree has none. Regenerated from the .env copied above rather
      # than copied, so it always matches that worktree'"'"'s .env.
      #
      # Not fatal: Dart work does not need it, and every Makefile target that
      # builds iOS depends on google-xcconfig, so an iOS build regenerates it
      # and fails loudly there if .env is short a value.
      if ! ./scripts/gen-google-xcconfig.sh; then
        echo "WARNING: gen-google-xcconfig failed. iOS Google sign-in will not work in this worktree until .env has GOOGLE_IOS_CLIENT_ID."
      fi
      fvm flutter pub get && make gen && make l10n && touch .worktree-ready
      echo "prep finished $(date -u +%Y-%m-%dT%H:%M:%SZ) exit=$?"
    } >> .worktree-prep.log 2>> .worktree-prep.err
    rmdir .worktree-prep.lock 2>/dev/null
  ' _ "$wt" > /dev/null 2> /dev/null &

  started="$started $(basename "$wt")"
done << EOF
$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10)}')
EOF

if [ -n "$started" ]; then
  printf '{"systemMessage": "Preparing worktree (pub get, gen, l10n) in background:%s. Watch <worktree>/.worktree-prep.log; .worktree-ready appears when it can compile."}\n' "$started"
fi
exit 0

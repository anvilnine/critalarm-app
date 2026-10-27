# Shared by release-ios.sh and release-android.sh. Sourced, never run.
#
# The caller has already set: say, die, name, number, and has cd'd to the repo
# root. Everything here is about one thing: a crash from a store build has to
# be readable months later.
#
# A release build hides Dart names (--obfuscate), so its stack traces are
# unreadable without the symbol files made by that exact build. Three things
# happen to those files:
#
#   1. The build writes them under build/, where the next build overwrites them.
#   2. keep_symbols copies them to symbols/<version>/<platform>/ in the main
#      checkout. Git ignores that folder. Back it up with the secrets folder.
#   3. upload_*_symbols sends them to Crashlytics, before the store upload, so
#      no build reaches a tester without them.
#
# Read a trace by hand with:
#   fvm flutter symbolize -i trace.txt \
#     -d symbols/<version>/android/dart/app.android-arm64.symbols

# symbols/ sits in the main checkout even when the script runs from a
# worktree, so a worktree that gets removed does not take a release's symbols
# with it.
main_checkout="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
symbols_root="${SYMBOLS_ROOT:-$main_checkout/symbols}"

# Pinned so a release does not pick up a new major version of the Firebase
# CLI on its own. npx downloads it on first use.
firebase_tools="firebase-tools@15.33.0"

# Where flutter writes the Dart symbols of this build.
dart_symbols_dir() { echo "build/symbols/$1"; }

# symbols/1.0.0+12/android
kept_symbols_dir() { echo "$symbols_root/$name+$number/$1"; }

# The same checks CI runs, minus the format check. A release must not be the
# first place a check fails.
run_gates() {
  make test
  make analyze
  make check-layers
  make check-l10n
  make check-access
}

# True when a changelog has a line waiting under Unreleased.
has_unreleased() {
  awk '/^## /{inside = ($2 == "Unreleased"); next} inside && /^- /{found = 1} END{exit !found}' "$1"
}

# Move the build number and commit it, so the build is made from a commit and
# the tag has something to point at. When a changelog has entries waiting they
# are released under the new version in the same commit.
bump_and_commit() {
  number=$((number + 1))
  perl -pi -e "s/^version: .*/version: $name+$number/" pubspec.yaml
  if has_unreleased CHANGELOG.md || has_unreleased dev-notes/CHANGELOG.md; then
    sh tool/changelog.sh release
    git add pubspec.yaml CHANGELOG.md dev-notes/CHANGELOG.md dev-notes/pubspec.yaml
    git commit -q -m "Release version $name+$number"
  else
    # dev-notes/pubspec.yaml only exists so cider can read a version. Keep it
    # in step here, since no changelog release ran to do it.
    perl -pi -e "s/^version: .*/version: $name+$number/" dev-notes/pubspec.yaml
    git add pubspec.yaml dev-notes/pubspec.yaml
    git commit -q -m "Bump build number to $number"
  fi
  say "Build number is now $name+$number, committed as $(git rev-parse --short HEAD)"
}

# One line per finished build: which version it is and which commit made it.
# --upload-only reads it back, so it can never send an older file that happens
# to be lying under build/.
stamp_file() { echo "build/release-$1.stamp"; }

write_stamp() {
  echo "$name+$number $(git rev-parse HEAD)" > "$(stamp_file "$1")"
}

check_stamp() {
  stamp="$(stamp_file "$1")"
  [ -f "$stamp" ] || die "no $stamp. The file under build/ was not made by this script, so nothing says which version it is. Build again."
  built="$(cut -d' ' -f1 "$stamp")"
  [ "$built" = "$name+$number" ] || die "the build under build/ is $built and pubspec.yaml says $name+$number. Build again."
}

# Tag the commit a store now holds. Local only: push it with the branch.
tag_release() {
  tag="v$name+$number"
  if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    echo "release: tag $tag already exists."
    return
  fi
  commit="$(cut -d' ' -f2 "$(stamp_file "$1")")"
  git tag "$tag" "$commit"
  echo "release: tagged $tag at $(git rev-parse --short "$commit"). Push it with: git push origin $tag"
}

# Copy this build's symbol files out of build/.
keep_symbols() {
  platform="$1"
  dart="$(dart_symbols_dir "$platform")"
  kept="$(kept_symbols_dir "$platform")"

  ls "$dart"/*.symbols >/dev/null 2>&1 || die "no Dart symbols under $dart. The build did not run with --split-debug-info."

  rm -rf "$kept"
  mkdir -p "$kept"
  cp -R "$dart" "$kept/dart"

  if [ "$platform" = "android" ]; then
    # R8's map for the Kotlin and Java side. 100 MB of text, a tenth zipped.
    mapping="build/app/outputs/mapping/release/mapping.txt"
    [ -f "$mapping" ] || die "no R8 mapping at $mapping."
    gzip -c "$mapping" > "$kept/mapping.txt.gz"
    # The engine's own symbols ride inside the bundle (BUNDLE-METADATA), and
    # so does this mapping, so Play Console has both without a second upload.
  else
    dsyms="build/ios/archive/Runner.xcarchive/dSYMs"
    [ -d "$dsyms" ] || die "no dSYMs under $dsyms. The archive did not keep debug symbols."
    (cd "$dsyms" && zip -qry "$kept/dSYMs.zip" .)
  fi

  {
    echo "version: $name+$number"
    echo "commit: $(git rev-parse HEAD)"
    echo "built: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "flutter: $(tr -d '{}" \n' < .fvmrc | cut -d: -f2)"
  } > "$kept/BUILD.txt"

  say "Kept symbols in $kept ($(du -sh "$kept" | cut -f1))"
}

# The Firebase app id for one platform, out of firebase.json.
firebase_app_id() {
  python3 -c 'import json,sys; print(json.load(open("firebase.json"))["flutter"]["platforms"][sys.argv[1]]["default"]["appId"])' "$1"
}

# Android: the Dart symbols. The Crashlytics Gradle plugin uploads R8's
# mapping during the build, and nothing else uploads these. The command needs
# no sign-in: it sends them the way the Gradle plugin does, by app id.
upload_android_symbols() {
  kept="$(kept_symbols_dir android)"
  [ -d "$kept/dart" ] || die "no kept symbols at $kept/dart. Build again."
  command -v npx >/dev/null || die "npx is not on PATH. The Firebase CLI runs through it."
  command -v java >/dev/null || die "java is not on PATH. The Crashlytics symbol tool needs it."

  say "Uploading Dart symbols to Crashlytics"
  npx -y "$firebase_tools" crashlytics:symbols:upload \
    --app="$(firebase_app_id android)" \
    "$kept/dart"
}

# iOS: every dSYM in the archive, which covers the app, the Dart code
# (App.framework), Flutter and the three extensions. The build phase in the
# Runner target uploads too, but it runs in the middle of the build and
# nothing reports whether it worked. This one fails loudly.
upload_ios_symbols() {
  kept="$(kept_symbols_dir ios)"
  [ -f "$kept/dSYMs.zip" ] || die "no kept symbols at $kept/dSYMs.zip. Build again."
  plist="ios/Runner/GoogleService-Info.plist"
  [ -f "$plist" ] || die "$plist is missing. It is kept out of this public repo."

  tool=""
  for candidate in \
    build/ios/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols \
    ios/Pods/FirebaseCrashlytics/upload-symbols; do
    [ -x "$candidate" ] && tool="$candidate" && break
  done
  [ -n "$tool" ] || die "cannot find Crashlytics upload-symbols. An iOS build puts it under build/ios/SourcePackages."

  unpacked="$(mktemp -d)"
  unzip -q "$kept/dSYMs.zip" -d "$unpacked"
  say "Uploading dSYMs to Crashlytics"
  "$tool" -gsp "$plist" -p ios "$unpacked"
  rm -rf "$unpacked"
}

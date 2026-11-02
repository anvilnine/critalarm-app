# Release builds and symbols

Moved out of AGENTS.md on 2026-10-17, text unchanged. Read before changing this area.

**Release builds and symbols.** `scripts/release-ios.sh` and
`scripts/release-android.sh` are the only way a build reaches a store. Both build
with `--obfuscate --split-debug-info`, so a release hides Dart names and its
stack traces need the symbol files from that exact build. `scripts/release-lib.sh`
holds the steps the two share.

- **Kept:** every build copies its symbols to `symbols/<version>/<platform>/` in
  the main checkout, also when the script runs from a worktree. Git ignores the
  folder. Android gets `dart/` and `mapping.txt.gz`. The bundle itself carries
  the mapping and the engine's symbols for Play Console.
  iOS gets `dart/` and `dSYMs.zip`. `BUILD.txt` names the commit.
- **Sent:** before the store upload the script sends symbols to Crashlytics.
  iOS sends every dSYM in the archive with the SDK's `upload-symbols`. Android
  sends the Dart symbols with `firebase crashlytics:symbols:upload` (through
  `npx`, no sign-in), and the Crashlytics Gradle plugin sends R8's mapping
  during the build. `--symbols-only` does this step alone. `--skip-symbols`
  leaves it out.
- **Bump and tag:** `--bump` runs the gates, then commits the new build number.
  When a changelog has lines under Unreleased it runs `make changelog-release`
  in the same commit. A finished store upload tags the commit `v<version>`. The
  tag is local until pushed.
- **Reusing a build:** `--upload-only` and `--symbols-only` read
  `build/release-<platform>.stamp` and stop when it does not match `pubspec.yaml`.
- **Reading a trace by hand:** `fvm flutter symbolize -i trace.txt -d
  symbols/<version>/android/dart/app.android-arm64.symbols`.
- **Code that breaks under obfuscation:** anything that compares
  `runtimeType.toString()` or a class name to a string. Enum `.name` is safe.
  A `runtimeType` in a log line prints a short mangled name in a release build.
- **Crash reports:** `installCrashHooks` in `lib/core/telemetry/crash_hooks.dart`
  sends errors nothing caught to `TelemetryGate.recordError`. The gate drops
  them while the user has crash reporting off. It sends the error's type and
  stack trace and never its message, because a message can quote a server
  answer. Do not call `FirebaseCrashlytics` anywhere else.
- A dev build (`make run-release`, `make build-quiet-apk`) is not obfuscated and
  sends no symbols.


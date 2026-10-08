.PHONY: screens gen regen l10n test run analyze format quality check-layers check-l10n doctor hooks sync-contract run-release run-quiet build-quiet-apk build-release-apk build-release-ios cold-start worktree-new worktree-list worktree-clean log devlog changelog-release release-ios release-ios-dry release-android release-android-dry

# One-shot codegen: freezed, json_serializable, flutter_gen.
# Generated output is git-ignored, so run this after a clone and after pulls.
gen:
	fvm dart run build_runner build

# Codegen from scratch. Use this whenever .env changed.
#
# `make gen` is incremental, and build_runner decides what to redo from its own
# cache. On 2026-09-20 that cache went stale against .env: four new keys were
# filled in and envied still reported "no-op", leaving env.g.dart holding
# `<int>[]` for every one of them. That builds an app with no RevenueCat key and
# no Google client id, which fails at runtime with nothing naming the cause.
#
# env.g.dart is gitignored, so git status will not warn you either. After
# touching .env, run this, not `make gen`.
regen:
	fvm dart run build_runner clean
	fvm dart run build_runner build --delete-conflicting-outputs

# Regenerate type-safe locale keys from assets/translations.
l10n:
	fvm dart run easy_localization:generate -S assets/translations -O lib/gen -o locale_keys.g.dart -f keys

# Refresh docs/api.md and docs/ARCHITECTURE.md from critalarm-server.
sync-contract:
	./scripts/sync-contract.sh

test:
	fvm flutter test

# Marketing screenshots from the real widgets in MOCK mode: store and social
# sizes, light and dark, plus manifest.json. A tool, not a test: it never runs
# in `make test` or CI. Output goes outside this repo, by default into the
# content pipeline checkout next to the main checkout of this repo (found from
# the shared .git, so it works from a worktree too). Override with
# SCREENS_OUT=/abs/path, render a subset with
# SCREENS_ONLY=alarm.ringing,home.calm, and only some sizes with
# SCREENS_DEVICES=social916. TZ is pinned so every clock on a screen reads in
# the same zone.
SCREENS_OUT ?= $(abspath $(dir $(shell git rev-parse --path-format=absolute --git-common-dir))../critalarm-content-pipeline/ui-snapshots)
screens:
	@mkdir -p "$(SCREENS_OUT)"
	TZ=UTC SCREENS_OUT="$(abspath $(SCREENS_OUT))" \
	SCREENS_ONLY="$(SCREENS_ONLY)" \
	SCREENS_DEVICES="$(SCREENS_DEVICES)" \
	GIT_SHA="$$(git rev-parse --short HEAD)" \
	GIT_DIRTY="$$(test -z "$$(git status --porcelain -- lib assets pubspec.yaml)" && echo false || echo true)" \
	fvm flutter test tool/capture_marketing_screens.dart --reporter=compact

# Fill ios/Flutter/Google.xcconfig from .env. Google Sign-In on iOS needs the
# reversed client id registered as a URL scheme in the bundle, and Xcode reads
# it from there. Every target that can build iOS depends on this, because a
# missing value builds an app whose sign-in fails silently.
google-xcconfig:
	./scripts/gen-google-xcconfig.sh

run: google-xcconfig
	fvm flutter run

analyze:
	fvm flutter analyze

format:
	fvm dart format .

# Format + analyze in one go. Run before every commit.
quality: format analyze

# Enforce clean-architecture dependency direction.
check-layers:
	sh tool/check_layers.sh

# Fail on an English string literal passed straight to Text, TextSpan or an
# AppButton label. Mark text that must stay with `// l10n-ok: <reason>`.
check-l10n:
	sh tool/check_l10n.sh

# Install the repo git hooks (pre-commit: format + analyze).
hooks:
	git config core.hooksPath tool/git-hooks
	chmod +x tool/git-hooks/*
	@echo "Git hooks installed (core.hooksPath -> tool/git-hooks)."

# Verifies toolchain, regenerates codegen, analyzes and checks layering and localization.
doctor:
	@test "$$(fvm flutter --version | head -1 | awk '{print $$2}')" = "$$(grep -o '[0-9][0-9.]*' .fvmrc)" \
		|| { echo "FVM version mismatch with .fvmrc"; exit 1; }
	fvm dart run build_runner build
	fvm flutter analyze
	sh tool/check_layers.sh
	sh tool/check_l10n.sh

# Release build for UI work on a device. Skips RevenueCat, so the test API key
# cannot pop the "Wrong API Key" dialog that closes the app.
# Pass a device with DEVICE=<id>, e.g. make run-release DEVICE=R5CXB30NDRV
run-release: google-xcconfig
	fvm flutter run --release --dart-define=SKIP_PAYWALL=true $(if $(DEVICE),-d $(DEVICE),)

# Release build that rings quietly: no volume override, and a ring that stops
# itself after a few seconds. For testing an alarm at a desk in daylight.
# Pass a device with DEVICE=<id>, e.g. make run-quiet DEVICE=R5CXB30NDRV
run-quiet: google-xcconfig
	fvm flutter run --release --dart-define=SKIP_PAYWALL=true --dart-define=QUIET_ALARM=true $(if $(DEVICE),-d $(DEVICE),)

# Same, as an installable artifact.
build-quiet-apk:
	fvm flutter build apk --release --dart-define=SKIP_PAYWALL=true --dart-define=QUIET_ALARM=true

# Never passes --yes-wipe. Fresh runs require an explicit script invocation.
cold-start:
	sh tool/cold_start.sh --apk "$(APK)" $(if $(SERIAL),--serial "$(SERIAL)",) $(if $(RUNS),--runs "$(RUNS)",) $(if $(MODE),--mode "$(MODE)",) $(if $(LABEL),--label "$(LABEL)",)

# Same flag, for an installable artifact instead of an attached run.
build-release-apk:
	fvm flutter build apk --release --dart-define=SKIP_PAYWALL=true

build-release-ios: google-xcconfig
	fvm flutter build ios --release --dart-define=SKIP_PAYWALL=true

# --- Store upload -------------------------------------------------------------
# One command from a clean main to a build sitting in App Store Connect.
# Auth is an App Store Connect API key, so there is no password and no two
# factor prompt. Run `./scripts/release-ios.sh --help` for the one time setup.

release-ios:
	./scripts/release-ios.sh --bump

# Build and validate against App Store Connect without uploading. Catches a
# duplicate build number or a bad entitlement in a minute instead of ten.
release-ios-dry:
	./scripts/release-ios.sh --dry-run

# Push to Play internal testing. Live in minutes, no review, 100 testers.
# Pass a different track through the script for closed or open testing.
release-android:
	./scripts/release-android.sh --bump

# Build and walk the whole Play upload without committing the edit. An
# uncommitted edit changes nothing, so this is safe to run any time.
release-android-dry:
	./scripts/release-android.sh --dry-run

# Both stores on the build number already in pubspec. No bump: set it first.
# The two builds run one after the other, because Xcode and Gradle at the same
# time fight over the machine. The gates run once, in the iOS step. The two
# uploads run side by side, and the target fails if either one does.
release-both:
	./scripts/release-ios.sh --build-only
	./scripts/release-android.sh --build-only --skip-gates
	./scripts/release-ios.sh --upload-only & ios=$$!; \
	./scripts/release-android.sh --upload-only & android=$$!; \
	wait $$ios; ios_status=$$?; \
	wait $$android; android_status=$$?; \
	[ $$ios_status -eq 0 ] && [ $$android_status -eq 0 ]

# --- Changelogs -------------------------------------------------------------
# cider writes both files. Rules: AGENTS.md, Changelogs.

# make log TYPE=fixed MSG="Android onboarding no longer says your phone needs iOS 26."
log:
	@sh tool/changelog.sh log "$(TYPE)" "$(MSG)"

# make devlog TYPE=changed MSG="AppKeyValueRow stacks label and value when they do not fit."
devlog:
	@sh tool/changelog.sh devlog "$(TYPE)" "$(MSG)"

# Move Unreleased under pubspec's version in both files. Run after the version bump.
changelog-release:
	@sh tool/changelog.sh release

# --- Worktrees ---------------------------------------------------------------
# One folder per branch under worktrees/. See worktrees/README.md for the flow.

# make worktree-new NAME=search-overlay [BRANCH=task/existing] [BASE=main]
worktree-new:
	@sh tool/worktree_new.sh "$(NAME)" "$(BRANCH)" "$(BASE)"

# Every worktree, its branch, and whether it still holds work.
worktree-list:
	@sh tool/worktree_status.sh

# Remove the worktrees that are clean and already merged into main.
worktree-clean:
	@sh tool/worktree_clean.sh

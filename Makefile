.PHONY: gen l10n test run analyze format quality check-layers doctor hooks sync-contract run-release build-release-apk build-release-ios

# One-shot codegen: freezed, json_serializable, flutter_gen.
# Generated output is git-ignored, so run this after a clone and after pulls.
gen:
	fvm dart run build_runner build

# Regenerate type-safe locale keys from assets/translations.
l10n:
	fvm dart run easy_localization:generate -S assets/translations -O lib/gen -o locale_keys.g.dart -f keys

# Refresh docs/api.md and docs/ARCHITECTURE.md from critalarm-server.
sync-contract:
	./scripts/sync-contract.sh

test:
	fvm flutter test

run:
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

# Install the repo git hooks (pre-commit: format + analyze).
hooks:
	git config core.hooksPath tool/git-hooks
	chmod +x tool/git-hooks/*
	@echo "Git hooks installed (core.hooksPath -> tool/git-hooks)."

# Verifies toolchain, regenerates codegen, analyzes and checks layering.
doctor:
	@test "$$(fvm flutter --version | head -1 | awk '{print $$2}')" = "$$(grep -o '[0-9][0-9.]*' .fvmrc)" \
		|| { echo "FVM version mismatch with .fvmrc"; exit 1; }
	fvm dart run build_runner build
	fvm flutter analyze
	sh tool/check_layers.sh

# Release build for UI work on a device. Skips RevenueCat, so the test API key
# cannot pop the "Wrong API Key" dialog that closes the app.
# Pass a device with DEVICE=<id>, e.g. make run-release DEVICE=R5CXB30NDRV
run-release:
	fvm flutter run --release --dart-define=SKIP_PAYWALL=true $(if $(DEVICE),-d $(DEVICE),)

# Same flag, for an installable artifact instead of an attached run.
build-release-apk:
	fvm flutter build apk --release --dart-define=SKIP_PAYWALL=true

build-release-ios:
	fvm flutter build ios --release --dart-define=SKIP_PAYWALL=true

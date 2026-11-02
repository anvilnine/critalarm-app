#!/usr/bin/env sh
# Layering contract (see AGENTS.md and docs/ARCHITECTURE.md):
#   domain  -> core only
#   data    -> domain + core (never presentation)
#   presentation -> domain + core (never data)
#   core    -> nothing app-specific (never features/)
#   features never read kIsWeb: they ask PlatformCapabilities
#   (lib/core/platform/platform_capabilities.dart), built in lib/app/di.dart.
#   features never import a store SDK (purchases_flutter,
#   purchases_ui_flutter, in_app_review, google_sign_in): they ask the store
#   services in lib/core/store/services/, which lib/app/di.dart picks by
#   StoreKind. The SDK calls live in lib/core/store/<store>/.
# The app/ layer is the composition root and may import everything.
set -eu

fail=0

check() {
  pattern="$1"; shift
  label="$1"; shift
  # shellcheck disable=SC2086
  if hits=$(grep -rn "$pattern" "$@" 2>/dev/null); then
    echo "LAYER VIOLATION ($label):"
    echo "$hits"
    fail=1
  fi
}

if ls lib/features/*/domain >/dev/null 2>&1; then
  check "import .*(/data/|/presentation/)" "domain must depend on core only" \
    -E lib/features/*/domain
fi
if ls lib/features/*/data >/dev/null 2>&1; then
  check "import .*/presentation/" "data must not import presentation" \
    lib/features/*/data
fi
if ls lib/features/*/presentation >/dev/null 2>&1; then
  check "import .*/data/" "presentation must not import data" \
    lib/features/*/presentation
fi
# Match the feature-slice package path only (lib/features/**), so core's own
# lib/core/features/ package is not a false positive.
check "import .*package:critalarm/features/" "core must not import features" \
  lib/core
# No exception list. A comment that names the global counts too.
check "kIsWeb" \
  "features must ask PlatformCapabilities (lib/core/platform/platform_capabilities.dart), the capabilities service, and never read kIsWeb" \
  lib/features
check "import .*package:(purchases_flutter|purchases_ui_flutter|in_app_review|google_sign_in)/" \
  "features must reach a store through lib/core/store/services/, never import a store SDK" \
  -E lib/features

if [ "$fail" -ne 0 ]; then
  echo "Dependency direction check FAILED."
  exit 1
fi
echo "Dependency direction check passed."

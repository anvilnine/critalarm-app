#!/usr/bin/env sh
# Layering contract (see AGENTS.md and docs/ARCHITECTURE.md):
#   domain  -> core only
#   data    -> domain + core (never presentation)
#   presentation -> domain + core (never data)
#   core    -> nothing app-specific (never features/)
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

if [ "$fail" -ne 0 ]; then
  echo "Dependency direction check FAILED."
  exit 1
fi
echo "Dependency direction check passed."

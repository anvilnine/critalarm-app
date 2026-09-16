#!/usr/bin/env bash
# Copy the API contract and the architecture doc out of critalarm-server into
# ./docs/. Both copies are generated. Edit them in critalarm-server and run this
# again; a change made here is lost the next time anyone runs it.
#
# Run from the repo root:  ./scripts/sync-contract.sh
set -euo pipefail

# Local sibling checkout. Override when the server lives somewhere else:
#   SERVER_REPO=../some/path ./scripts/sync-contract.sh
#
# Plain "../critalarm-server" only works from the main checkout. Inside
# worktrees/<name> it points at critalarm-app/worktrees/critalarm-server, which
# does not exist. The common git dir always lives in the main checkout, so we
# walk back from there instead of from the current folder.
if [ -z "${SERVER_REPO:-}" ]; then
  common_dir="$(git rev-parse --git-common-dir 2>/dev/null || true)"
  if [ -n "$common_dir" ] && [ -d "$common_dir" ]; then
    main_checkout="$(dirname "$(cd "$common_dir" && pwd)")"
    SERVER_REPO="$main_checkout/../critalarm-server"
  else
    SERVER_REPO="../critalarm-server"
  fi
fi

# After critalarm-server is pushed, switch to fetching a pinned commit instead
# of a sibling folder, so a stale local checkout cannot leak into a build:
#
#   RAW=https://raw.githubusercontent.com/anvilnine/critalarm-server
#   COMMIT=<pin a full 40-char sha here, never a branch name>
#   curl -fsSL "$RAW/$COMMIT/docs/api.md"          -o docs/api.md.tmp
#   curl -fsSL "$RAW/$COMMIT/docs/ARCHITECTURE.md" -o docs/ARCHITECTURE.md.tmp

if [ ! -d "$SERVER_REPO/docs" ]; then
  echo "sync-contract: no docs/ under $SERVER_REPO" >&2
  echo "sync-contract: set SERVER_REPO to the critalarm-server checkout" >&2
  exit 1
fi

commit="$(git -C "$SERVER_REPO" rev-parse --short HEAD 2>/dev/null || echo unknown)"
if [ -n "$(git -C "$SERVER_REPO" status --porcelain 2>/dev/null || true)" ]; then
  commit="$commit-dirty"
fi

mkdir -p docs

for f in api.md ARCHITECTURE.md; do
  {
    echo "<!-- GENERATED from critalarm-server@$commit — do not edit. Run scripts/sync-contract.sh -->"
    echo
    cat "$SERVER_REPO/docs/$f"
  } > "docs/$f"
  echo "sync-contract: docs/$f <- critalarm-server@$commit"
done

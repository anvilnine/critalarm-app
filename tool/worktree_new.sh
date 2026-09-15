#!/usr/bin/env sh
# Create a worktree at <repo>/worktrees/<name>.
#
# The path is resolved from the shared .git, not from the current directory, so
# running this from inside another worktree still puts the new one next to it
# instead of nesting one worktree inside another.
#
#   sh tool/worktree_new.sh <name> [branch] [base]
#
# With no branch, it creates task/<name> off base (default main). With a branch,
# it checks that branch out and ignores base.
set -eu

name="${1:-}"
if [ -z "$name" ]; then
  echo "usage: make worktree-new NAME=<slug> [BRANCH=task/existing] [BASE=main]" >&2
  exit 1
fi
branch="${2:-}"
base="${3:-main}"

common=$(git rev-parse --path-format=absolute --git-common-dir)
main=$(dirname "$common")
path="$main/worktrees/$name"

if [ -e "$path" ]; then
  echo "$path already exists. Pick another NAME, or remove it first." >&2
  exit 1
fi

if [ -n "$branch" ]; then
  git worktree add "$path" "$branch"
else
  git worktree add "$path" -b "task/$name" "$base"
fi

# Use the hook from this checkout, not from the main one. The main checkout can
# sit on a branch that predates the hook, and then prep would silently skip.
prep="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/.claude/hooks/worktree-prep.sh"
if [ -x "$prep" ]; then
  sh "$prep" > /dev/null || true
else
  echo "warning: $prep is missing, so nothing was prepped." >&2
  echo "Run pub get, make gen and make l10n in the new worktree by hand." >&2
fi

echo "Created $path on $(git -C "$path" branch --show-current)."
echo "Codegen runs in the background: tail $path/.worktree-prep.log"
echo ".worktree-ready appears there when it can compile."

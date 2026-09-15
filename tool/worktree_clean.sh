#!/usr/bin/env sh
# Remove worktrees that are finished. Refuse everything else.
#
# Finished means both: the working tree is clean, and the branch is already an
# ancestor of main. Anything with uncommitted changes or unmerged commits is left
# alone and reported, because a worktree can hold hours of work and this script
# is not allowed to guess.
#
# Only worktrees under <repo>/worktrees/ are considered. One parked elsewhere is
# somebody else's and is never touched.
set -eu

common=$(git rev-parse --path-format=absolute --git-common-dir)
main=$(dirname "$common")

git worktree list --porcelain | awk '/^worktree /{print substr($0,10)}' | while read -r wt; do
  [ "$wt" = "$main" ] && continue
  name=$(basename "$wt")

  case "$wt" in
    "$main/worktrees/"*) ;;
    *) echo "skip   $name -- outside worktrees/"; continue ;;
  esac

  if [ ! -d "$wt" ]; then
    echo "prune  $name -- folder gone"
    continue
  fi
  if [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]; then
    echo "keep   $name -- uncommitted changes"
    continue
  fi
  branch=$(git -C "$wt" branch --show-current 2>/dev/null || true)
  if [ -z "$branch" ]; then
    echo "keep   $name -- detached HEAD"
    continue
  fi
  if ! git -C "$wt" merge-base --is-ancestor "$branch" main 2>/dev/null; then
    ahead=$(git -C "$wt" rev-list --count main.."$branch" 2>/dev/null || echo '?')
    echo "keep   $name -- $ahead commit(s) not in main"
    continue
  fi

  git worktree remove "$wt"
  echo "remove $name -- $branch, merged"
done

git worktree prune
echo "Done. Run make worktree-list to see what is left."

#!/usr/bin/env sh
# One line per worktree: folder, branch, commits ahead of main, state.
set -eu

common=$(git rev-parse --path-format=absolute --git-common-dir)
main=$(dirname "$common")

fmt='%-30s %-28s %6s  %s\n'
# shellcheck disable=SC2059
printf "$fmt" FOLDER BRANCH AHEAD STATE
git worktree list --porcelain | awk '/^worktree /{print substr($0,10)}' | while read -r wt; do
  name=$(basename "$wt")
  branch=$(git -C "$wt" branch --show-current 2>/dev/null || echo '-')
  [ -n "$branch" ] || branch='(detached)'
  ahead=$(git -C "$wt" rev-list --count main.."$branch" 2>/dev/null || echo '-')
  dirty=$(git -C "$wt" status --porcelain 2>/dev/null || true)

  if [ "$wt" = "$main" ]; then
    name="$name (main checkout)"
    if [ -n "$dirty" ]; then state='uncommitted changes'; else state='clean'; fi
  elif [ ! -d "$wt" ]; then
    state='MISSING, run make worktree-clean'
  else
    case "$wt" in
      "$main/worktrees/"*) managed=yes ;;
      *) managed=no ;;
    esac
    if [ "$managed" = no ]; then
      state='outside worktrees/, not managed here'
    elif [ -n "$dirty" ]; then
      state='uncommitted changes'
    elif [ "$branch" = '(detached)' ]; then
      state='detached HEAD'
    elif [ ! -f "$wt/.worktree-ready" ]; then
      state='clean, prep not finished'
    elif git -C "$wt" merge-base --is-ancestor "$branch" main 2>/dev/null; then
      state='merged, safe to remove'
    else
      state='clean, unmerged'
    fi
  fi

  # shellcheck disable=SC2059
  printf "$fmt" "$name" "$branch" "$ahead" "$state"
done

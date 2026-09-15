#!/usr/bin/env sh
# On session end, say which worktrees are finished and which still hold work.
#
# This never deletes anything. A worktree can hold hours of uncommitted work and
# a hook is the wrong place to guess. It prints the verdict; `make worktree-clean`
# does the removing, and only for the ones listed as done here.
#
# Done      = working tree clean AND branch fully merged into main.
# Keep      = anything else, with the reason.
set -u

common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
main=$(dirname "$common")

done_list=""
keep_list=""
while read -r wt; do
  [ "$wt" = "$main" ] && continue
  [ -d "$wt" ] || continue
  case "$wt" in "$main/worktrees/"*) ;; *) continue ;; esac
  name=$(basename "$wt")
  branch=$(git -C "$wt" branch --show-current 2>/dev/null)

  if [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]; then
    keep_list="$keep_list $name(uncommitted)"
  elif [ -z "$branch" ]; then
    keep_list="$keep_list $name(detached)"
  elif git -C "$wt" merge-base --is-ancestor "$branch" main 2>/dev/null; then
    done_list="$done_list $name"
  else
    ahead=$(git -C "$wt" rev-list --count main.."$branch" 2>/dev/null || echo '?')
    keep_list="$keep_list $name(${ahead}_unmerged)"
  fi
done << EOF
$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print substr($0,10)}')
EOF

msg=""
[ -n "$done_list" ] && msg="merged and clean, safe to drop:$done_list. Run make worktree-clean. "
[ -n "$keep_list" ] && msg="${msg}still holding work:$keep_list."
[ -z "$msg" ] && exit 0

printf '{"systemMessage": "Worktrees: %s"}\n' "$msg"
exit 0

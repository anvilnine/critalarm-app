#!/usr/bin/env sh
# Add a changelog entry with cider, or release both changelogs.
#
#   sh tool/changelog.sh log <type> "<one line>"      CHANGELOG.md (users)
#   sh tool/changelog.sh devlog <type> "<one line>"   dev-notes/CHANGELOG.md
#   sh tool/changelog.sh release                      both, at pubspec's version
#
# <type> is one of: added changed deprecated removed fixed security.
# Rules for what goes where: AGENTS.md, Changelogs.
set -eu

root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
cider() { fvm dart pub global run cider "$@"; }

if ! fvm dart pub global list 2>/dev/null | grep -q '^cider '; then
  fvm dart pub global activate cider >/dev/null
fi

cmd="${1:-}"
case "$cmd" in
  log|devlog)
    type="${2:-}"
    msg="${3:-}"
    case "$type" in
      added|changed|deprecated|removed|fixed|security) ;;
      *) echo "TYPE must be added, changed, deprecated, removed, fixed or security." >&2; exit 1 ;;
    esac
    if [ -z "$msg" ]; then
      echo "MSG is empty. Write one line, e.g. MSG=\"History keeps 90 days on Pro.\"" >&2
      exit 1
    fi
    case "$msg" in
      *—*|*–*) echo "MSG has an em or en dash. Use a period, comma or colon." >&2; exit 1 ;;
    esac
    dir="$root"
    [ "$cmd" = devlog ] && dir="$root/dev-notes"
    cider --project-root "$dir" log "$type" "$msg"
    ;;
  release)
    version=$(sed -n 's/^version: *//p' "$root/pubspec.yaml")
    cider --project-root "$root/dev-notes" version "$version"
    cider --project-root "$root" release
    cider --project-root "$root/dev-notes" release
    echo "Released $version in CHANGELOG.md and dev-notes/CHANGELOG.md."
    ;;
  *)
    echo "usage: make log TYPE=<type> MSG=\"...\" | make devlog TYPE=<type> MSG=\"...\" | make changelog-release" >&2
    exit 1
    ;;
esac

#!/usr/bin/env sh
# Claude Code PostToolUse hook: format a Dart file right after Claude edits it.
#
# Reads the tool-call JSON on stdin and formats tool_input.file_path when it is
# a hand-written .dart file. Generated files (.g/.freezed/.gen.dart) are
# skipped, matching tool/git-hooks/pre-commit and the CI format check.
#
# Run by tool/git-hooks/pre-commit. Always exits 0 so
# a formatter hiccup never blocks an edit.
set -eu

file=$(jq -r '.tool_input.file_path // empty')
[ -n "$file" ] || exit 0

case "$file" in
  *.g.dart | *.freezed.dart | *.gen.dart) exit 0 ;;
  *.dart) ;;
  *) exit 0 ;;
esac

[ -f "$file" ] || exit 0

fvm dart format "$file" >/dev/null 2>/dev/null || dart format "$file" >/dev/null 2>/dev/null || true

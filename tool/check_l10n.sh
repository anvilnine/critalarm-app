#!/usr/bin/env sh
# Localization guard: fail when an English string literal is passed straight to
# a widget instead of going through LocaleKeys.<key>.tr().
#
# What it flags in production code under lib/ (one line at a time):
#   - a string literal as the first argument of Text( or TextSpan(, on the same
#     line or alone on the line right after a trailing Text( or TextSpan(
#   - a literal after text: on a TextSpan( line or in the 8 lines after it
#   - a literal after label: on an AppButton( line or in the 8 lines after it
#
# Not flagged without a marker: the empty string, and any literal with no ASCII
# letter once ${...} and $name interpolation is removed (digits, symbols,
# whitespace, pure interpolation).
#
# Marker: end the line with `// l10n-ok: <reason>` for text that must stay as
# written (demo data, unit letters). The reason is required. A bare
# `// l10n-ok` fails.
#
# Known limit: it reads one line at a time. A literal held in a variable first,
# or a Text( whose string starts two or more lines down, gets past it. A custom_lint rule would close the gap and is not wanted now.
#
# Needs only POSIX sh and awk, so it runs on the macOS (BSD) toolchain.
set -eu

# Skip list: everything here is generated, mock data, or developer-only UI.
skip_file() {
  case "$1" in
    lib/gen/*|*.g.dart|*.freezed.dart|*.gen.dart) return 0 ;;
    lib/core/api/mock_server.dart|lib/core/api/mock_api_client.dart) return 0 ;;
    lib/design/gallery/*) return 0 ;;
    lib/features/settings/presentation/dialog_sheet_gallery_screen.dart) return 0 ;;
    lib/features/settings/presentation/access_lab_screen.dart) return 0 ;;
    lib/features/settings/presentation/face_gallery_screen.dart) return 0 ;;
    lib/features/settings/presentation/ringing_faces_screen.dart) return 0 ;;
    *) return 1 ;;
  esac
}

files=$(find lib -type f -name '*.dart' | LC_ALL=C sort | while IFS= read -r f; do
  skip_file "$f" || printf '%s\n' "$f"
done)

if [ -z "$files" ]; then
  echo "Localization check passed."
  exit 0
fi

# shellcheck disable=SC2086
if hits=$(printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 awk '
# Return the contents of the string literal that starts at s (s[1] is a quote).
function literal(s,    q, i, c, out) {
  q = substr(s, 1, 1)
  out = ""
  for (i = 2; i <= length(s); i++) {
    c = substr(s, i, 1)
    if (c == "\\") { out = out c substr(s, i + 1, 1); i++; continue }
    if (c == q) return out
    out = out c
  }
  return out
}
# 1 when the literal holds an ASCII letter outside interpolation and escapes.
function has_letters(lit) {
  gsub(/\\./, "", lit)
  gsub(/\$\{[^}]*\}/, "", lit)
  gsub(/\$[A-Za-z_][A-Za-z0-9_]*/, "", lit)
  return lit ~ /[A-Za-z]/
}
# Check every literal that follows `re` on the line. Returns 1 on a hit.
function scan(line, re,    rest, hit, lit) {
  hit = 0
  rest = line
  while (match(rest, re)) {
    lit = substr(rest, RSTART + RLENGTH - 1)
    if (has_letters(literal(lit))) hit = 1
    rest = substr(rest, RSTART + RLENGTH)
  }
  return hit
}
FNR == 1 { btn = 0; span = 0; pend = 0 }
{
  line = $0
  trimmed = line
  sub(/^[ \t]+/, "", trimmed)
  bad = 0
  marker_ok = (line ~ /\/\/ l10n-ok: [^ ]/)

  # Marker without a reason is its own violation.
  if (line ~ /\/\/ l10n-ok/ && !marker_ok) {
    printf "L10N VIOLATION (l10n-ok needs a reason): %s:%d:%s\n", FILENAME, FNR, line
    found = 1
  }

  if (trimmed ~ /^\/\//) next

  # Text( or TextSpan( at the end of a line: the literal may open the next one.
  if (pend) {
    pend = 0
    if (trimmed ~ /^["\x27]/ && has_letters(literal(trimmed))) bad = 1
  }
  if (line ~ /(^|[^A-Za-z0-9_])(Text|TextSpan)\([ \t]*$/) pend = 1

  if (line ~ /(^|[^A-Za-z0-9_])AppButton\(/) btn = 9
  if (line ~ /(^|[^A-Za-z0-9_])TextSpan\(/) span = 9
  if (btn > 0) btn--
  if (span > 0) span--

  if (scan(line, "(^|[^A-Za-z0-9_])(Text|TextSpan)\\([ \t]*[\"\x27]")) bad = 1
  if (span > 0 || line ~ /TextSpan\(/) {
    if (scan(line, "(^|[^A-Za-z0-9_])text:[ \t]*[\"\x27]")) bad = 1
  }
  if (btn > 0 || line ~ /AppButton\(/) {
    if (scan(line, "(^|[^A-Za-z0-9_])label:[ \t]*[\"\x27]")) bad = 1
  }

  if (bad && !marker_ok) {
    printf "L10N VIOLATION: %s:%d:%s\n", FILENAME, FNR, line
    found = 1
  }
}
END { exit found ? 1 : 0 }
'); then
  echo "Localization check passed."
else
  # awk exits 1 on a hit; re-run is not needed, the hits are in $hits.
  printf '%s\n' "$hits"
  echo "Localization check FAILED."
  exit 1
fi

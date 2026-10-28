#!/usr/bin/env sh
# Fail when a store build carries another store's SDK.
#
#   sh tool/store_leak_check.sh <apk-or-aab> <play|galaxy|huawei> [mapping.txt]
#
# Lists the classes in every dex file of the build (dexdump from the SDK build
# tools) and checks them by package. A release build is shrunk by R8, which
# renames most classes into short packages (com.google...AssetPackException
# ships as ua.a), so the names are read back through R8's map: a bundle
# carries it (BUNDLE-METADATA), an apk does not, so pass the variant's
# build/app/outputs/mapping/<store>Release/mapping.txt with a release apk.
# The checks:
#   play           must not carry com.huawei. or com.samsung.android.sdk.iap
#   galaxy, huawei must not carry com.google.android.play.core.assetpacks
#   huawei         reports com.android.billingclient without failing. It comes
#                  in through purchases_flutter, which every flavor ships,
#                  and the multi-store spec accepts it for now.
# An app bundle is checked for the Play sound pack too: the play bundle must
# hold the sound_pack_library module, and the other two must not. Gradle adds
# that pack per run, not per flavor (android/app/build.gradle.kts says why).
#
# It also prints how many classes each SDK family has, so a new SDK shows up
# in the output before it shows up in a store review.
#
# Exit 0 when clean, 1 on a leak, 2 on a usage or tool problem.
set -eu

# dexdump prints raw bytes from the dex string pool. Read them as bytes.
export LC_ALL=C

usage() {
  echo 'Usage: sh tool/store_leak_check.sh <apk-or-aab> <play|galaxy|huawei> [mapping.txt]' >&2
  exit 2
}

[ $# -eq 2 ] || [ $# -eq 3 ] || usage
build=$1
store=$2
mapping=${3:-}
[ -z "$mapping" ] || [ -f "$mapping" ] || { echo "store-leak-check: no R8 map at $mapping" >&2; exit 2; }
case "$store" in play|galaxy|huawei) ;; *) usage ;; esac
[ -f "$build" ] || { echo "store-leak-check: no build at $build" >&2; exit 2; }
case "$build" in
  *.apk) kind=apk ;;
  *.aab) kind=aab ;;
  *) echo "store-leak-check: $build is neither an .apk nor an .aab" >&2; exit 2 ;;
esac

sdk=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
dexdump=$(ls -d "$sdk"/build-tools/*/dexdump 2>/dev/null | sort -V | tail -1 || true)
[ -n "$dexdump" ] && [ -x "$dexdump" ] || {
  echo "store-leak-check: no dexdump under $sdk/build-tools. Install the SDK build tools, or set ANDROID_HOME." >&2
  exit 2
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# An apk keeps its dex files at the root, a bundle under <module>/dex/.
if [ "$kind" = apk ]; then
  unzip -q -o "$build" 'classes*.dex' -d "$work" 2>/dev/null || true
else
  unzip -q -o "$build" '*/dex/*.dex' -d "$work" 2>/dev/null || true
fi
dex_files=$(find "$work" -name '*.dex' | sort)
[ -n "$dex_files" ] || { echo "store-leak-check: no dex files in $build" >&2; exit 2; }

# One class name per line, dotted, as it is in the dex: ua.a
shipped="$work/shipped.txt"
for dex in $dex_files; do
  "$dexdump" "$dex" 2>/dev/null
done | sed -n "s/^ *Class descriptor *: *'L\(.*\);'$/\1/p" | tr '/' '.' | sort -u > "$shipped"
total=$(wc -l < "$shipped" | tr -d ' ')
[ "$total" -gt 0 ] || { echo "store-leak-check: dexdump listed no classes in $build" >&2; exit 2; }

if [ -z "$mapping" ] && [ "$kind" = aab ]; then
  if unzip -q -o "$build" 'BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map' -d "$work" 2>/dev/null; then
    mapping="$work/BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map"
  fi
fi

# The names to check: every shipped class under its original name where R8's
# map has one ("original -> shipped:"), plus the shipped names as they are.
classes="$work/classes.txt"
if [ -n "$mapping" ]; then
  awk 'NR == FNR { shipped[$0] = 1; print; next }
       /^[^ #]/ && $2 == "->" { to = $3; sub(/:$/, "", to); if (to in shipped) print $1 }' \
    "$shipped" "$mapping" | sort -u > "$classes"
  names="original names from $(basename "$mapping")"
else
  cp "$shipped" "$classes"
  names="no R8 map, so a renamed class counts under its short name only"
fi

# Classes whose name starts with $1, taken literally (dots are dots).
count() { awk -v p="$1" 'index($0, p) == 1 { n++ } END { print n + 0 }' "$classes"; }
first() { awk -v p="$1" 'index($0, p) == 1' "$classes" | head -5; }

echo "store-leak-check: $build ($store, $kind, $total classes, $names)"
echo "  SDK families carried:"
for family in \
  com.google.android.play.core.assetpacks. \
  com.google.android.play.core. \
  com.google.android.gms. \
  com.google.firebase. \
  com.android.billingclient. \
  com.revenuecat. \
  com.huawei. \
  com.samsung.android.sdk.iap. \
  com.samsung.; do
  printf '    %-42s %s\n' "$family" "$(count "$family")"
done

fail=0
forbid() {
  n=$(count "$1")
  if [ "$n" -gt 0 ]; then
    echo "  LEAK: the $store build carries $n classes under $1, for example:"
    first "$1" | sed 's/^/    /'
    fail=1
  else
    echo "  ok: no $1"
  fi
}

case "$store" in
  play)
    forbid com.huawei.
    forbid com.samsung.android.sdk.iap.
    ;;
  galaxy)
    forbid com.google.android.play.core.assetpacks.
    ;;
  huawei)
    forbid com.google.android.play.core.assetpacks.
    n=$(count com.android.billingclient.)
    echo "  note: com.android.billingclient. has $n classes (purchases_flutter, accepted for now, not a failure)"
    ;;
esac

if [ "$kind" = aab ]; then
  if unzip -l "$build" 'sound_pack_library/*' >/dev/null 2>&1; then has_pack=yes; else has_pack=no; fi
  if [ "$store" = play ] && [ "$has_pack" = no ]; then
    echo "  MISSING: the play bundle has no sound_pack_library module."
    fail=1
  elif [ "$store" != play ] && [ "$has_pack" = yes ]; then
    echo "  LEAK: the $store bundle carries the Play sound pack (sound_pack_library)."
    fail=1
  else
    echo "  ok: sound_pack_library in the bundle: $has_pack"
  fi
fi

if [ "$fail" -ne 0 ]; then
  echo "store-leak-check: FAILED for $store"
  exit 1
fi
echo "store-leak-check: passed for $store"

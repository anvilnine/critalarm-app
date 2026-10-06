#!/usr/bin/env sh
# Build the APK first with: make build-quiet-apk
# For an offline run, switch airplane mode on by hand and pass --label offline.
# TotalTime ends at the activity's first drawn frame, which may be the splash.
# Each uiautomator poll costs about a second, so Get started timing is coarse
# and useful only for large differences.
set -eu

usage() {
  echo 'Usage: sh tool/cold_start.sh --apk <path> [--serial <id>] [--runs 10] [--mode fresh|warm] [--label <text>] [--yes-wipe]' >&2
  exit 2
}

apk=''
serial=''
runs=10
mode=warm
label=''
yes_wipe=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --apk|--serial|--runs|--mode|--label)
      [ "$#" -ge 2 ] || usage
      case "$1" in
        --apk) apk=$2 ;;
        --serial) serial=$2 ;;
        --runs) runs=$2 ;;
        --mode) mode=$2 ;;
        --label) label=$2 ;;
      esac
      shift 2 ;;
    --yes-wipe) yes_wipe=1; shift ;;
    *) usage ;;
  esac
done

[ -n "$apk" ] || usage
case "$runs" in ''|*[!0-9]*) usage ;; esac
[ "$runs" -gt 0 ] || usage
case "$mode" in fresh|warm) ;; *) usage ;; esac
case "$label" in *','*) echo 'Label must not contain a comma or newline.' >&2; exit 2 ;; esac
label_lines=$(printf '%s\n' "$label" | wc -l | tr -d ' ')
[ "$label_lines" -eq 1 ] || { echo 'Label must not contain a comma or newline.' >&2; exit 2; }
[ -n "$label" ] || label=$mode

# Keep this gate ahead of every adb call, including adb devices and install.
if [ "$mode" = fresh ] && [ "$yes_wipe" -ne 1 ]; then
  echo 'Fresh mode deletes all app.critalarm data. Pass --yes-wipe explicitly.' >&2
  exit 2
fi
[ -f "$apk" ] || { echo "APK not found: $apk" >&2; exit 2; }
command -v adb >/dev/null 2>&1 || { echo 'adb not found.' >&2; exit 2; }

if [ -z "$serial" ]; then
  devices=$(adb devices) || exit 1
  serial=$(printf '%s\n' "$devices" | awk 'NR > 1 && $2 == "device" { print $1 }')
  count=$(printf '%s\n' "$serial" | awk 'NF { n++ } END { print n+0 }')
  [ "$count" -eq 1 ] || { echo 'Specify --serial when zero or multiple devices are available.' >&2; exit 2; }
fi

adb_on_device() { adb -s "$serial" "$@"; }
now_ms() {
  # Android's date has %N (nanoseconds) but no %3N, so divide here.
  value=$(adb_on_device shell date +%s%N | tr -d '\r') || return 1
  case "$value" in ''|*[!0-9]*) echo "Cannot read device nanoseconds: $value" >&2; return 1 ;; esac
  echo $((value / 1000000))
}

# Dumping to /dev/tty prints no XML on Android 15, so dump to a file and read it.
ui_dump() {
  adb_on_device shell 'uiautomator dump /sdcard/window_dump.xml >/dev/null 2>&1; cat /sdcard/window_dump.xml' 2>/dev/null || true
}

model=$(adb_on_device shell getprop ro.product.model) || exit 1
android=$(adb_on_device shell getprop ro.build.version.release) || exit 1
size=$(wc -c < "$apk" | tr -d ' ')
echo "Device: $model ($serial), Android $android" >&2
echo "APK: $apk ($size bytes)" >&2
echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')" >&2
if [ "$mode" = fresh ]; then
  echo "WIPING app.critalarm data on $model ($serial) before every run." >&2
fi

# install -r preserves data. A signature mismatch is an error, not a reason
# to uninstall the owner's app.
adb_on_device install -r "$apk" || { echo 'APK install failed. No uninstall was attempted.' >&2; exit 1; }

results=$(mktemp) || exit 1
trap 'rm -f "$results"' EXIT HUP INT TERM
echo 'label,mode,run,total_ms,wait_ms,get_started_ms'
run=1
while [ "$run" -le "$runs" ]; do
  if [ "$mode" = fresh ]; then
    adb_on_device shell pm clear app.critalarm >/dev/null || exit 1
  else
    adb_on_device shell am force-stop app.critalarm || exit 1
  fi

  start_ms=$(now_ms) || exit 1
  launch=$(adb_on_device shell am start -W -n app.critalarm/.LauncherDefault) || {
    printf '%s\n' "$launch" >&2
    exit 1
  }
  total=$(printf '%s\n' "$launch" | awk '/^[[:space:]]*TotalTime:/ { print $2; exit }')
  wait=$(printf '%s\n' "$launch" | awk '/^[[:space:]]*WaitTime:/ { print $2; exit }')
  case "$total:$wait" in
    *[!0-9:]*|:*|*:) printf 'Could not parse am start -W output:\n%s\n' "$launch" >&2; exit 1 ;;
  esac

  get_started=skipped
  if [ "$mode" = fresh ]; then
    get_started=timeout
    while :; do
      current_ms=$(now_ms) || exit 1
      [ $((current_ms - start_ms)) -lt 30000 ] || break
      dump=$(ui_dump)
      if printf '%s\n' "$dump" | grep -Eq '(text|content-desc)="Get started"'; then
        current_ms=$(now_ms) || exit 1
        get_started=$((current_ms - start_ms))
        break
      fi
      sleep 1
    done
  else
    # A warm launch normally opens Home. Record the welcome label only if
    # it is already visible in the first dump.
    dump=$(ui_dump)
    if printf '%s\n' "$dump" | grep -Eq '(text|content-desc)="Get started"'; then
      current_ms=$(now_ms) || exit 1
      get_started=$((current_ms - start_ms))
    fi
  fi
  adb_on_device shell am force-stop app.critalarm || exit 1
  row="$label,$mode,$run,$total,$wait,$get_started"
  echo "$row" | tee -a "$results"
  run=$((run + 1))
done

awk -F, '
  function stats(name, values, count,    i,j,temp,median) {
    if (!count) { print "# " name ": no numeric samples"; return }
    for (i=2; i<=count; i++) {
      temp=values[i]; j=i-1
      while (j>=1 && values[j]>temp) { values[j+1]=values[j]; j-- }
      values[j+1]=temp
    }
    if (count%2) median=values[(count+1)/2]
    else median=(values[count/2]+values[count/2+1])/2
    printf "# %s: median=%g min=%g max=%g ms\n", name, median, values[1], values[count]
  }
  { total[++nt]=$4+0; wait[++nw]=$5+0; if ($6 ~ /^[0-9]+$/) started[++ns]=$6+0 }
  END { stats("total_ms",total,nt); stats("wait_ms",wait,nw); stats("get_started_ms",started,ns) }
' "$results"

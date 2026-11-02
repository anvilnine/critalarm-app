#!/bin/sh
# Records the Cloud paywall layouts and benefit previews as frames. The usage,
# ids and output layout are in the header of tool/capture_site_paywalls.dart.
set -eu
cd "$(dirname "$0")/.."
: "${SITE_OUT:=$PWD/build/site_paywalls}"
export SITE_OUT
exec fvm flutter test tool/capture_site_paywalls.dart \
  --dart-define=MOCK=true --dart-define=SKIP_PAYWALL=true --reporter=expanded

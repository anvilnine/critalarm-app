#!/usr/bin/env sh
# One source for plan access (lib/core/access/):
#   "is this feature open"        -> FeatureAccess.can / FeatureAccess.decide
#   "what does this install hold" -> Holdings.holds / Holdings.stateOf
#   "is this a server of the user's own" -> FeatureAccess.isOwnServer /
#                                           isOwnServerMode
# Nothing else reads the registered tier, the store, the relay's packs or a
# developer switch to decide access, and nothing else compares a server mode
# to decide something about plans. This fails when a file under lib/ that is
# not on the allow list has one of the raw reads:
#   isPaid, readIsPaid, isRegisteredPaid, isProPending, isProActive,
#   isForcing (ProOverride.isForcingPro, ProPackOverride.isForcing),
#   storeSaysPro, entitlements.active,
#   .isHeld, isStoreAcceptedAwaitingRelay, ProPackAccess.stream,
#   .tier read off an identity or a registration answer,
#   readHeldByServer, storeMayStillHold (named reads of the Hosted source),
#   ServerMode.selfhosted / .hosted / .relay next to == or !=.
#
# A line that has to carry one of these for another reason ends with
#   // access-ok: <reason>
# The marker counts only on the offending line itself, after its code.
set -eu

# The allow list. One path per line. A file, except where a folder is the
# only thing that can be listed (it ends with /).
ALLOW='
lib/core/access/
lib/app/access/hosted_holding_source.dart
lib/app/access/pro_holding_source.dart
lib/app/access/sure_lock.dart
lib/core/models/account_access.dart
lib/core/storage/device_identity_store.dart
lib/core/account/plan_changes.dart
lib/core/paywall/pro_override.dart
lib/features/pro_pack/domain/pro_pack_access.dart
lib/features/pro_pack/domain/pro_pack_override.dart
lib/features/paywall/domain/repositories/subscription_repository.dart
lib/features/paywall/data/repositories/dev_subscription_repository.dart
lib/features/paywall/data/repositories/in_memory_subscription_repository.dart
lib/features/paywall/data/repositories/revenuecat_subscription_repository.dart
lib/features/paywall/presentation/cubits/paywall_cubit.dart
lib/features/pro_pack/presentation/cubits/pro_pack_sheet_cubit.dart
lib/features/paywall/presentation/layouts/
'
# Why each entry is there:
#   lib/core/access/            the access layer itself, with the one
#                               own-server rule.
#   hosted_holding_source.dart  the Hosted source: tier, store flag, switch,
#                               and its two named reads.
#   pro_holding_source.dart     the Pro source: the only reader of
#                               ProPackAccess.isHeld.
#   sure_lock.dart              asks the Hosted source's storeMayStillHold
#                               before it says "locked".
#   account_access.dart         wrapped by the Hosted source. Defines isPaid,
#                               isRegisteredPaid and isProPending, and words
#                               the usage line.
#   device_identity_store.dart  where the tier is kept. It reads .tier to
#                               write it back and decides nothing.
#   plan_changes.dart           wrapped by the Hosted source. Holds
#                               storeSaysPro.
#   pro_override.dart           wrapped by the Hosted source. The developer
#                               switch, isForcingPro.
#   pro_pack_access.dart        wrapped by the Pro source. Defines isHeld,
#                               isStoreAcceptedAwaitingRelay and stream.
#   pro_pack_override.dart      wrapped by ProPackAccess. The developer Pro
#                               switch, isForcing.
#   subscription_repository.dart and the three files under
#   paywall/data/repositories/  the store. They define and answer
#                               isProActive from entitlements.active, and
#                               run buy and restore.
#   paywall_cubit.dart          the shipped Hosted paywall: buy and restore.
#                               It reads AccountAccess.isPaid fresh (line
#                               82) beside the cached Holdings, and waits
#                               for the server tier after a purchase. Left
#                               alone: it is the shipped paywall.
#   pro_pack_sheet_cubit.dart   the Pro sheet: buy and restore.
#   paywall/presentation/layouts/
#                               a folder, because this task may not edit or
#                               list the files in it: the layout buy cubits
#                               (buy and restore), and three animation
#                               frames with a field of their own named
#                               isHeld.

MODE='ServerMode\.(selfhosted|hosted|relay)'
PATTERN="isPaid|readIsPaid|isRegisteredPaid|isProPending|isProActive"
PATTERN="$PATTERN|isForcing|storeSaysPro|entitlements\.active"
PATTERN="$PATTERN|\.isHeld|isStoreAcceptedAwaitingRelay"
PATTERN="$PATTERN|ProPackAccess>\(\)\.stream|[aA]ccess\.stream"
TIER='(dentity|response|carried|stored|saved|\))[!?]?\.tier([^A-Za-z0-9_]|$)'
PATTERN="$PATTERN|$TIER"
PATTERN="$PATTERN|[rR]eadHeldByServer|[sS]toreMayStillHold"
PATTERN="$PATTERN|[!=]= *$MODE|$MODE *[!=]="

# A marked line has code, then the marker, then a reason, to the line end.
MARKED='[^ /].*// access-ok: [^ ].*$'

hits=$(grep -rnE "$PATTERN" lib --include='*.dart' \
  | grep -v '\.g\.dart:' | grep -v '\.freezed\.dart:' \
  | grep -vE "^[^:]+:[0-9]+:.*$MARKED" || true)

for entry in $ALLOW; do
  hits=$(printf '%s\n' "$hits" | grep -v "^$entry" || true)
done

if [ -n "$hits" ]; then
  echo "ACCESS VIOLATION (ask FeatureAccess or Holdings, lib/core/access/):"
  echo "$hits"
  echo "Access check FAILED."
  exit 1
fi
echo "Access check passed."

#!/usr/bin/env sh
# One source for plan access (lib/core/access/):
#   "is this feature open"  -> FeatureAccess.can / FeatureAccess.decide
#   "what does this install hold" -> Holdings.holds / Holdings.stateOf
# Nothing else reads the registered tier, the store, the relay's packs or a
# developer switch to decide access. This fails when a file under lib/ that
# is not on the allow list names one of the raw reads:
#   isPaid, readIsPaid, isRegisteredPaid, isProActive, isForcingPro,
#   storeSaysPro, or `.isHeld` (ProPackAccess).
#
# A line that has to carry one of these names for another reason ends with
#   // access-ok: <reason>
set -eu

# The allow list. One path per line, a file or a folder (ends with /).
ALLOW='
lib/core/access/
lib/app/access/hosted_holding_source.dart
lib/app/access/pro_holding_source.dart
lib/core/models/account_access.dart
lib/core/account/plan_changes.dart
lib/core/paywall/pro_override.dart
lib/features/pro_pack/domain/pro_pack_access.dart
lib/features/paywall/domain/repositories/subscription_repository.dart
lib/features/paywall/data/repositories/
lib/features/paywall/presentation/cubits/paywall_cubit.dart
lib/features/pro_pack/presentation/cubits/pro_pack_sheet_cubit.dart
lib/features/paywall/presentation/layouts/
'
# Why each entry is there:
#   lib/core/access/            the access layer itself.
#   hosted_holding_source.dart  the Hosted source: tier, store flag, switch.
#   pro_holding_source.dart     the Pro source: the only reader of
#                               ProPackAccess.isHeld.
#   account_access.dart         wrapped by the Hosted source. Defines isPaid
#                               and isRegisteredPaid, and words the usage line.
#   plan_changes.dart           wrapped by the Hosted source. Holds
#                               storeSaysPro.
#   pro_override.dart           wrapped by the Hosted source. The developer
#                               switch, isForcingPro.
#   pro_pack_access.dart        wrapped by the Pro source. Defines isHeld.
#   subscription_repository.dart and paywall/data/repositories/
#                               the store. They define and answer
#                               isProActive, and run buy and restore.
#   paywall_cubit.dart          the shipped Hosted paywall: buy and restore.
#                               It waits for the server's tier after a
#                               purchase, which is not a gate.
#   pro_pack_sheet_cubit.dart   the Pro sheet: buy and restore.
#   paywall/presentation/layouts/
#                               the layout buy cubits (buy and restore), and
#                               three animation frames with a field of their
#                               own named isHeld.

PATTERN='isPaid|readIsPaid|isRegisteredPaid|isProActive|isForcingPro|storeSaysPro|\.isHeld'

hits=$(grep -rnE "$PATTERN" lib --include='*.dart' \
  | grep -v '\.g\.dart:' | grep -v '\.freezed\.dart:' \
  | grep -v '// access-ok: ' || true)

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

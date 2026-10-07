import 'package:critalarm/core/models/account_pack.dart';

/// The id the relay lists the Pro pack under (api.md §4.2).
const proPackId = 'pro';

/// Whether [packs] lists the Pro pack.
///
/// The list is the whole answer. An id this app does not know is treated as
/// absent, which here means it is passed over.
bool listsProPack(Iterable<AccountPack> packs) =>
    packs.any((pack) => pack.id == proPackId);

/// What the app may conclude from one `POST /relay/v1/packs/refresh`.
enum ProPackRefreshOutcome {
  /// The account holds the pack.
  held,

  /// The store was read and the account holds the pack from no source.
  notHeld,

  /// Nothing. The store could not be asked, or the relay could not be
  /// reached. Whatever was showing stays, and the app asks again later.
  unknown,
}

/// The table in api.md §4.2, one row per case.
///
/// `confirmed` is about the store read, not about the list. So a pack that
/// is listed is held whatever `confirmed` says, and a pack that is missing
/// is only "not held" when the store was read. `confirmed: false` with the
/// pack missing never reads as "no pack".
ProPackRefreshOutcome proPackRefreshOutcome({
  required bool confirmed,
  required bool listed,
}) {
  if (listed) return ProPackRefreshOutcome.held;
  return confirmed
      ? ProPackRefreshOutcome.notHeld
      : ProPackRefreshOutcome.unknown;
}

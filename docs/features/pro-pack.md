# Pro pack

Moved out of AGENTS.md on 2026-10-17, text unchanged. Read before changing this area.

**Pro pack.** A pack is an add-on an account holds beside its tier
(api.md §4.2). The only one is `pro`. The code is in `lib/features/pro_pack/`.

- Two things share a word. Identifiers that say Pro and are not `ProPack...`
  (`ProAskSheet`, `ProStatusCubit`, `SubscriptionTier.cloudEntitlement`,
  `ProOverride`, `DevProSwitch`) mean the Cloud plan. The pack is always
  `ProPack...` in code and "Pro" in copy. Neither routes through the other.
- `ProPackAccess` answers one question: does this install hold the pack.
  `isHeld` is the value and `stream` carries its changes. It never says how
  the pack was granted, and nothing in the app names a way of selling it.
- It reads the relay's `packs` list: every registration response,
  `GET /relay/v1/packs` on launch and resume (once a minute at most), and
  `POST /relay/v1/packs/refresh` after a purchase or a restore. The last list
  is kept under the prefs key `pro_pack.relay_packs`, so a cold start with
  no network still answers.
- A kept list belongs to one account on one relay (`ProPackScope`). It
  shows only while this phone's account is known and is that one. An
  unknown account holds nothing, and a different one clears the list.
- Relay answers have one writer (`_apply`). The calls `ProPackAccess` makes
  run one at a time. A registration is numbered when it starts
  (`beginRelayRequest`), and an answer older than the one showing, or asked
  for another account, is dropped.
- A purchase is written down before the store is asked
  (`pro_pack.pending_confirm`). Until the relay lists the pack, launch and
  resume ask it to read the store again, for
  `ProPackAccess.pendingConfirmGivesUpAfter` at most.
- A kept pack whose `expires_at` has passed stays held for
  `ProPackAccess.expiredGrace` with no word from the relay, then is not
  held. A pack with no `expires_at` never ends on the phone.
- A pack is never worked out from the tier. `proPackGrantedElsewhere`
  (`pro_pack_grant.dart`) is the one function that could grant the pack from
  another source, and it returns false.
- `proPackRefreshOutcome` is the refresh table. `confirmed: false` with no
  pack listed is `unknown`: what was showing stays, the paywall says it is
  still checking and asks again. It is never "no pack" and never a failed
  purchase.
- Pro is sold on a paywall layout (`/plans/<layout>?product=pro`), the same
  route that sells Cloud. There is no Pro sheet and no `/pro` route.
  `ProPaywallBuyCubit` lists the packages of the RevenueCat offering
  `proPackOfferingId`. With no such offering the layout still draws, and
  its buy block says Pro is not on sale yet and offers nothing to buy.
  Restore is there either way.
- **Paywalls are coded, never remote.** Every locked place asks
  `PaywallDoor` (`lib/features/paywall/presentation/paywall_door.dart`), and
  the door always answers with a layout location. `paywallOpeningFor`
  (`lib/features/paywall/domain/paywall_routing.dart`) holds the defaults:
  the place table picks the layout and the intro, Cloud ends on Receipt
  party after Cloud climb, Pro on Stamp after Break, lift, ring. Remote
  Config holds no paywall key, RevenueCat's dashboard draws no paywall
  (`RevenueCatUI.presentPaywall` is never called), and only the customer
  centre still comes from `purchases_ui_flutter`. Developer options can
  set each of the four steps in a `SKIP_PAYWALL` or `PAYWALL_LAB` build,
  with "Auto" (the coded default) first. `/paywall?source=...` is kept as a
  path for reminders, the settings search result and a locked home screen
  widget. It draws nothing and redirects to the layout for its source. If
  the door fails, or none is registered, the plan layout for that product
  opens. Details: `lib/features/paywall/presentation/layouts/kit/README.md`,
  "What opens".
- The pack unlocks features built into the app (`featureTable`). It has
  no row on the Reliability screen: the weekly delivery check there needs
  Cloud (see `docs/features/weekly-check.md`).
- Developer options has a switch for the pack beside the Cloud one, in a
  `SKIP_PAYWALL` build only (`dev.pro_pack`). In a mock build it also makes
  the mock relay hold the pack (`MockServer.grantedPacks`).


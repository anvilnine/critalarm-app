# The setup offer

Moved out of AGENTS.md on 2026-10-17, text unchanged. Read before changing this area.

`offer` is a frame around the offer sequence (`offer_step_screen.dart`). It
holds no words, prices or benefit lists: the layout and the thanks screen own
those. `2026-10-b` and `2026-10-c` list it between `real_ring` and `hook_up`,
it has no chapter, and it ships switched on.

- Four switches (`OnboardingOfferConfig`): `enabled` (true), `cloud_product`
  (`auto`, `pro`, `hosted` or `none`; `auto`), `self_hosted_product` (`pro` or
  `none`; `pro`) and `layout` (a `PaywallLayoutId.key`; `reel`). The bundled
  value is in brackets. They are one JSON object, read from Developer options
  (`dev.onboarding_offer`), then the Remote Config key `onboarding_offer`
  (`TelemetryGate.onboardingOfferJson`), then the bundled value. A field left
  out takes its bundled value, so a remote value that leaves `enabled` out
  keeps the step on and only `{"enabled": false}` switches it off. A field
  with a value it cannot have sets the whole object aside and the next
  source is asked. A build older than `auto`
  sets a value holding it aside the same way.
- `auto` picks the product from the answer on our server: the Pro pack for the
  home answer, Cloud for the rest. `pro`, `hosted` and `none` force one
  answer for everyone. On a server of the user's own only
  `self_hosted_product` counts, and Cloud is never offered there.
- `decideOnboardingOffer` is the rule. The step skips itself on a replay
  (see below), when it is off, when the product is `none` for this kind of
  server, when the layout is not built in this version, when no account id is
  known, and when the user already holds the product. `OnboardingOfferGate`
  reads the phone for it, and a read that fails is a skip. It reads no store.
- The store check starts early. When the real alarm step opens,
  `OnboardingOfferGate.startSaleCheck()` has `OfferSaleProbe` make the buy
  model and load it, so the store answer is cached before "It works" appears.
  It is the one store read the paywall already makes and no request goes to
  the app's own server. The step takes the loaded model (`takeOnSale`): a
  cached answer costs no wait, and with no answer yet it waits up to 2
  seconds (`offerSaleWait`) on the plain setup canvas. Only a product that is
  on sale goes on. Not on sale, a failed load and a timeout all skip the step.
  A cached "not on sale" also makes the engine skip the step
  (`hasNoOfferToShow`), so Continue goes straight to `hook_up`.
- There is no intro. After Continue the reel rises over the setup step from
  the bottom edge, fully opaque (`buildOfferLayerTransition`, 400 ms), so the
  setup canvas and its tracker are covered by the moving edge and never show
  through a half-faded reel. With reduced motion it opens at once. The setup
  offer plays no false alarm, shows no tag and no skip hint, and never writes
  `paywall.false_alarm_shown`: the Settings plan row keeps its false alarm.
  The false alarm intro, its tag rule and the paywall kit's `hint` parameter
  stay in the kit for other triggers.
- Then the reel, and on a purchase the confetti thanks. The reel opens on the
  benefit the answer leads with (`offerLeadFor`): the critical topics for
  servers (naming the user's topic), the weekly delivery check for homelab
  and jobs, widgets for home and for any answer on an own server. An answer
  of `other` keeps the paywall's own order. A lead never names a benefit the
  product does not list. A scene whose picture has less room than
  `reelStageMinHeight` (the smallest mascot and the room above it) draws no
  picture and no placeholder, and the lead's line stands under the headline.
  It happens at 320 wide and text scale 2.0 with a lead line.
- The thanks screen has one button, "Hook up your tool". It pops the layer
  and the step finishes, so setup goes on to `hook_up` and never to Home.
  Closing the layer with the cross does the same with no purchase.
- A real alarm wins. When one starts while the layer is open, or the step
  goes away under it, the layer is taken off at once, the step finishes in
  the engine with no navigation and no purchase is recorded.
- A step that skips counts as already done (`hasNoOfferToShow`), so a run
  never opens it and the funnel never counts it.
- A replay plays the step in a build that skips the store (`SKIP_PAYWALL`,
  `OnboardingOfferGate.readUsesDemoStore`), and nowhere else. Redo onboarding
  there goes on from the ring step into the reel, led by the answer picked in
  that replay (`SetupUseReplay`), then the made-up purchase or the cross, the
  thanks and hook up. On that made-up buy model a replay ignores the account
  and the products held (`offerIgnoresHoldings`), so a tester sees the paywall
  with no account, with Cloud already held and with Pro already held. It
  still follows the switches: the offer switched off (by the developer value
  or the remote one), no product for an own server, and an unbuilt layout all
  skip it. An own server gets the `self_hosted_product` offer, as a real run
  would. The replay writes nothing: no answer, no step marked done, no funnel
  event (`isReplay` goes to `OnboardingFunnel`), no false alarm flag, and no
  `appPlanChanges` or `appAccountIdentityChanges` bump after the made-up
  purchase. The replayed real alarm step sends nothing and its button moves
  on, so a replay has no "It works" screen and no confetti rule to follow.
- A replay with a real store skips the step, because the buy button would
  start a real purchase. The one exception is a developer value: with the
  Offer step switches set in Developer options, "Open a step" shows it, and
  the Offer sequence row there opens it on one answer (`?use=<wire id>`). That
  replay asks the phone as a real run does (account, products held), reads
  the real store, and is the tester's own choice.
  `tool/capture_offer_sequence.dart` (`ONLY=redo`) walks the whole Redo
  onboarding and checks that the prefs end as they began.
- The buy model comes from the same `PaywallBuyCubit` factory the paywall
  route uses, so only a `SKIP_PAYWALL` build gets the stand-in.
- Three funnel events go through `OnboardingFunnel`: `onboarding_offer_shown`,
  `onboarding_offer_closed` and `onboarding_offer_bought`, each with
  `product`, `layout`, `use` and `flow_id`. They wait for the analytics answer
  with the step events.
- While the step is still to come (`offerStepIsAhead`) and the store has not
  said no, `AfterAckDecider` gives an acknowledged alarm no follow-up.
  `OnboardingOfferGate.outlook()` is the one answer: `coming` (step ahead,
  store said on sale), `none` (not ahead, or the store said nothing is on
  sale) and `unsure` (step ahead, no store answer yet). `ackConfettiMayFly`
  is the pure rule on it.


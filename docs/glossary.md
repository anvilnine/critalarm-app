# Glossary

Moved out of AGENTS.md on 2026-10-17, text unchanged. Read before changing this area.

**Glossary.** Three features share a screen and used to share words. Use these
names in code, strings, comments and PRs, and never one for another.

- **Feature Guides** (`lib/features/feature_guides/`): the per-screen spotlight
  walkthroughs. Each screen plays its guide once; Settings › Feature Guides
  replays them all. Formerly "tour" and, before that, "showcase". The prefs keys
  `tour_guides_seen` and `has_completed_showcase_tour` keep their old names
  because devices already hold them.
- **Cloud** (the paid plan): the word in copy since the plan was renamed from
  Hosted. The code keeps `hosted` everywhere it was already there: `Holding.hosted`,
  `PaywallProduct.hosted`, translation key names such as `paywall_kit.name_hosted`,
  route values, prefs keys, analytics, the store product ids, the server mode
  and the account tier. Only the text a person reads or hears says Cloud. The
  server we run is "our server" in copy, never "Crit Alarm Cloud", so that Cloud
  means the plan only.
- **In-App Notices** (`lib/features/in_app_notices/`): a reminder Home pins
  above the tab bar as an `AppPinnedNoticeBar`. `InAppNoticeCubit` picks two
  of them: the Cloud plan ending and "back up your topics". A notice sits
  there until its condition clears or the user dismisses it. An **ask** is
  different: an interruptive sheet or popup (the Pro ask, the consent ask,
  the Local reminders sheet, the cancel question, the store review),
  governed by `HomeAskRules` and `SetupGate`. Never call a sheet a notice. Formerly "home prompts"; the
  `home_prompt_*` prefs keys and the `pro_prompt_answered` analytics event
  keep their names.
  Home puts three kinds of thing on the screen, and only the first is a
  notice:
  - **Pinned bars** (`pinnedBarFor` in
    `lib/features/topics/domain/home_list_rules.dart`): one at a time, in
    this order. The Cloud ending, the account backup reminder, then "One
    topic so far", which is Home's own rule and not a notice.
  - **Status card kinds** (`HomeCardKind`): what Home reports about whether
    an alarm will ring, and where setup stands. No server, a missed alarm, a
    stale or failed list, a warning, a failed or doubtful reliability check
    (a missing permission, battery saver, a phone update, weekly checks that
    stopped), the setup checklist and the wait for the first message. None
    of them is a notice or a banner. The card is the only place Home reports
    health.
  - **Cream cards** (`AppCreamCard`, `creamCardFor`): the widgets card and the
    day-0 card, one at a time at the top of the list sheet. The widgets card
    comes from `HomeSetupCubit`. `Day0CardCubit` decides the day-0 card,
    after the asks in `runHomeAsk`. Neither goes through `InAppNoticeCubit`.
    See `docs/features/home.md`.
- **Local Reminders** (`lib/features/local_reminders/`): notifications the app
  schedules for itself on the device: fire drill, silent topic, backup, plan
  heads-up, review and feedback asks, Pro later. Method channel
  `app.critalarm/local_reminders`. The Android channel id `reminders_v1`, the
  iOS category ids `reminder_<kind>` and the `reminder_*` prefs keys are
  persisted and keep their names.
- **Setup order.** Onboarding, including the first-topic step inside it,
  shows no guide, notice, ask or Local Reminder. There is one exception:
  the analytics switch row on the last step (`hook_up`). It is a row on
  the screen, it opens no sheet and it holds nothing back. The order of the setup
  steps is a flow (see `docs/features/onboarding-flow-engine.md`). In the default flow the
  first topic is created before the test alarm, and the server sends that
  test alarm (see "Real ring" in `docs/features/onboarding-steps.md`). The
  Topics guide is always the first Feature Guide. The first time the user
  reaches Topics, a sheet offers it (`FeatureGuideStatus.offering`); taking
  it plays the Topics guide, declining it marks every guide seen. Only after
  that is answered do other screens' guides, In-App Notices, asks and
  planned Local Reminders start.
  `SetupGate` holds back the notices, asks and Local Reminders;
  `FeatureGuideCubit.requestIfNew` holds back every guide but the Topics
  one. Do not route guides through `SetupGate`: it waits for the Topics
  guide, which could then never start.
- **Remote Reminders** (not built): reminders the server would send. The
  "Local" qualifier exists so the two never share a name.


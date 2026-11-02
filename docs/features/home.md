# Home setup content

Moved out of AGENTS.md on 2026-10-17, text unchanged. Read before changing this area.

**Home setup content.** A user who left setup early gets a checklist that
the status card speaks for. The card shows the label SETUP, the count as
`1/3` with one pip per row, and a foot naming the next open row
(`HomeCardKind.setup`). Its button, Continue, opens the screen for that row.
Nothing in the list sheet or above the tab bar shows the rows any more: the
floating checklist card that did is gone. Once the first two
rows are true the card turns into the wait for the first message
(`HomeCardKind.waiting`). Its foot is the waiting line of the saved tool when
that tool has documented steps, and of the user's answer otherwise
(`waitingLineFor`); an `other` answer leaves "send the first line". The rules are pure functions in
`lib/features/topics/domain/setup_checklist.dart`, and `HomeSetupCubit` runs
them from the list Home drew. The card rule is in
`lib/features/topics/domain/home_card/home_card_rule.dart`.

- Three rows, one pip each: a server is connected, a topic has Critical
  delivery on, a first message arrived (`FirstMessageStore.isReceived`, the
  same fact the last setup step reads).
- It counts only over a list that loaded, and stays until all three are
  true. The card shows the first kind in `homeCardPriority` whose condition
  holds, so a ringing alarm, the no-server card or a broken check outranks
  it. An empty Home shows its empty state in the sheet under the card.
- A pinned bar does not cover the card, so the checklist counts as in front
  whenever Home is, and no row ticks out of sight.
- The Continue button only opens the screen for the next open row
  (`setupChecklistRoute`). Nothing here turns Critical delivery on.
- The first look at a phone (`seedSetupChecklist`, once, saved as
  `setup_checklist_seeded`): a phone that already has the first-message
  flag, a message that is not a test alarm, or an incident that
  `countsAsRealUse`, never sees the checklist. That covers installs from
  before it existed and a user who finished setup.
- Home polls for the first message only while Home is the screen in
  front, no guide is up and the third row is open. One
  `FirstMessageWatcher` per topic, three topics at most, critical ones
  first. The watch is quick for a minute, then slows to one read a minute
  (`backsOffWhenQuiet`), and is quick again when Home comes back to the
  front. Topics beyond the three get one read each on a sweep, a few per
  sweep and at most every 30 seconds (`topicsToSweepForFirstMessage`), so
  a first message on any topic ticks the row.
- "In front" is `isHomeFrontScreen`: the router's location is `/` and the
  app is resumed. The route observer alone is not enough, because an
  alarm, the new-topic screen and the plans sit on the root navigator and
  another tab is not a push.
- The first look gives every topic of that time a baseline. A topic with
  no baseline was made later, so everything it holds counts
  (`countsFromStart`): a message sent from the topic page before Home
  polled it is the first message.
- A first look that fails is tried again after 15 seconds, doubling to 5
  minutes (`setupSeedRetryDelay`). Nothing is drawn until it succeeds.
- An install that owns a topic and finished setup before the checklist
  existed (`SetupChecklistStore.wasSetUpHere` is false) never sees it.
- `HomeSetupCubit.checklistDismissed` retires the checklist for good with no
  celebration. The card has no control that calls it, so nothing on Home
  does today.
- A row that turns true while Home is covered is held until Home is back,
  so the tick plays in view. When the last one turns in view,
  `setup_checklist_done` is saved first, then the card shows
  `setupFinishCard` (`3/3`, every pip full, a glad face, no button) under a
  short throw of confetti (none under reduce motion), and goes back to its
  kind for good. Leaving Home ends it.
- After that, on a later visit and once the Feature Guides offer was
  answered, the widgets card shows once at the top of the list sheet
  (`home_widgets_card_seen`), on iOS and Android only. Opening the how-to, going to the plans or closing it
  all count as seen. Its main button is the next thing that user can do:
  the how-to where widgets are unlocked, the plans where they need Pro (Pro alone unlocks widgets, on a server of the
  user's own too). The how-to steps have separate iOS and Android keys
  (`home_widgets.ios.*`, `home_widgets.android.*`).

The Feature Guide offer is raised after the frame in which the route
changed (`FeatureGuideHost._onRoute`). Raised earlier, the sheet sat on the
page that was leaving, went down with it, and was read as "not now". An
offer whose screen went away under it is not counted as declined.


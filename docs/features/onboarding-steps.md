# Setup steps

Moved out of AGENTS.md on 2026-10-17, text unchanged. Read before changing this area.

**Permission steps.** The permissions screen is one setup step that walks a
list of its own. `permissionSetupStepsFor`
(`lib/features/permissions/domain/entities/permission_setup_step.dart`)
returns the ordered list for a phone from values it is handed: the platform,
whether AlarmKit exists, and the phone's maker.

- iOS 26 or later: notifications, then AlarmKit.
- iOS 16 to 25: notifications, then the Time-Sensitive explainer.
- Android: notifications, then the full-screen alarm, then battery on a
  listed maker.
- Web and desktop: none.

`ReadPermissionSetupUsecase` builds that list and reads every step's status.
The flow engine's `permissions` check (`hasEveryPermission`) and the screen's
cubit both call it, so "every permission granted" has one definition. Nothing
is cached: the screen reads when it opens and every time the app comes back,
because a store can grant a permission at install.

A granted step is never drawn. The cubit has no current step until the
statuses are read, and the screen shows the waiting face until then.
`permissionStepsToRender` decides what one run draws: setup leaves out what is
granted, the screen opened from Health keeps only steps with a prompt left,
and a replay shows all of them.

The list on screen holds still once drawn (`freezePermissionSteps`): a later
read can pass over a step that became granted and can add a step at the end,
but never removes a dot or puts one in before the step on screen. The read
gives up after five seconds, so the screen never stays checking, and "Not now"
is on screen from the first frame.

Each step is a face, a title, one line, the drawn prompt and the button. A
drawn dialog has no hint under it; a drawn Settings switch keeps one. When
the user allows a step, its face is glad for one beat
(`PermissionStepView.grantedFace`) before the next step draws, and under
reduce motion there is no beat.

A step never says more than is true. The Time-Sensitive explainer shows only
once notifications are granted. No step carries a chip today. When the system will not show a notification
prompt again (`notificationPromptSpent`), the step opens Settings and draws a
switch instead of a prompt.

iOS and Android stay apart. Each step is its own enum value
(`iosNotifications`, `androidNotifications`), with its own view, strings
(`onboarding_permissions.ios.*`, `onboarding_permissions.android.*`) and drawn
prompt. To add a step for one platform:

1. Add a value to `PermissionSetupStep` and list it under that platform in
   `permissionSetupStepsFor`.
2. Read its status in `ReadPermissionSetupUsecase` and act on its button in
   `NotificationPermissionsCubit.allowCurrentStep`.
3. Add its strings under that platform's object in `en.json` and a view in
   `ios_permission_step_views.dart` or `android_permission_step_views.dart`.
   `permissionStepViewFor` will not compile until the step has one.

The battery step shows only on makers known to put background apps to sleep.
The list is `backgroundKillerMakers` in
`lib/features/permissions/domain/entities/background_killer_makers.dart`, the
only copy. `makerKillsBackgroundApps` compares it with both names Android
reports, through `DeviceMakerReader` (`lib/core/device/device_maker.dart`). To
see the step on an emulator, run a debug build with
`--dart-define=DEVICE_MAKER=samsung`. A release build ignores the flag.
Settings > Health keeps its battery row for every phone.

**First topic.** The create-topic screen is the `first_topic` step. On the
user's first topic (`isFirstTopicFor`: the shared list is ready and empty,
`CreateTopicState.isFirstTopic`) it draws two extra things:

- `FirstTopicCriticalCard` in place of the Critical delivery row. It is an
  `AppHighlightCard` around the switch, with the words picked by `RingClaim`.
  The switch starts off and only the user's tap turns it on. The card is one
  title and one line (`firstTopicCardCopy`), plus the plan line on the free
  plan. Its tone comes from `firstTopicCardTone`, the one place to change it:
  `choice` while off, `crit` once on, never `calm`.
- A row of tool chips (`ToolTemplate`). Outside setup (`FirstTopicLayout.wrapping`)
  they wrap above the name field. A chip fills the name only when the field is
  empty or still holds a name a chip put there. The chosen id is saved under
  `topic_tool_template.<topic name>` (`ToolTemplateStore`) once the topic
  exists. Nothing about it goes to the server. `ToolTemplate.other` has no
  chip: picking none means the same. `curl` is a tool with a chip, no
  suggested name and no snippet: its hook-up content is the curl line.

In setup the first topic reads the answer from the `use` step
(`FirstTopicLayout.answerFirst`, never a route parameter) and the form is laid
out in this order:

1. The name field arrives filled with the answer's name. The answer `other`
   leaves it empty with the example placeholder.
2. Under it, unless the answer is `other`, one line of name chips from the
   answer's table. A name chip always replaces the field.
3. One line of tool chips, ordered by the answer, with the answer's tool
   selected. The row scrolls sideways and fades at its right edge, and all
   six tools are in it. A tool tap replaces the name only when the field is
   empty or holds a name an earlier chip or the answer filled; a name the
   user typed is never replaced.
4. The Critical delivery card and the Create button as above.

Later topics keep the plain screen.

In setup the screen is one step (`CreateTopicCubit.isOneStep`, set whenever
the screen is given `onDone`). The pinned button creates the topic from the
first step. There is no token-name step: the token is named after the picked
tool (`setupTokenName`), or by the server when no tool is picked. There is no
created stop either: the topic drops as a row into a small picture of Home
(`TopicMadeBeat`, about 1.2 seconds, a tap skips it, still under reduce
motion) and the screen moves on, because the hook-up step shows the address
and the token where they are used. A replay makes no topic and shows no
picture. It shows no ask, the Cloud ask included. Opened from Home, the
screen keeps its two steps and its created state, whatever the topic count.

When finishing a step ends setup, `finishOnboardingStepInEngine` raises
`setupFinishSignal` with the topic setup made, and the Home that opens next
takes it and glows that row once (`SetupGlow`). The signal is in memory
only, so a later launch never glows. A replay, a "Set this up later" exit
and a run with no topic raise nothing. The rules and times are in
`lib/features/topics/domain/setup_finish_glow.dart` and
`topic_made_beat.dart`.

A setup run also fills `FirstTopicHandoff` (registered in `get_it`) when the
topic is made: the name, server URL, template id and publish token. The entry
lives in memory only, because the server never shows the token again. The
topic name is also saved as `onboarding_first_topic`, so a resume after a
kill knows which topic setup made. `CompleteOnboardingUsecase` clears both.
A replay and a screen opened from Home hold nothing. The id of the token
(never the token) is saved under `onboarding_hook_up_token_id` too: setup
does not show that token until the hook-up step, so if the app dies first,
hook up takes it back before it makes another. The server address handed on
falls back to the saved connection when the screen had not loaded it yet.

**Real ring.** The `real_ring` step asks the server to send the test alarm:
`POST /v1/test?topic=<name>`, then the push, then the real alarm screen. The
screen is `real_ring_screen.dart`, the logic is `RealRingCubit`, and the
rules are pure functions in
`lib/features/onboarding/domain/real_ring/real_ring_rules.dart`.

- The checks run when the step opens and on every tap (`realRingGateFor`).
  No server and Critical off are known before the call, so neither one
  calls the server. A 409 that arrives anyway shows as Critical off.
- Critical delivery is the user's to turn on. `setCritical` is the only
  path to `UpdateTopicUsecase`, and only the switch on the card calls it.
- The topic is the one setup made (`setupTestTopic`): the name in
  `FirstTopicHandoff`, then the saved name, then the first topic in the
  shared list.
- After a 200 the phone gets 20 seconds (`realRingPushWait`). The wait ends
  when the alarm for that incident reaches this phone. `AlarmArrivals` is
  where that comes from: an alarm push the running app received, an alarm
  the phone scheduled, a tapped alarm notification. It never asks the
  server, because the server holding an incident says nothing about this
  phone ringing. Coming back to the app, and a cold start, ask the phone
  (`isUp`).
- The incident ids are saved by `SetupTestRing`. The alarm can start the
  app from cold, and the acknowledged screen still has to know the incident
  was the setup test. `incidentId` (`onboarding_real_ring_incident`) is the
  newest, which the step after the ring reads. `incidentIds`
  (`onboarding_real_ring_incidents`) is every test of the run: Try again
  sends a second one and the first can still ring late, so each counts.
  `CompleteOnboardingUsecase` clears both.
- A push from the server that lands while the phone-only countdown runs
  cancels the phone's own alarm, so only one rings.
- Only a push that rings counts as an arrival: priority 5 `open`, `repeat`
  or `reopen`. Android decides in `PushRouter.route`, iOS in
  `AlarmScheduleRule.ringingIncidentId`. An ack, a close, a forward and a
  ring held by quiet hours name no incident.
- The fallback is the alarm the phone sets for itself, `LocalTestAlarm`,
  the only copy of that logic. It starts from the user's tap and from
  nothing else, and the screen calls it a test of this phone only. The
  `legacy_test` step runs the same class as its test.
- iOS and Android stay apart: `realRingCopyFor` returns the instruction
  lines and the check list from `onboarding_real_ring.ios.*`,
  `onboarding_real_ring.ios_time_sensitive.*` and
  `onboarding_real_ring.android.*`. Words about silent mode come from
  `RingClaim`.
- The tap does not send at once. It starts a count of `realRingSendDelay`
  (5 seconds, the one constant, and zero turns the wait off) so the user
  can lock the phone. `SendCountdown`
  (`lib/features/onboarding/domain/real_ring/send_countdown.dart`) holds
  the rule: the server is asked when the count ends, Cancel sends nothing,
  and the app leaving the front (`hidden` or `paused`) sends at once on
  both platforms, because a timer is not promised to run in the
  background. A tap whose checks finish with the app already hidden sends
  with no count. `inactive` alone never sends
  (`RealRingCubit.appLifecycleChanged`). The checks run before the count starts, and a server that
  goes away during it ends the count unsent.
- While it counts the screen shows `TypedCurlTerminal`, the same
  `CurlTerminalCard` the How it rings story draws. It types
  `CurlLine.forTerminal`: the user's server and topic, `Priority: urgent`
  and a masked `tk_…`. That function takes no token. One line under it
  says the server sends this test for them.
- A problem is a short title and at most one plain line (`RealRingReason`)
  on a `SetupProblemCard`, the one widget every problem and wait in setup
  uses (real ring, hook up, the setup gate). Its action is in the card.
  The face over it fits the problem: `sad` for a server or topic that is not there
  yet, `skeptical` for Critical delivery off, `confused` for a test that
  timed out, `worried` for a failure.
- The Critical card on this step carries the same free-plan line as on the
  first topic (`criticalPlanFor`, from `readCriticalLimit`).
- A replay sends nothing: the button moves on to the next step.
- The server fixes the test alarm's title and message, so the sample for the
  user's answer shows on the alarm screen from local state
  (`setupSampleFor`, applied where `CriticalAlarmCubit` sets the incident's
  title and body). It applies only to the setup test the server sent: the
  title is the answer's sample message and the body is a short line saying it
  is what a real one looks like. A real incident, the first tool alarm, a
  Settings test, the phone-only test and an `other` answer keep the server's
  text. The OS notification and the text cached for the iOS extension stay as
  the server sent them, so the lock screen shows the server's text.

**After the ring.** The acknowledged screen says what the alarm proved
(`setupTestKind`: server-sent, phone-only, or not a test) as a list of
ticks (`setupProofFor`, drawn by `ProofList`): three for a server-sent
test, and one for the phone-only test with the server and the push shown
as not tested. It picks its buttons with `ackedExitsFor`. A test is matched by incident id only, never
by a topic name. In a setup run on a flow that has `real_ring`
it shows one Continue button, which calls `finishOnboardingStep` and never
completes setup itself: the engine does, when no step is left. `legacy-1`
keeps its two buttons and completes setup from them. A test run again after
setup ends on one Finish button.

The setup test's acknowledged screen ("It works") stays calm only when the
offer follows and the store said the product is on sale (`OfferOutlook.coming`).
It asks the offer gate (`outlook`) once, reads the cached store answer without
waiting, builds nothing until that answer is in, and throws its confetti and
plays its success haptic a few frames late for every other answer: no offer,
the store said nothing is on sale, or the store has not answered yet. So a
session is never left with no celebration. The one case where the two differ:
the store answers after "It works" opened, so the confetti flies and the offer
still shows. The face ripple stays either way. The first tool alarm keeps its
confetti.

Setup never closes, silences or walks away from a real alarm. Continue on a
server-sent test calls `CriticalAlarmCubit.closeSetupTests(id)`, which does
nothing unless that id is the incident on screen and a stored setup test.
It ends every test of the run through `EndSetupTestUsecase` (acknowledge if
needed, close, one retry), and answers false when a real alarm took the
screen over meanwhile, in which case the screen stays on that alarm. A test
left acknowledged would ring again from its desk timer as a real alarm, so
a close that still fails moves the id to `unclosedIds`
(`onboarding_real_ring_unclosed`): it stops counting as a setup test, and
`closeLeftovers` closes it the next time the app opens.

The alarm the first hook-up message sets off is `AckedExits.firstToolAlarm`.
It is a real incident and rings with every control. Its acknowledged
screen is the setup one: three ticks (`firstToolAlarmProof`) and one Finish
button. Setup is already complete by then, so Finish only closes that one
incident (`CriticalAlarmCubit.finishFirstToolAlarm`, through
`EndSetupTestUsecase`) and goes Home. If another alarm has the screen,
Finish does nothing.

The id alone never decides it. The server keeps one id for an incident's
whole life: a later message joins it and its desk timer reopens it. So the
phone keeps a record (`SetupTestRing.firstTool`, the
`onboarding_first_tool_*` keys): the id, when hook up heard it, the
`opened_at` and `last_message_at` the alarm screen first saw, and whether
it was acknowledged. `firstToolVerdictFor` checks every incident the alarm
screen shows against it, and the record is forgotten the moment the
incident reopens, takes in another message or closes. It is also forgotten
by Finish, by Done on the hook-up step, by Set this up later, and at the
next launch after the first acknowledgement
(`settleFirstToolAtLaunch`). Forgotten, the incident gets the normal
screen with every control. When in doubt the answer is the normal screen.

The normal acknowledged screen shows two buttons at most: At my desk while
the desk timer runs, over a paper Back to topics. The topic name under the
title is a pill and the one way to the topic. The screen keeps the
acknowledged colours after At my desk. Its face shrinks on a short phone
so the details card sits above the pinned buttons, and at a large text
size the hint moves into the list.

Every "Set this up later" exit calls `SetUpLaterUsecase`, which completes
setup, and completes nothing on a replay.

**Hook up your tool.** The `hook_up` step is `hook_up_screen.dart` with
`HookUpCubit`. Done on it finishes the step, and the engine completes setup
because no step is left.

- The curl line comes from `CurlLine.build` with `priority: CurlLine.urgent`,
  so it rings a critical topic. Callers that leave `priority` out get the
  line without the header, which is what the topic page shows. The message
  and the address are single-quoted for a shell (`CurlLine.shellQuote`).
- The token is the one in `FirstTopicHandoff`, in memory only. When it is
  gone (the app was killed since the topic was made) the cubit makes one
  new named token and holds it. The id of that token, never its value, is
  saved under `onboarding_hook_up_token_id`, and the next cold start
  deletes that token on the server before making another.
  `HookUpState.toString` leaves the token out.
- Only the topic setup made is used. With no saved name, or a name the
  server no longer has, the screen shows its no-topic state and makes
  nothing. For a user who already completed setup the step does nothing.
- `ToolSnippet.build` returns what to give the tool picked on the first
  topic: code to paste (cron, CI, Home Assistant) or the fields of the
  tool's own form (Uptime Kuma, Healthchecks). The CI snippet reads the
  token from a secret and never holds it. Field labels are the tool's own
  words and stay in English.
- Layout follows the tool saved on the topic, not the answer. Uptime Kuma,
  Healthchecks and Home Assistant are the three tools with documented steps
  (`toolStepsFor`), and they get the steps layout (`HookUpStepsLayout`): a
  `Hook up` label, the tool name as the title, a white sheet of numbered
  steps with the tool's fields or code inside it, a row of chips (Copy URL,
  Copy token, curl), the waiting card and Done. It has no face. The address
  and token are masked where they are only looked at and whole when copied.
  The curl line is one tap away under the chips. Every other tool, and no
  tool, keeps the curl screen: the face, the curl block with the tool's
  snippet after it. For the `jobs` answer that screen carries one line under
  the curl block about where a job sends it.
- The last step follows the topic's Critical switch. `toolStepsFor` takes
  `isCritical`: on keeps "This phone rings.", off or not known says "It lands
  on this phone." A topic with Critical off does not ring. The switch is
  `HookUpState.isCritical`, the one the `critical_off` note reads. It is
  in the first frame because `FirstTopicHandoffEntry.isCritical` carries what
  the topic was made with, and the topic list read has the last word.
- The waiting card's line follows the saved tool when it has documented
  steps, and the answer's line otherwise (`waitingLineFor`).
- `FirstMessageWatcher` (`lib/features/topics/domain/first_message/`) polls
  the topic every 5 seconds while its screen is open and the app is in
  front, and backs off to a minute when the server cannot be asked. Where
  it starts is the server's answer, never the phone's clock: the first
  poll reads everything (`since=all`) and saves the newest message id
  under `first_message_since.<topic>`. An empty topic saves `all`, so its
  first message counts. A message after that point that is not a test
  alarm is the first message. It sees message ids only, and never moves
  the `MessageSyncService` cursor.
- A test alarm never ticks the row: `ApiFirstMessageSource` leaves out any
  message with the test route's title, from setup or from Settings.
- `FirstMessageStore.isReceived` (`first_message_received`) is set once and
  never cleared. Deleting a topic drops that topic's starting point and
  keeps the flag.
- `FirstMessageRow` draws the row from one boolean. It holds no state.
- When the curl line sets off an alarm, the alarm reaches the phone before
  a poll would. The cubit hears it through `AlarmArrivals` and counts it
  only when the incident is on this step's topic and is not a setup test
  or the phone-only test. Then the row turns, the screen finishes the step
  and opens the alarm screen, because a ringing phone needs its stop
  control. `HookUpLeaving` holds the rule that Done and the handover never
  both run.
- `SetupStatsConsent` is the analytics switch. A tap either way saves the
  same choice Settings > Privacy does. A switch nobody touched writes
  nothing. It does not stamp the Home consent ask: that sheet also offers
  crash reports, so it still gets its turn. The setup funnel hears the answer
  through the privacy repository (see `docs/features/onboarding-analytics.md`).
- A replay shows made-up values and reads, sends, makes and saves nothing.
  In a developer build `?show=<state>` and `?tool=<id>` put it on a state
  (`HookUpScreen.replayStateNames`); Developer options lists them.


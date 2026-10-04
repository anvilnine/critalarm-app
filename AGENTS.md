# Crit Alarm: rules for every agent

You are building Crit Alarm. Read, in this order, before touching code:
1. docs/api.md          is the contract. Build to this. Never edit it inside a task. (In the app and site repos it is a generated copy; the source is critalarm-server/docs/api.md.)
2. docs/ARCHITECTURE.md is how the pieces fit and the folder layout.
3. The task file you were given. It is self-contained; it includes the product commitments that apply to you.

Commitments made to Apple that no task may break: critical delivery defaults OFF per topic; every topic has a token; the app never generates alerts and never inspects content; the alarm stops on acknowledge; the user can disable critical delivery per topic or in Settings.

## Non-negotiables
- Critical delivery on a topic defaults to OFF. Never change this default.
- Every topic has a token. There are no public topics.
- The `incident` package does not import from `push` or `relay`. It emits events.
- Timers are database rows, never in-memory only.
- Do not add features not in your task. If you think one is needed, write it in the PR description under "Suggested follow-ups" and stop.
- Do not invent API routes, fields, or headers. If api.md does not cover what you need, stop and report; do not guess.

## Tests
- Unit tests only. No widget tests, no integration tests, no e2e.
- Server: every state transition in the incident machine has a test using a fake clock. Every ntfy header alias has a test. Every error code in api.md §1.8 has a test.
- App: unit-test models, the API client against the mock server, and any pure logic. Do not test widgets.
- UI is verified by screenshot. Attach one to the PR for any screen you touch.

## Code
- TypeScript strict. No `any`. Node 22.
- Flutter: follow the design system in the repo. Cubit/Bloc, go_router, freezed, as the template does. Do not introduce a state-management library.
- Astro: follow the template. No new frameworks.
- Small commits with plain messages. One task = one branch = one PR.

## Definition of done
- The acceptance list in the task file passes.
- `npm test` / `flutter test` / `npm run build` passes.
- PR description has: what was built, how to verify it by hand, screenshots for UI, suggested follow-ups.
- Nothing outside the task's file scope was changed. If you had to, say why.
- Changelog entries added with cider where the change calls for one (see Changelogs below, in the critalarm-app section).

## Running under /goal
- Your task file ends with a `/goal` line. That line is your stopping condition. Nothing else is.
- The evaluator judges from what you show in the transcript. After every meaningful step, paste the command you ran and its output: test summary, `git diff --name-only`, build result. Work you did not show did not happen.
- Do not declare done. Show the evidence and let the evaluator decide.
- If you hit the turn cap without meeting the condition, write BLOCKED.md with what remains and stop.

## When stuck
Write what you tried and what blocked you in the PR or a `BLOCKED.md` in the task folder. Do not work around a blocker by changing the contract or another package.

---

## This repo

`critalarm-app`. Public, GPL-3.0. The Flutter app, and later one native Swift
target for the iOS Notification Service Extension.

**Stack.** Flutter 3.44.9 (pinned in `.fvmrc`, use `fvm`), Dart 3.12. Cubit and
Bloc for state, `go_router` for navigation, `freezed` for models, `get_it` for
the composition root, `easy_localization` for strings. Do not add another
state-management library.

**Commands.** Every one of these goes through `fvm`.

| What | Command |
|---|---|
| Test | `make test` (`fvm flutter test`) |
| Analyze | `make analyze` (`fvm flutter analyze`) |
| Codegen | `make gen`, then `make l10n` |
| Layer check | `make check-layers` |
| Refresh the contract | `make sync-contract` |
| Run with a quiet alarm | `make run-quiet DEVICE=<id>` (dev only, never ships) |
| New worktree | `make worktree-new NAME=<slug>` |
| Worktree status | `make worktree-list` |
| Drop merged worktrees | `make worktree-clean` |

**Work in a worktree, one per task.** `make worktree-new NAME=search-overlay`
creates `worktrees/search-overlay` on branch `task/search-overlay` off `main`, so
two agents never fight over `HEAD`. A fresh worktree does not compile until
`pub get`, `make gen` and `make l10n` have run, so `.claude/hooks/worktree-prep.sh`
runs all three in the background and drops a `.worktree-ready` marker when it can
build. `make worktree-list` shows what is still open; `make worktree-clean` removes
only the worktrees that are clean and already merged. Details in
`worktrees/README.md`.

**Most generated files are git-ignored.** `*.g.dart` and `*.freezed.dart` are not
in the repo. FlutterGen's `lib/gen/*.gen.dart` is the exception and is committed,
because it is derived from `pubspec.yaml` rather than from source. After a clone, run `make gen` and `make l10n` or nothing compiles.
`lib/gen/locale_keys.g.dart` comes from easy_localization's own generator, not
from build_runner, so `make l10n` is a separate step and skipping it breaks
every `LocaleKeys` reference.

**Run `make gen` after every merge that touched an annotated source file.**
Because the generated file is ignored, git never updates it, so a merge can
leave new source next to an old `.g.dart`. It shows up as every widget test
failing to load with `Error: Member not found`, which reads like a broken merge
and is not one. Seen on 2026-09-18: a branch renaming a field in
`lib/core/env/env.dart` was green on its own and put 9 tests on the floor the
moment it reached `main`, because `env.g.dart` in the working copy still held
the old field. One `make gen` fixed all 9.

**Folder layout** (ARCHITECTURE §12):

```
lib/features/<name>/ one folder per feature, 13 today (`ls lib/features`)
ios/CritAlarmNSE/    Swift. fetch + mutate the notification.
ios/Shared/Alarm/    Swift. AlarmKit alarm and the acknowledge card.
android/             full-screen intent channel config
```

Each feature is `data/domain/presentation`, and `tool/check_layers.sh` enforces
the direction: core must not import features, domain must not import data or
presentation.

**Glossary.** Three features share a screen and used to share words. Use these
names in code, strings, comments and PRs, and never one for another.

- **Feature Guides** (`lib/features/feature_guides/`): the per-screen spotlight
  walkthroughs. Each screen plays its guide once; Settings › Feature Guides
  replays them all. Formerly "tour" and, before that, "showcase". The prefs keys
  `tour_guides_seen` and `has_completed_showcase_tour` keep their old names
  because devices already hold them.
- **In-App Notices** (`lib/features/in_app_notices/`): the one non-blocking
  card or pinned bar on Home: no server connected, setup health, Pro ending,
  back up your topics. A notice sits on the screen until its condition clears
  or the user dismisses it. An **ask** is different: an interruptive sheet or
  popup (the Pro ask, the consent ask, the Local reminders sheet, the store
  review), governed by `HomeAskRules` and `SetupGate`. Never call a sheet a
  notice. Formerly "home prompts"; the `home_prompt_*` prefs keys and the
  `pro_prompt_answered` analytics event keep their names.
  The setup checklist and the widgets card are neither: they are Home
  content, drawn at the top of the list sheet by `HomeSetupSection` from
  `HomeSetupCubit`, and they do not go through the notice slot or
  `SetupGate`. See "Home setup content" below.
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
  steps is a flow (see "Setup flow engine" below). In the default flow the
  first topic is created before the test alarm, and the server sends that
  test alarm (see "Real ring" below). The
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

**This app also builds for web.** The dashboard is this codebase run through
`flutter build web` (ARCHITECTURE §2). Four rules keep that cheap:

- Ask the capabilities service (`canRegisterPush`, `canRunAlarm`, `canImportSounds`, `canComposeMessages`), never `kIsWeb` or `Platform.isIOS` inline; it answers per platform, so web gets no push, no alarm, yes compose.
- A screen that exists on one platform only is its own route gated by a capability, never a widget hidden behind a boolean: the message composer is web only, the permissions screen is mobile only.
- Shared widgets take no platform-specific dependencies.
- Layout breakpoints come from the design system, never from the platform.

**Setup flow engine.** The order of the setup steps is data. A flow is an id
plus a list of step ids, for example
`{"id": "2026-10-a", "steps": ["welcome", "how_it_rings", "connect"]}`. The
code is in `lib/features/onboarding/domain/flow/` (flow, validator, sources,
engine) and `lib/features/onboarding/presentation/flow/onboarding_step_registry.dart`
(the steps).

To add a step:

1. Add an id to `OnboardingStepId`. Ids are saved on phones, so a shipped id
   never changes.
2. Add an `OnboardingStepEntry` to `OnboardingStepRegistry.entries` with:
   - `route` and `routeName`, and `screen`, the widget that route builds. The
     router makes one route per entry inside the onboarding `ShellRoute`, so
     there is nothing to add in `router.dart` except the `AppRoute` name.
   - `isAvailable`: whether the step exists on this phone. It gets the
     platform as values (`OnboardingPlatform`). No `Platform.isIOS`, no
     `kIsWeb`.
   - `isSatisfied`: whether the step is already true for this user, read
     through `OnboardingStepFacts`. Local reads only, because launch waits on
     it. Leave it out for a step that only counts once the user finishes it.
   - `requires`: step ids that must come earlier in any flow that lists it.
   - `ambientStep`: the `OnboardingAmbientStep` the canvas shows on that
     route. `onboardingStepForPath` reads it from the entry.
3. When the user is done with the screen, call
   `finishOnboardingStep(context, OnboardingStepId.yourStep)`. A screen never
   names the step after it.
4. List the id in a flow. `BundledOnboardingFlows` holds the two that ship:
   `2026-10-a` (the default) and `legacy-1` (the first shipped order).

An entry with no route is known to the validator and never shown. None is
like that today.

An entry that requires `connect` is covered by the shell while no server is
connected. `handlesMissingServer: true` turns that off for a step that has
its own state for it: `real_ring` and `hook_up` today.

`hook_up` is the last step of the default flow. It exists on iOS and
Android, and counts as already done once a first message was received.

`widgets` is an optional step. The default flow leaves it out and `legacy-1`
lists it. It works at any position, the last one included, and it exists on
iOS and Android only.

Where a flow comes from, highest priority first: the developer settings
override, the remote value, the bundled default. Each is an
`OnboardingFlowSource` registered in `lib/app/di.dart`. A source answers with
what it has in hand and never waits. `OnboardingFlowEngine.chooseFlowWithOrigin()`
says which one won (`OnboardingFlowOrigin`: developer, remote, bundled).

The remote source is `RemoteOnboardingFlowSource`. It reads the Remote Config
key `onboarding_flow` through `TelemetryGate.onboardingFlowJson`, which
returns what is already activated and never fetches. The default is an empty
string, which means no remote flow. The value is the same JSON as a bundled
flow, and only `id` and `steps` are read. It is rejected before the validator
sees it when:

- the text is empty or is not JSON;
- `id` is missing or is not 1 to 40 characters of letters, digits, `.`, `_`
  or `-` (it becomes an analytics parameter);
- `steps` is missing, is not a list, or holds anything but strings.

A remote flow applies only to installs that have not tapped Get started yet.
A value that arrives later changes nothing for a user who is already pinned.
A build without Firebase config uses the bundled flow.

Every source passes `validateOnboardingFlow`:

- An unknown step id is dropped.
- A duplicate id keeps its first position.
- `welcome` not first, a step listed before one it requires, or a required
  step missing: the whole flow is rejected and the next source is asked.
- Nothing left after the drops: rejected too. The bundled default is the
  last source, so that is where it ends.

A flow decides order and inclusion only. Copy and defaults such as Critical
OFF stay in code.

Pinning: the flow is chosen once, when the user taps Get started on
`welcome`, and saved (`onboarding_flow_id`, `onboarding_flow_steps`). A
source that changes later applies to the next fresh install, never to a run
in progress. Finished steps are saved in `onboarding_flow_completed`.
`CompleteOnboardingUsecase` clears all three.

Resume: no position is saved. The next step is the first one in the pinned
list that is available, not completed and not satisfied. With nothing pinned
the app opens `welcome`. With no step left, setup is complete.

The replay flag: Settings opens the flow with `?demo=true`. On a replay
nothing is saved or pinned, no step is skipped for being satisfied, the flag
carries on to the next route, and the connect step moves on without
connecting. `isOnboardingReplay(context)` reads the flag.

After setup: two setup screens are also opened on their own, by
`OnboardingEntryPoint.connectServer` (Server settings, the no-server card on
Home) and `OnboardingEntryPoint.testAlarm` (Health). Once setup is complete,
`finishStep` saves nothing and pins nothing, and the screen closes back to
whatever opened it. A user who connects late lands back where they were,
connected, never in setup.

A pinned flow is checked again every time it is read. Unknown ids are
dropped, and a list the validator rejects (empty, or nothing known left) is
replaced by the bundled default with the completed steps kept.

Background connect: Continue with Crit Alarm Cloud finishes the `connect`
step at once. `BackgroundConnect`
(`lib/features/onboarding/domain/connect/background_connect.dart`, one object
for the whole app run, registered in `lib/app/di.dart`) does the work behind
the user: `GET /v1/info`, the device registration, then saving the
connection.

- The pending connect is saved under the prefs key `connect_intent_v1`. It
  holds the server address and the retry time, and no token. It is not part
  of the onboarding draft and it is not a saved connection, so Home never
  reads it as "a server exists".
- It retries on a timer (every 15 seconds, backing off to 5 minutes), on
  resume, on launch, when the push token arrives, and when the permissions
  step is finished. The timer stops once the connect lands or gives up.
- No network and no push token yet are waits. A server version the app does
  not know, or an answer a retry will not change, is a failure: the intent
  is cleared and nothing retries.
- The intent is also cleared when the user disconnects or connects to a
  server by hand. Disconnecting cancels the pending connect first and
  clears the connection second.
- The `connect` step counts as done only while a connection is saved or a
  connect is pending. A failure or a cancel takes it out of the completed
  steps (`OnboardingFlowEngine.reopenStep`), so a relaunch resumes at the
  connect step.
- A 429 from the device registration is the device cap, a failure with its
  own line. A 429 from `/v1/info` is the rate limit and is retried.
- A failure is forgotten when setup completes or the user leaves through
  Set this up later.
- The privacy line reads `ServerInfo.statedRelayContent`, which is null when
  the answer had no `relay_content`. `relayContent` keeps its `none`
  default for the rest of the app.
- The result shows as step content, never as a notice or a notification.
  `OnboardingStepGate` (in `onboarding_shell.dart`) wraps every step route.
  A step whose registry entry requires `connect` shows `AppWaitingFace` and
  one line until the connect lands. A failure shows on whichever step is
  open, with one button back to the connect step. A step that requires
  `connect` with nothing pending and no saved connection shows the same
  gate. Other steps show a short
  status in the top corner of the shell. `connectGateFor` holds the rule.
  A step that draws something in that corner (the permission step dots)
  asks `OnboardingAmbientScope.hasQuietLineOf` and gives the corner up
  while the status is there.
- A later step asks `getIt<BackgroundConnect>().state`: `isPending`,
  `isConnected`, `isFailed` with `failure`. `stream` carries every change.
- A server typed by hand connects in the foreground, on the connect screen.

Developer settings: a build made with `--dart-define=SKIP_PAYWALL=true` or
`--dart-define=PAYWALL_LAB=true` shows a setup section in Developer options
(`developer_setup_section.dart`). Its controls:

- Flow: pick no override, a bundled flow, or Custom. Custom takes comma
  separated step ids and shows what the validator did (ids dropped, ids
  repeated, the final order, or why the list was rejected). A rejected list is
  never saved and the previous choice stays. The choice is saved in
  `dev.onboarding_flow`. It fills the `developerOnboardingFlowSource` slot, so
  it outranks the remote value and still passes the validator.
- Redo onboarding: replays the flow that would run now (`?demo=true`) and
  names its id.
- Open a step: every registered step, opened as a replay. A step that is not
  on this phone, or has no screen yet, is listed greyed with the reason. A
  replay of the permissions step takes `?skip=<n>` to open on a later step
  (`OnboardingPermissionsScreen.replaySkipParam`).
- Count as not done: one switch per step that has an `isSatisfied` check
  (`forceableOnboardingSteps`), saved in `dev.onboarding_forced_unsatisfied`.
  A forced step is the resume point even when its check says it is done, and
  the permissions screen shows its steps (`replayForDemo`).

A store build is compiled with `NoDeveloperOnboardingOverrides` and the empty
developer slot (`buildHasOnboardingDeveloperTools` is a compile-time
constant), so it ignores both keys even when they are set.

A replay changes nothing real: no flow state, no topic on the first-topic
step, and no connect form draft (`onboarding_replay_rules.dart`).

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
- A row of tool chips (`ToolTemplate`) above the name field. A chip fills the
  name only when the field is empty or still holds a name a chip put there.
  The chosen id is saved under `topic_tool_template.<topic name>`
  (`ToolTemplateStore`) once the topic exists. Nothing about it goes to the
  server. `ToolTemplate.other` has no chip: picking none means the same.

In setup the screen is one step (`CreateTopicCubit.isOneStep`, set whenever
the screen is given `onDone`). The pinned button creates the topic from the
first step. There is no token-name step: the token is named after the picked
tool (`setupTokenName`), or by the server when no tool is picked. There is no
created stop either: the face is glad for one beat and the screen moves on,
because the hook-up step shows the address and the token where they are
used. It shows no ask, the Hosted ask included. Opened from Home, the screen
keeps its two steps and its created state, whatever the topic count.

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
- A problem is a short title and at most one plain line (`RealRingReason`),
  under a face that fits it: `sad` for a server or topic that is not there
  yet, `skeptical` for Critical delivery off, `confused` for a test that
  timed out, `worried` for a failure.
- The Critical card on this step carries the same free-plan line as on the
  first topic (`criticalPlanFor`, from `readCriticalLimit`).
- A replay sends nothing: the button moves on to the next step.

**After the ring.** The acknowledged screen says what the alarm proved
(`setupTestKind`: server-sent, phone-only, or not a test) and picks its
buttons with `ackedExitsFor`. A test is matched by incident id only, never
by a topic name. In a setup run on a flow that has `real_ring`
it shows one Continue button, which calls `finishOnboardingStep` and never
completes setup itself: the engine does, when no step is left. `legacy-1`
keeps its two buttons and completes setup from them. A test run again after
setup ends on one Finish button.

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
  through the privacy repository (see "Setup funnel events").
- A replay shows made-up values and reads, sends, makes and saves nothing.
  In a developer build `?show=<state>` and `?tool=<id>` put it on a state
  (`HookUpScreen.replayStateNames`); Developer options lists them.

**Setup funnel events.** Each setup step sends two analytics events,
`onboarding_step_viewed` and `onboarding_step_completed`. Each has three
parameters and no others: `step` (a step id from the registry), `flow_id`
(the flow the user is in) and `ms_since_previous` (whole milliseconds since
the previous step event in this app run, 0 for the first one). No content,
topic name, URL, token or device id ever goes in them. `OnboardingFunnel`
(`lib/core/telemetry/onboarding_funnel.dart`) sends them, fed by
`OnboardingFlowEngine.onStepEvent`, so screens make no calls of their own.
The names live in `AnalyticsEvents` and the wrapper is `OnboardingAnalytics`.

The consent question comes on the last step, so events wait on the phone
until the user answers:

- No answer yet: each event is added to the prefs list
  `pending_onboarding_events`. Nothing is sent and no analytics call is made.
- Opt in (the setup switch, Settings > Privacy or the Home consent sheet,
  whichever comes first): the waiting events go through
  `TelemetryGate.logEvent` once, in order, and the list is deleted. Later
  events go straight to the gate.
- Opt out, or analytics switched off again: the list is deleted and nothing
  is sent. On the Home consent sheet, Not now counts as opting out.
- No answer for 7 days after the first event: the list is deleted and no more
  events are held for this install. The age is checked at app launch and
  whenever an event is added.
- The list holds at most 100 events. When it is full a new event is dropped
  and the old ones stay as they are. A list that does not read back exactly as
  written is deleted, never sent.
- A replay (`?demo=true`, developer "Redo onboarding" and "Open a step") records
  nothing. Neither does a setup screen opened after setup is complete.
- `flow_id` must match `[A-Za-z0-9._-]{1,40}` and `step` must be a registry id,
  or the event is dropped.

Every answer is saved through `ObservedPrivacyRepository`, which tells the
funnel. A new way to answer needs no code of its own as long as it saves
through `PrivacyRepository`. The funnel keeps who answered what under
`onboarding_funnel_state` (`in`, `out` or `expired`), because
`privacy_analytics_enabled` reads false both for "never asked" and for "said
no".

**Real use.** Setup rings the phone on purpose, so those alarms are not
the user's own use of the app. `countsAsRealUse`
(`lib/features/incidents/domain/real_use.dart`) is the one decision: false
for a test setup asked the server for, for the alarm the first hook-up
message set off, and for the phone-only test. `SetupTestRing.setupIncidentIds`
(`onboarding_setup_incidents`) keeps those ids after setup completes,
because the acknowledgement often comes later. Three places read it:

- The alarm screen: an acknowledgement that is not real use stamps no
  last-acknowledged time and opens no sheet.
- `HomeAskRules`' newest acknowledgement (`newestRealAckedAt`), which the
  rating ask and the Local reminders sheet on Home wait for.
- `LocalReminderInputsReader`, where such an incident counts as a test for
  the fire drill and morning-after rules.

`EndSetupTestUsecase.closeLeftovers` does not close a leftover test
incident that now holds a message of the user's own. It drops it from the
list and leaves it for them to answer.

**Home setup content.** A user who left setup early gets a checklist at
the top of the Topics list sheet. The rules are pure functions in
`lib/features/topics/domain/setup_checklist.dart`, and `HomeSetupCubit`
runs them from the list Home drew.

- Three rows: a server is connected, a topic has Critical delivery on, a
  first message arrived (`FirstMessageStore.isReceived`). The third row is
  `FirstMessageRow`, the same one the last setup step uses, drawn bare. The
  rows have no stroke of their own: the checklist is one cream block, so it
  is no heavier than the topic rows under it.
- It shows only over a list that loaded, and stays until all three are
  true. With no server nothing is drawn: the no-server card has that row.
  With no topics it stands in for the empty card.
- A row only opens a screen (`setupChecklistRoute`). Nothing here turns
  Critical delivery on.
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
- The close control on the checklist retires it for good with no
  celebration (`checklistDismissed`).
- A row that turns true while Home is covered is held until Home is back,
  so the tick plays in view. When the last one turns in view,
  `setup_checklist_done` is saved first, the tick plays, then the rows
  become one finished line with a short throw of confetti (none under
  reduce motion), and it goes for good. Leaving Home ends it.
- After that, on a later visit and once the Feature Guides offer was
  answered, the widgets card shows once (`home_widgets_card_seen`), on iOS
  and Android only. Opening the how-to, going to the plans or closing it
  all count as seen. Its main button is the next thing that user can do:
  the how-to where widgets are unlocked, the plans where they need Hosted. The how-to steps have separate iOS and Android keys
  (`home_widgets.ios.*`, `home_widgets.android.*`).

The Feature Guide offer is raised after the frame in which the route
changed (`FeatureGuideHost._onRoute`). Raised earlier, the sheet sat on the
page that was leaving, went down with it, and was read as "not now". An
offer whose screen went away under it is not counted as declined.

**Changelogs.** Two files, both written with cider, never by hand. The
how-to is the `changelog` skill: `.claude/skills/changelog/SKILL.md`.

- `CHANGELOG.md` is for users. Add a line only for a change a user would
  notice and care about: a new feature, a change in what the app does, a fixed
  bug they could have hit. It feeds the store "What's new" text.
- Leave small UX polish out of `CHANGELOG.md`: spacing, colours, wording
  tweaks, a moved button, a nicer empty state. Those go in
  `dev-notes/CHANGELOG.md`, with refactors, new tokens and components, prefs
  keys, build flags, tooling and test changes.
- Add entries with `make log TYPE=<added|changed|fixed|removed|deprecated|security> MSG="..."`
  or `make devlog TYPE=... MSG="..."`. One line per entry, no hard wraps,
  plain words, no em dashes. Write user entries from the user's side ("History
  keeps 90 days on Hosted"), not the code's.
- Add the entry in the same branch as the change. When branches merge, keep
  both sides' lines.
- This repo is public. Neither file names prices, keys, task numbers or
  planning documents.
- At release, after the version bump, `make changelog-release` moves
  Unreleased under the new version in both files.

**Where the docs are.**

- `docs/api.md` and `docs/ARCHITECTURE.md` are **generated copies**. Do not edit
  them. Run `make sync-contract` to refresh them from `critalarm-server`.
- `docs/design-system/` holds `index.html` and `NOTES.md`. `lib/design/` is the
  design system that implements them, and screens build from it: tokens in
  `tokens/`, components in `components/`, the face in `faces/`, the theme in
  `theme/`. `NOTES.md` lists the components and when to use each. The debug
  route `/gallery` shows every one.
- `lib/design_system/` is the older folder. It re-exports `lib/design/` and
  keeps the motion and haptics helpers. Do not add components there.

**What is real and what is a placeholder.**

- Real: the design system in `lib/design/`, with its palette, fonts and
  component names. The `AppColors` `ThemeExtension` with `copyWith` and `lerp`,
  the single `ThemeData` construction point in `lib/design/theme/theme.dart`,
  the theme preference round-trip, `go_router` wiring (`lib/app/router.dart`, 51
  routes today: `GoRoute(` appears 43 times, and one of those is a loop that
  builds the 9 setup step routes), the `AppResult` and `Failure` types, `tool/check_layers.sh`, CI.
- Placeholder: nothing in `lib/design/`. The widgets left in
  `lib/design_system/widgets/` predate it. Do not build new screens from them.

**Public repo.** Never commit a `.p8`, a keystore, `google-services.json`,
`GoogleService-Info.plist`, a `.env`, a RevenueCat key, or a price. Signing
identities live in the Apple developer account, not here.

**No Apple Critical Alerts.** Apple denied the entitlement for `app.critalarm`.
The app does not ask for it and no code path may assume it exists. One iOS
story, used everywhere: an AlarmKit alarm through silent mode on iOS 26 or
later, a Time-Sensitive notification with sound on older iPhones. Android keeps
the full-screen alarm. Copy that promises a ring through silent mode picks its
words from `RingClaim` (`lib/core/alarm/ring_claim.dart`) so an older iPhone is
never told that. The per-topic `critical` switch, the priority ladder and
incidents are unaffected and stay exactly as they are.

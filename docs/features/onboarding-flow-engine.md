# Setup flow engine

Moved out of AGENTS.md on 2026-10-17, text unchanged. Read before changing this area.

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
     Each step has its own, with its own arrangement in
     `OnboardingAmbientProfiles`, so the shapes glide whenever the flow moves
     from one step to another. A test fails when two steps share one.
3. When the user is done with the screen, call
   `finishOnboardingStep(context, OnboardingStepId.yourStep)`. A screen never
   names the step after it.
4. List the id in a flow. `BundledOnboardingFlows` holds the four that
   ship: `2026-10-c` (the default), `2026-10-b` (the default before it, with
   no `use` step), `2026-10-a` (the one before that) and `legacy-1` (the
   first shipped order). The older three are kept for phones that pinned
   them. A shipped flow is never edited: a new order is a new flow id.
5. Give it a chapter in `onboarding_chapters.dart` if the tracker should
   count it. A step with no chapter sits outside the tracker.

An entry with no route is known to the validator and never shown. None is
like that today.

An entry that requires `connect` is covered by the shell while no server is
connected. `handlesMissingServer: true` turns that off for a step that has
its own state for it: `real_ring` and `hook_up` today.

`hook_up` is the last step of the default flow. It exists on iOS and
Android, and counts as already done once a first message was received.

`widgets` is an optional step. No bundled flow lists it, because the welcome
shows the widgets as its last page. A flow that lists it shows it at any
position, the last one included, and it exists on iOS and Android only.

`welcome` is one step with three pages (`WelcomePage` in
`domain/welcome_pages.dart`): the word page ("Welcome to Crit Alarm" with the
face), the curl that rings a phone and the home screen widgets. The user
swipes between them or taps Next, and Get started on the last page finishes
the step. Until the first swipe or Next tap, the first story ends by opening
the next page. The rules for the button, for where a finished story hands on
and for which page may play haptics are in that file.

- While the pager moves, the first page's big title, face and rings fade and
  travel clear of the page edge instead of being cut by it
  (`welcomeWordPartingAt`, driven by the `PageController` page value).
- The shapes behind the welcome follow the page value: each page has its own
  arrangement (`OnboardingAmbientProfiles.welcomePages`), and the shell
  paints the blend of two neighbours (`welcomeAmbientAt`) while a swipe moves
  the pager. The welcome reports the page value through
  `OnboardingAmbientScope.pagePosition`. Under reduced motion the pager
  jumps, so the shapes jump too.
- `how_it_rings` and `widgets` are still steps with their own routes, and a
  flow that lists them shows them. No bundled flow does, because the welcome
  already shows the curl and the widgets.

`use` is the question step, "What should wake you?": five rows (servers,
homelab, jobs, home, something else) and a `skip` control. A tap on a row
saves the answer, sends the pick event and finishes the step at once; there
is no Continue button. The answer is `SetupUse`, one wire id each (`servers`,
`homelab`, `jobs`, `home`, `other`), kept under the one prefs key `setup_use`
by `SetupUseStore`. It is not part of the setup draft, because setup clears
the draft when it ends and Home and the offer read the answer afterwards.
`skip` saves `other`. A missing or unreadable answer reads as `other`, which
is what a phone on an older flow has. Everything an answer changes is data
in `SetupUseProfile` (`domain/setup_use/`): the topic name and name chips,
the tool chip order and the tool that starts selected, the sample alarm
message, what the offer opens on and the Home waiting line. A replay keeps
its pick in memory (`SetupUseReplay`) and saves nothing; readers ask
`setupUseFor`. The step is in the Set up chapter, is satisfied for a user
who already owns a topic, and flow `2026-10-c` lists it between
`permissions` and `first_topic`.


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

Chapters and the tracker: setup has three chapters (`OnboardingChapter`):
Meet (`welcome`, and `how_it_rings` in a flow that lists it), Set up
(`connect`, `permissions`, `use`, `first_topic`) and Hear it (`real_ring`). The shell draws `SetupTracker`
where a step's top bar has its title: one small face and three bars.
`onboardingTrackerFillFor` holds the maths. Bars before the current chapter
are full, and the current one is the chapter's steps listed before this one
over all of the chapter's steps in the flow, so a step the run passed over
counts as done. A step with no chapter (`offer`, `hook_up`, `widgets`,
`legacy_test`) shows what the next counted step would, and every bar full
when none is left. A step's top bar takes its title from
`setupTopBarTitle(context)`, which is null while the tracker is up.

The small face: a step sets its mood with
`OnboardingAmbientScope.maybeOf(context)?.setFaceMood(...)`, from a listener
or a callback, and passes null to hand the choice back. `TravellingFaceMood`
has the five it can be. A step never draws a face of its own in the top bar.

Back: `onboardingBackStepFor` is the rule. Back is offered on
`how_it_rings` (where a flow lists it), `connect`, `permissions`, `use` and
`first_topic`, and is gone for
good once the first topic exists. It goes to the nearest earlier step of the
flow that was on screen at any point in this run
(`OnboardingFlowEngine.shownSteps`, held in memory and emptied when setup
ends). Going back takes nothing out of that set, so a step the user saw once
stays in reach. A step the run passed over is never a Back target, and after a
restart there is no Back until the user moves forward. A screen that moves on with nothing for the
user to do finishes with `skippedItself: true`. The shell draws the button only
while it is offered, never greyed out, and `OnboardingStepFrame` makes the
Android back button and an iPhone edge swipe follow the same rule.
`OnboardingFlowEngine.goBack` takes the step that was left out of the
completed steps, so going forward opens it again. Back opens the step with
`?back=true` (`isOnboardingCameBack`): the use step then draws the saved
answer's row picked, and a tap on any row saves it again and moves on. The
connect step shows
"Connected to" the server that is saved, or where a connect still running
stands, with a way to change it through the call Settings > Server makes.
The permissions list every permission of this phone as allowed or not
allowed (`PermissionAnswerList`), and only a tap on a row asks for
anything. The battery row opens the app's page in Settings and never the
system dialog. A step that is busy holds Back with
`holdBack(isHeld: true)`.

Step changes: the shell slides and fades the old step out and the new one
in (`AppDurations.slow` in all, none under reduce motion), the other way
round for Back. `finishOnboardingStep` and `goBackInOnboarding` start it, so
a step route has no page transition of its own. The canvas gets `pop` for
Back, and `sweep` when the change crosses a chapter.

Background connect: Continue with our server finishes the `connect`
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
  names its id. In a `SKIP_PAYWALL` build it plays on through the offer
  (see the `offer` step).
- Open a step: every registered step, opened as a replay. A step that is not
  on this phone, or has no screen yet, is listed greyed with the reason. A
  replay of the permissions step takes `?skip=<n>` to open on a later step
  (`OnboardingPermissionsScreen.replaySkipParam`).
- Other setup states: screens around setup that no step route reaches,
  with made-up values. `first_tool_acknowledged` opens the setup
  acknowledged screen (`CriticalAlarmScreen.previewFirstToolAckedLocation`),
  and `checklist_closed` / `checklist_open` set `homeSetupPreview`. Home no
  longer reads it, so those two draw nothing. Nothing is sent or saved. Real ring states also
  has `send_countdown`.
- Count as not done: one switch per step that has an `isSatisfied` check
  (`forceableOnboardingSteps`), saved in `dev.onboarding_forced_unsatisfied`.
  A forced step is the resume point even when its check says it is done, and
  the permissions screen shows its steps (`replayForDemo`).

A store build is compiled with `NoDeveloperOnboardingOverrides` and the empty
developer slot (`buildHasOnboardingDeveloperTools` is a compile-time
constant), so it ignores both keys even when they are set.

A replay changes nothing real: no flow state, no topic on the first-topic
step, and no connect form draft (`onboarding_replay_rules.dart`).


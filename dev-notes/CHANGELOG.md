# Dev notes
Changes developers need to know about: new tokens and components, prefs keys, build flags, tooling, tests, refactors and small UI polish too minor for the user changelog. Added with cider (`make devlog`), one line each. Versions match the app's `pubspec.yaml`. This repo is public: no prices, keys, task numbers or planning links.

## Unreleased
### Added
- Setup flow engine in `lib/features/onboarding/domain/flow/`: a flow is an id plus a list of step ids, checked by `validateOnboardingFlow`, chosen from ordered `OnboardingFlowSource`s and pinned when the user taps Get started. `OnboardingStepRegistry` holds one entry per step (route, screen, `isAvailable`, `isSatisfied`, `requires`, canvas step) and the router builds the step routes from it. Screens call `finishOnboardingStep(context, stepId)` and no longer name the next step.
- Prefs keys `onboarding_flow_id`, `onboarding_flow_steps` and `onboarding_flow_completed` hold the pinned setup flow and the steps finished in it. All three are cleared when setup completes.
- Routes `/onboarding/first-topic`, `/onboarding/real-ring` and `/onboarding/test`. `CreateTopicScreen` takes an optional `onDone` callback that replaces its three exits, and `OnboardingConnectScreen` takes a `part` (connect or test).
- `AppHighlightCard` (tones `crit` and `calm`), `AppAnimatedTick` and `AppWaitingFace` in `lib/design/components/`, shown in the gallery. The no-server notice card draws its surface with `AppHighlightCard`.
- BackgroundConnect, one object for the whole app run, connects to Crit Alarm Cloud behind the user. Its pending intent is saved under the prefs key connect\_intent\_v1 and retried on a timer, on resume and on launch
- OnboardingStepGate wraps every setup step route: a step that requires connect shows the waiting face until the connect lands, and any step shows the failure when it gives up
- Developer settings can pick the setup flow (bundled or a typed step list), replay it, open any setup step, and force a step to count as not done. Prefs keys: dev.onboarding\_flow and dev.onboarding\_forced\_unsatisfied. Release builds without the developer flags ignore both.
- Remote Config key onboarding\_flow (default an empty string) feeds the remote slot of the setup flow sources through TelemetryGate.onboardingFlowJson and RemoteOnboardingFlowSource. OnboardingFlowEngine.chooseFlowWithOrigin() says whether the developer override, the remote value or the bundled default won.
- Android battery step in setup, shown only on makers listed in backgroundKillerMakers. DeviceMakerReader reads the maker, and a debug run takes --dart-define=DEVICE\_MAKER=<name> to fake it.
- PermissionStepDots counts the steps a phone draws. OnboardingAmbientStep.battery is the canvas for the battery step.
- Settings variant of the notification step for a spent prompt, with keys onboarding\_permissions.{ios,android}.notifications.settings\_\*. AndroidSdkReader reads the API level.
- Topics: ToolTemplate enum, FirstTopicHandoff (in-memory token, name saved as onboarding\_first\_topic), ToolTemplateStore (topic\_tool\_template.<name>), isFirstTopicFor, AppTopicChip isSelected and hitSlop.
- RealRingCubit and real\_ring\_screen.dart run the real\_ring step: the server sends the test alarm, AlarmArrivals says when it reached this phone, and LocalTestAlarm is the one copy of the phone-only fallback.
- Prefs key onboarding\_real\_ring\_incident (SetupTestRing) holds the incident id of the setup test until setup completes.
- FirstMessageWatcher polls a topic for the first message while a screen waits, with the prefs keys first\_message\_received and first\_message\_since.<topic>.
- ToolSnippet.build returns the paste text or form fields for the tool picked on the first topic, and CurlLine.build takes an optional priority.
- AppCodeBlock isWrapped wraps long commands with the copy button underneath, and AppHighlightTone.pending is a row that is still waiting.
- countsAsRealUse decides whether an alarm is the user's own use or one setup caused, and SetupTestRing.setupIncidentIds keeps those ids under onboarding\_setup\_incidents.
- AppScreenScaffold barBacking puts a solid colour behind the top bar and the pinned bottom bar, and the hook-up token id is saved under onboarding\_hook\_up\_token\_id.
- Home setup content: HomeSetupCubit and HomeSetupSection draw the setup checklist, its one celebration and the widgets card at the top of the Topics list sheet. Prefs keys setup\_checklist\_seeded, setup\_checklist\_done and home\_widgets\_card\_seen, each set once.
- Setup sends onboarding\_step\_viewed and onboarding\_step\_completed (step, flow\_id, ms\_since\_previous). They wait in pending\_onboarding\_events until the user answers the analytics question, are sent on opt-in, and are deleted on opt-out and after 7 days unanswered. The answer is kept in onboarding\_funnel\_state.
- AppHighlightTone.choice: cream with the ink stroke, for the one choice on a screen before it is made. The first-topic Critical card uses it while off.
- AppWaitingFace takes faceState, FaceRipple takes restFaces for a mixed wall, AppTextField takes scrollPadding.
- A replay of the permissions step takes ?skip=<n> to open on a later step in a developer build.
- AckedExits.firstToolAlarm: the alarm the first hook-up message set off gets a setup acknowledged screen with one Finish button, which closes that incident through CriticalAlarmCubit.finishFirstToolAlarm. The id is saved as onboarding\_first\_tool\_incident (SetupTestRing.firstToolIncidentId). Developer options, Other setup states, opens it with made-up values.

### Changed
- A successful connect finishes the connect step and moves on. `/onboarding/connect` no longer turns into the test screen, and `OnboardingConnectCubit` saves the half-typed form only.
- Locale values and the search keyword for the paid plan say Hosted. Keys, class names, routes and analytics event names keep their pro\_ names. The create-topic limit hint is now the key create\_topic.limit\_review\_plan\_hint.
- `AppEmptyState` has no English defaults: `title` and `description` are required and `buttonLabel` is null unless passed. The Home empty card reads its words from `home.empty_body` and `home.empty_button`.
- A pinned setup flow goes through the validator each time it is read: unknown ids are dropped, and a rejected or empty list is replaced by the bundled default with the completed steps kept. `finishOnboardingStep` does not navigate when the router moved while it was waiting. `CriticalAlarmState.hasOwnedTopic` decides whether the demo celebration offers the first topic.
- A mock build answers for the Crit Alarm Cloud address as hosted, so Continue with Crit Alarm Cloud works under MOCK
- Welcome and the other intro screens show their words and button from the first frame. Removed the staged reveal, the per-animation text delays and the staged flag. The animation keeps its size at large text sizes and the page scrolls when the words need the room. The widgets step is optional: the default flow leaves it out, and its registry entry exists on iOS and Android only.
- A replay of setup no longer saves the connect form draft, and the first-topic step in a replay ends without creating a topic.
- The permissions screen walks a step list built per platform by permissionSetupStepsFor. ReadPermissionSetupUsecase reads every step's status before one is drawn, and the flow engine's permissions check uses the same read.
- Permission copy keys split by platform: onboarding\_permissions.ios.{notifications,alarms,time\_sensitive}.\* and onboarding\_permissions.android.{notifications,full\_screen,battery}.*. The mixed step1\_*, step2\_*, preview\_* and badge\* keys are gone. New keys: checking, step\_progress.
- PermissionDialogPreview is split into IosPermissionDialogPreview, AndroidPermissionDialogPreview and AndroidSettingsSwitchPreview inside a shared PermissionPreviewFrame. The full-screen step now draws a settings switch.
- Permission steps hold still once drawn: freezePermissionSteps only appends. The status read times out after five seconds. The battery dialog's Deny moves on.
- The connect step counts as done only while a connection is saved or a connect is pending, a 429 from device registration is a permanent device cap failure, and the privacy line needs relay\_content present in the answer (ServerInfo.statedRelayContent)
- Setup completion moved: the acknowledged screen finishes the real\_ring step and the flow engine completes setup, legacy-1 keeps its own buttons, and every Set this up later exit calls SetUpLaterUsecase.
- The onPushReceived channel call carries the incident id of an alarm push (PushHost.alarmPushes), and Android answers receivedAlarmFor on the alarm channel.
- SetupTestRing keeps every test incident id of a setup run and the ones a close failed for (prefs keys onboarding\_real\_ring\_incidents and onboarding\_real\_ring\_unclosed), and EndSetupTestUsecase closes leftovers when the app opens.
- The bundled flow 2026-10-a ends with hook\_up, and Developer options lists the hook-up states.
- The hook-up step pins its first-message row above Done up to twice the default text size, and puts it in the body above that.
- CurlLine.build single-quotes the message and the address for a shell, on the topic page too.
- FirstMessageWatcher takes its starting point from the server with since=all and no longer reads the phone clock.
- FirstMessageRow takes showsFace, so a list with its own face can leave the row's out. The paywall pitch lists home screen widgets.
- Every setup step draws one 80 px hero face with the tag onboarding-face at the same top inset. watching is kept for waits, worried for failures.
- CreateTopicCubit.isOneStep creates from the first step and names the token after the picked tool. Setup sets it; the Home screen keeps two steps.
- Home decides it is in front from the router's location (isHomeFrontScreen), backs off its first-message poll, sweeps topics beyond the polled three, and backs off a failed first look.
- The acknowledged screen of a setup test lists what the alarm proved as ticks (ProofList). The phone-only test shows the server and the push as not tested. AppAnimatedTick takes optional colours for the acknowledged canvas.
- The acknowledged screen shows two buttons at most: At my desk (or the topic once the incident is closed) over a paper Back to topics. Its title scales to fit one line (AppFittedTitle), the topic is a tappable pill, and it keeps the acknowledged colours after At my desk.

### Fixed
- A setup screen opened after setup is over (`OnboardingEntryPoint.connectServer` from Server settings and the no-server card, `OnboardingEntryPoint.testAlarm` from Health) saves nothing, pins nothing and closes back to the screen that opened it. Health opens `/onboarding/test`.
- The denied permissions screen stays on screen through a status read. It used to turn into the stepper as soon as the first read finished.
- The Time-Sensitive explainer no longer shows after notifications were refused, and the Android full-screen step drops its ring chip while notifications are off. The Android notification mock says Don't allow.
- Setup never closes or leaves a real alarm: CriticalAlarmCubit.closeSetupTests acts only on the stored setup test on screen, a server push cancels a running phone-only countdown, and iOS names an incident to Dart only for a push that rings (AlarmScheduleRule.ringingIncidentId).
- The Feature Guide offer is raised after the route change has settled, so it is no longer swept away and counted as declined when setup ends.
- A token made in setup and never shown is taken back if the app is killed before the hook-up step: its id is saved with the handoff.

### Removed
- The `OnboardingStep` enum, `OnboardingDraft.step`, `RememberOnboardingStepUsecase` and `goToOnboardingStep`. The `onboarding_step` prefs key is read once to place a user who was halfway through setup, then removed.
- NotificationPermissionsState.activeSubstep, totalSteps, alarmSupported, fullScreenStep, fullScreenGranted, notificationsGranted and criticalAlertsGranted, replaced by steps, current and granted. The cubit's requestNotifications, requestCriticalAlerts and requestPermissions are one allowCurrentStep.
- OnboardingPermissionsCubit and OnboardingConnectCubit.ringTestAlarm, both unused and holding hardcoded English.
- Setup strings that said a thing twice: permission badges, dialog hints, helper lines, the steps header. Their keys are gone from en.json.

## 1.0.0+12 - 2026-10-03
### Added
- Prefs keys `home_prompt_first_topic_at` (first time the user owned a topic, set once) and `home_prompt_battery_dismissed_at` (battery notice dismissed for good).
- `InAppNoticeType.batteryOptimization`, priority 3, between critical health and Pro ending.
- Colour tokens `segmentSelected`, `switchOff`, `switchThumbOff`, `tabBar` and `tabBarLine`; dark `cream` is now `#312823`.
- `AppButtonVariant.cream` for primary actions on the acknowledged canvas, and `AppStepBullet` numbered discs in `sheets.dart`.
- `yearlySavingPercent` in `lib/features/paywall/domain/entities/plan_saving.dart`, with tests.
- `HistoryWindow.shownDays` and `HistoryWindows.isLocked`; the history filter default window is 90 days, shown as the widest window the plan allows.
- `make log`, `make devlog` and `make changelog-release` wrap cider for both changelogs.
- tool/caf\_length\_check.sh checks caf length against ffmpeg on a Mac; docs/specs/gapless-loop-check.md says how to check the alarm loop on a phone.
- `tools/sounds/emergency.mjs` rebuilds the 14 `emergency_*` sounds into `assets/sounds/` as mono AAC `.m4a` (iOS) and mono Opus `.ogg` (Android), with byte-identical output and a decoded clip check. `BundledSounds.extensionFor` now takes the sound id, because the iOS extension differs per sound. Settings search finds the sound list by emergency, klaxon, sos, beeper, horn and bell.
- `tools/sounds/loops.mjs` rebuilds the five `loop_*` sounds into `assets/sounds/` as mono AAC `.m4a` (afconvert on macOS) and mono Opus `.ogg`, each exactly 1,382,400 samples at 48 kHz on both platforms, with a decoded length, clip and join check. `AlarmSound.seamlessLoop` (default false) and `BundledSounds.seamlessLoops` mark them for a gapless player.
- Sound packs: an on-demand Play Asset Delivery pack (sound\_pack\_library) and an Apple-hosted Background Assets pack with a downloader extension, bridged on the app.critalarm/sound\_packs channel. Pack sounds are copied into the app's sound folder and ring like imported ones; a missing pack sound falls back to classic\_siren.
- tools/sounds/library\_pack.mjs prepares the library pack sounds with the emergency.mjs mastering chain and writes both packs, their credits and lib/core/sound/library\_pack\_sounds.dart.

### Changed
- Onboarding step 1 on Android asks for notifications only; the full-screen intent is its own step 2 through `DevicePermissionsRepository`.
- Settings sub-page routes sit on the root navigator and are opaque, like `/app-icon`, so the tab bar is hidden there. `/settings/alarms` now holds Storage.
- `AppKeyValueRow` keeps labels at full width, ellipsizes values, and stacks the two when they do not fit.
- `AppListRow` subtitles wrap to two lines; About shows URLs without the scheme.
- Search results list with the best match next to the search bar; no-results shows a face card with example searches.
- List section headers go through `AppSectionHeader`.
- `AppTextField` hints use `ink3` at 60% in every field.
- `AppButtonVariant.destructive` uses `inkFixed` text, so every destructive dialog changes.
- Calm ambient profiles use only `#FFB21F` and `#FFE08A`, at half opacity on dark canvases.
- The Feature Guide card has no close X and no large shadow; "Skip guide" is the one exit.
- The in-app paywall has one heading, Yearly and Monthly plan titles, and no cobalt ring on the face.
- The onboarding screens before Permissions slide in with their text and buttons.
- The onboarding test alarm's acknowledged screen drops its explanatory text and detail sheet and ends on confetti.
- The test alarm's It works screen has a black-ink face, a short line and the ring time, and ripples with faces behind the confetti.
- Redo onboarding in Settings shows in developer-flag builds (SKIP\_PAYWALL or PAYWALL\_LAB), not only debug builds.
- The test alarm's It works screen shows a ripple of happy faces as its picture instead of one big face.
- The test alarm's finish screen now reads Welcome to Crit Alarm! with a four-column face ripple and two buttons, Create your first topic and Finish.
- The Android alarm decodes its sound once to PCM (PcmDecoder) and loops it through a streaming AudioTrack (PcmLoopPlayer). MediaPlayer is the fallback when decoding fails, logged as alarm\_loop\_fallback.
- iOS convertToCAF writes LPCM caf at the source sample rate through GaplessCaf and cuts MP3 encoder delay and padding, so every caf is the exact decoded length.
- The Android alarm falls back to MediaPlayer whenever the loop writer dies, and MediaPlayer tries the bundled default before giving up; logged as alarm\_loop\_fallback, alarm\_media\_player\_failed and alarm\_silent.
- AlarmPlayer runs on the main thread only; a failed AudioTrack is rebuilt once from the decoded PCM (alarm\_track\_retry) before MediaPlayer, and a MediaPlayer that errors while playing retries the chain once after 500 ms (alarm\_media\_player\_retry).
- tools/sounds generators master every bundled sound to at least -9 LUFS on the decoded mono file and fail any decoded file over -1.0 dBTP true peak. Sounds already that loud get gain only; quieter ones get a presence lift, parallel compression, a 4x soft clip with a DC-blocking high-pass, and a 4x limiter. Emergency sounds and loops encode Opus at 48k (12 kHz cutoff for emergency, 16 kHz for loops). generate.py rebuilds byte-identically. AlarmSound.seamlessLoop is derived from the id, never stored.

### Fixed
- The PRO badge uses `inkFixed`, so it stays ink on yellow in dark.
- Unselected radios use the card surface and a theme ink ring instead of a canvas-filled dot.
- MainActivity.shouldHandleDeeplinking returns false: the manifest flag is looked up on the launcher activity-alias, so a launcher start left deep linking on. The router also maps any critalarm:// location to the incident, topic or Home route (PushDeepLink.fromAppUri).
- Align self-host toggle button padding with cloud card using Spacing.s5.

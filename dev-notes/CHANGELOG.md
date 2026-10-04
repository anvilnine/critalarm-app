# Dev notes
Changes developers need to know about: new tokens and components, prefs keys, build flags, tooling, tests, refactors and small UI polish too minor for the user changelog. Added with cider (`make devlog`), one line each. Versions match the app's `pubspec.yaml`. This repo is public: no prices, keys, task numbers or planning links.

## Unreleased
### Added
- Setup flow engine in `lib/features/onboarding/domain/flow/`: a flow is an id plus a list of step ids, checked by `validateOnboardingFlow`, chosen from ordered `OnboardingFlowSource`s and pinned when the user taps Get started. `OnboardingStepRegistry` holds one entry per step (route, screen, `isAvailable`, `isSatisfied`, `requires`, canvas step) and the router builds the step routes from it. Screens call `finishOnboardingStep(context, stepId)` and no longer name the next step.
- Prefs keys `onboarding_flow_id`, `onboarding_flow_steps` and `onboarding_flow_completed` hold the pinned setup flow and the steps finished in it. All three are cleared when setup completes.
- Routes `/onboarding/first-topic`, `/onboarding/real-ring` and `/onboarding/test`. `CreateTopicScreen` takes an optional `onDone` callback that replaces its three exits, and `OnboardingConnectScreen` takes a `part` (connect or test).
- `AppHighlightCard` (tones `crit` and `calm`), `AppAnimatedTick` and `AppWaitingFace` in `lib/design/components/`, shown in the gallery. The no-server notice card draws its surface with `AppHighlightCard`.
- Developer settings can pick the setup flow (bundled or a typed step list), replay it, open any setup step, and force a step to count as not done. Prefs keys: dev.onboarding\_flow and dev.onboarding\_forced\_unsatisfied. Release builds without the developer flags ignore both.
- Remote Config key onboarding\_flow (default an empty string) feeds the remote slot of the setup flow sources through TelemetryGate.onboardingFlowJson and RemoteOnboardingFlowSource. OnboardingFlowEngine.chooseFlowWithOrigin() says whether the developer override, the remote value or the bundled default won.

### Changed
- A successful connect finishes the connect step and moves on. `/onboarding/connect` no longer turns into the test screen, and `OnboardingConnectCubit` saves the half-typed form only.
- Locale values and the search keyword for the paid plan say Hosted. Keys, class names, routes and analytics event names keep their pro\_ names. The create-topic limit hint is now the key create\_topic.limit\_review\_plan\_hint.
- `AppEmptyState` has no English defaults: `title` and `description` are required and `buttonLabel` is null unless passed. The Home empty card reads its words from `home.empty_body` and `home.empty_button`.
- A pinned setup flow goes through the validator each time it is read: unknown ids are dropped, and a rejected or empty list is replaced by the bundled default with the completed steps kept. `finishOnboardingStep` does not navigate when the router moved while it was waiting. `CriticalAlarmState.hasOwnedTopic` decides whether the demo celebration offers the first topic.
- Welcome and the other intro screens show their words and button from the first frame. Removed the staged reveal, the per-animation text delays and the staged flag. The animation keeps its size at large text sizes and the page scrolls when the words need the room. The widgets step is optional: the default flow leaves it out, and its registry entry exists on iOS and Android only.
- A replay of setup no longer saves the connect form draft, and the first-topic step in a replay ends without creating a topic.

### Fixed
- A setup screen opened after setup is over (`OnboardingEntryPoint.connectServer` from Server settings and the no-server card, `OnboardingEntryPoint.testAlarm` from Health) saves nothing, pins nothing and closes back to the screen that opened it. Health opens `/onboarding/test`.

### Removed
- The `OnboardingStep` enum, `OnboardingDraft.step`, `RememberOnboardingStepUsecase` and `goToOnboardingStep`. The `onboarding_step` prefs key is read once to place a user who was halfway through setup, then removed.

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

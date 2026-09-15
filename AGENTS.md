# Crit Alarm — rules for every agent

You are building Crit Alarm. Read, in this order, before touching code:
1. docs/api.md          — the contract. Build to this. Never edit it inside a task. (In the app and site repos it is a generated copy; the source is critalarm-server/docs/api.md.)
2. docs/ARCHITECTURE.md — how the pieces fit and the folder layout.
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
- Flutter: follow the design system in the repo. Cubit/Bloc, go_router, freezed — as the template does. Do not introduce a state-management library.
- Astro: follow the template. No new frameworks.
- Small commits with plain messages. One task = one branch = one PR.

## Definition of done
- The acceptance list in the task file passes.
- `npm test` / `flutter test` / `npm run build` passes.
- PR description has: what was built, how to verify it by hand, screenshots for UI, suggested follow-ups.
- Nothing outside the task's file scope was changed. If you had to, say why.

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

**Stack.** Flutter 3.44.4 (pinned in `.fvmrc`, use `fvm`), Dart 3.12. Cubit and
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

**Folder layout** (ARCHITECTURE §12):

```
lib/features/{onboarding,topics,incidents,settings}
ios/CritAlarmNSE/    Swift. fetch + mutate the notification.
android/             full-screen intent channel config
```

Each feature is `data/domain/presentation`, and `tool/check_layers.sh` enforces
the direction: core must not import features, domain must not import data or
presentation. Today only `features/settings` exists, holding the theme slice.

**This app also builds for web.** The dashboard is this codebase run through
`flutter build web` (ARCHITECTURE §2). Four rules keep that cheap:

- Ask the capabilities service (`canRegisterPush`, `canRunAlarm`, `canImportSounds`, `canComposeMessages`), never `kIsWeb` or `Platform.isIOS` inline; it answers per platform, so web gets no push, no alarm, yes compose.
- A screen that exists on one platform only is its own route gated by a capability, never a widget hidden behind a boolean: the message composer is web only, the permissions screen is mobile only.
- Shared widgets take no platform-specific dependencies.
- Layout breakpoints come from the design system, never from the platform.

**Where the docs are.**

- `docs/api.md` and `docs/ARCHITECTURE.md` are **generated copies**. Do not edit
  them. Run `make sync-contract` to refresh them from `critalarm-server`.
- `docs/design-system/` holds `index.html` and `NOTES.md`. `lib/design_system/`
  must implement that. It does not yet. The palette, the three font families
  and several widget names in `lib/design_system/` are placeholders standing in
  until A0 replaces them. A0 reconciles the two. Do not reconcile them inside
  another task.

**What is real and what is a placeholder.**

- Real: the `AppColors` `ThemeExtension` with `copyWith` and `lerp`, the single
  `ThemeData` construction point in `lib/design_system/theme.dart`, the theme
  preference round-trip, `go_router` wiring, the `AppResult` and `Failure`
  types, `tool/check_layers.sh`, CI.
- Placeholder: every colour and font value, `lib/app/router.dart` (one route),
  and the widget names in `lib/design_system/widgets/`.

**Public repo.** Never commit a `.p8`, a keystore, `google-services.json`,
`GoogleService-Info.plist`, a `.env`, a RevenueCat key, or a price. The
Critical Alerts entitlement is tied to the signing identity, which lives in the
Apple developer account, not here.

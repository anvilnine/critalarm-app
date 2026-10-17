# Crit Alarm: rules for every agent

<!-- Shared block. critalarm-server, -app, -site and -cli each carry a copy. Change all four
     together. -->

You are building Crit Alarm. Read, in this order, before touching code:
1. `docs/api.md` is the contract. Build to it. Never edit it inside a task. (In the app and site
   repos it is a generated copy. The source is `critalarm-server/docs/api.md`.)
2. `docs/ARCHITECTURE.md` is how the pieces fit and the folder layout.
3. The task file you were given. It is self-contained and names the product commitments that
   apply to you.

Commitments made to Apple that no task may break:

- The per-topic `critical` switch defaults to OFF, and the user can turn it off per topic or in
  Settings.
- Every topic has a token. There are no public topics.
- The app never generates alarms and never inspects content.
- The alarm stops on acknowledge.

## Non-negotiables
- Do not add features that are not in your task. Put the idea under "Suggested follow-ups" in the
  PR description and stop.
- Do not invent API routes, fields or headers. If `api.md` does not cover what you need, stop and
  report.
- The `incident` package does not import from `push` or `relay`. It emits events.
- Timers are database rows, never in-memory only.

## Tests
- Unit tests only. No widget tests, no integration tests, no e2e.
- Server: every state transition in the incident machine has a test using a fake clock. Every
  ntfy header alias has a test. Every error code in `api.md` section 1.8 has a test.
- App: unit-test models, the API client against the mock server, and any pure logic. Do not
  test widgets.
- UI is verified by screenshot. Attach one to the PR for any screen you touch.

## Code
- TypeScript strict, no `any`, Node 22.
- Flutter: Cubit/Bloc, go_router, freezed, as the template does. No other state-management
  library.
- Astro: follow the template. No new frameworks.
- Small commits with plain messages. One task, one branch, one PR.

## Definition of done
- The acceptance list in the task file passes.
- `npm test` / `make test` / `npm run build` passes.
- The PR says what was built, how to check it by hand, and has screenshots for UI and suggested
  follow-ups.
- Nothing outside the task's file scope changed. If something had to, the PR says why.

## Running under /goal
- Your task file ends with a `/goal` line. That line is your stopping condition. Nothing else is.
- The evaluator judges from the transcript. After every meaningful step, paste the command and its
  output: test summary, `git diff --name-only`, build result. Work you did not show did not
  happen.
- Do not declare done. Show the evidence and let the evaluator decide.
- At the turn cap without meeting the condition, write `BLOCKED.md` with what remains and stop.

## When stuck
Write what you tried and what blocked you in the PR or a `BLOCKED.md` in the task folder. Never
work around a blocker by changing the contract or another package.

---

## This repo

`critalarm-app`. Public, GPL-3.0. The Flutter app, plus a Swift target for the iOS Notification
Service Extension.

**Stack.** Flutter 3.44.9 (pinned in `.fvmrc`, use `fvm`), Dart 3.12. Cubit and Bloc, `go_router`,
`freezed`, `get_it` for the composition root, `easy_localization` for strings.

**Commands.** Every one goes through `fvm`.

| What | Command |
|---|---|
| Test | `make test` |
| Analyze | `make analyze` |
| Codegen | `make gen`, then `make l10n` |
| Layer check | `make check-layers` |
| Localization check | `make check-l10n` |
| Refresh the contract | `make sync-contract` |
| Run with a quiet alarm | `make run-quiet DEVICE=<id>` (dev only, never ships) |
| Buy for real on a device | `make run-store DEVICE=<id>` (`run-release` skips the store) |
| Record paywall frames for site and marketing | `make site-paywalls`, then `sh tool/site_paywalls_to_web.sh <out-dir>`. Read the header of `tool/capture_site_paywalls.dart` first |
| Android cold start | `make cold-start APK=<path>` |
| New worktree | `make worktree-new NAME=<slug>` |
| Worktree status | `make worktree-list` |
| Drop merged worktrees | `make worktree-clean` |
| Changelog line | `make log TYPE=<type> MSG="..."` (users) or `make devlog ...` (dev notes) |

Fresh cold-start mode wipes all app data on the selected device and needs `--yes-wipe`. The
Makefile target never passes it.

## Repo rules

Each rule carries its reason. Detail sits behind the link.

1. **One task, one worktree: `make worktree-new NAME=<slug>`.** It makes `worktrees/<slug>` on
   branch `task/<slug>`. Never `.claude/worktrees/` or Claude Code's built-in worktree. If you find
   one there, stop and tell Z.
   Why: Flutter skips dot folders, so nothing builds there, and `worktree-list`, `worktree-clean`
   and the prep hook never see it. Details: `worktrees/README.md`.
2. **Run `make gen` and `make l10n` after a clone, in a fresh worktree, and after any merge that
   touched an annotated source file.**
   Why: `*.g.dart` and `*.freezed.dart` are git-ignored, so a merge can leave new source beside an
   old generated file. It shows up as every widget test failing with `Error: Member not found`,
   which looks like a broken merge and is not one. `lib/gen/*.gen.dart` (FlutterGen) is the one
   committed exception. `.claude/hooks/worktree-prep.sh` runs both for a new worktree and drops a
   `.worktree-ready` marker.
3. **Layers point one way.** Each feature is `data/domain/presentation`. Core never imports
   features. Domain never imports data or presentation. `tool/check_layers.sh` enforces it.
4. **Every user-facing string goes through `LocaleKeys.<key>.tr()`.** Text that must stay as
   written ends its line with `// l10n-ok: <reason>`.
   Why: `tool/check_l10n.sh` fails on an English literal in `Text`, `TextSpan` or an `AppButton`
   label.
5. **Ask `PlatformCapabilities`, never `kIsWeb` or `Platform.isIOS` inline.**
   Why: the dashboard is this codebase built for web (ARCHITECTURE section 2). `lib/app/di.dart`
   is the one place that reads `kIsWeb` for feature code, and `check_layers.sh` fails on any
   `kIsWeb` under `lib/features/`, comments included. A one-platform screen is its own route gated
   by a capability, never a widget hidden behind a boolean. Breakpoints come from the design
   system. Full rules: `docs/features/web.md`.
6. **No Apple Critical Alerts.** Apple denied the entitlement for `app.critalarm`. No code path may
   assume it. Copy that promises a ring through silent mode picks its words from `RingClaim`
   (`lib/core/alarm/ring_claim.dart`).
   Why: iOS 26 and later rings through AlarmKit. Older iPhones get a Time-Sensitive notification
   and must never be told it rings through silent mode.
7. **Never commit** a `.p8`, a keystore, `google-services.json`, `GoogleService-Info.plist`, a
   `.env`, a RevenueCat key or a price.
   Why: the repo is public. Signing identities live in the Apple developer account.
8. **Build screens from `lib/design/`.** Never add components to `lib/design_system/` (the older
   folder, which re-exports `lib/design/`). `docs/design-system/NOTES.md` lists the components.
   The debug route `/gallery` shows every one.
9. **The Crit face is always yellow (`#FFC93C`)** with dark outline and features, in both themes
   and on every canvas. Tell faces apart by expression, size, tilt or a ring, never by head colour.
10. **Read the `motion` skill before adding or changing an animation**
    (`.claude/skills/motion/SKILL.md`). One large living thing per screen, everything under it
    quiet. No Lottie, no Rive, no video.
11. **Write changelog lines with cider, in the same branch as the change.** User-visible changes go
    in `CHANGELOG.md`, polish and internals in `dev-notes/CHANGELOG.md`. Neither names prices,
    keys, task numbers or planning docs. How-to: `.claude/skills/changelog/SKILL.md`.
12. **Never compare `runtimeType.toString()` or a class name to a string.**
    Why: release builds are obfuscated, so the names are mangled. Enum `.name` is safe.
13. **Never call `FirebaseCrashlytics` directly.** Errors go through `TelemetryGate.recordError`
    (`installCrashHooks` in `lib/core/telemetry/crash_hooks.dart`).
    Why: the gate respects the user's crash-reporting switch and drops the message, which can
    quote a server answer.
14. **Only `scripts/release-ios.sh` and `scripts/release-android.sh` put a build in a store.**
    Symbols, bump and tag, and reading a trace: `docs/release.md`.
15. **`docs/api.md` and `docs/ARCHITECTURE.md` are generated copies.** Refresh them with
    `make sync-contract`. Never edit them.
16. **On the Apple developer portal, a wrong team looks like a missing item.** The portal never
    says "wrong team". Its team switcher is top right and does not follow Xcode. The team is
    `N358LNAWS2`.

## Names

Use these in code, strings, comments and PRs. Never use one for another. History and old key
names: `docs/glossary.md`.

| Name | Means | Code |
|---|---|---|
| Feature Guides | per-screen spotlight walkthroughs, replayable from Settings | `lib/features/feature_guides/` |
| Cloud | the paid plan, in anything a person reads. Code keeps `hosted` | `Holding.hosted`, `PaywallProduct.hosted` |
| In-App Notice | a bar Home pins above the tab bar until its condition clears | `lib/features/in_app_notices/` |
| Ask | an interruptive sheet or popup. Never call a sheet a notice | `HomeAskRules`, `SetupGate` |
| Local Reminders | notifications the app schedules for itself | `lib/features/local_reminders/` |
| Remote Reminders | not built. Server-sent reminders | none |

"Our server" in copy, never "Crit Alarm Cloud", so Cloud only ever means the plan.

## Before you touch a feature

Read its doc first. Each one says what the code does and why. Docs are in `docs/features/`.

| Working on | Read |
|---|---|
| Setup order, adding or moving a setup step, remote flows | `onboarding-flow-engine.md` |
| The setup offer (paywall inside setup) | `onboarding-offer.md` |
| Permissions, first topic, real ring, after the ring, hook up | `onboarding-steps.md` |
| Setup funnel events, what counts as real use | `onboarding-analytics.md` |
| Home: notices, status cards, cream cards, setup checklist | `home.md` |
| The Pro pack | `pro-pack.md` |
| The weekly delivery check | `weekly-check.md` |
| Backups and restores | `backups.md` |
| `LocalStore` and the held topic list | `local-store.md` |
| Building for web | `web.md` |

What may show during and after onboarding (guides, notices, asks, Local Reminders) is under
"Setup order" in `docs/glossary.md`. Do not route Feature Guides through `SetupGate`: it waits for
the Topics guide, which could then never start.

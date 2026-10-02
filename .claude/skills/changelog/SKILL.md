---
name: changelog
description: Use when a change in critalarm-app is done and needs a changelog line, when asked to update the changelog, write release notes or "What's new" text, or when cutting a release. Decides user changelog vs dev notes and writes the entry with cider.
---

# Changelog entries with cider

The app keeps two changelogs. cider writes both. Never edit either file by hand.

| File | Reader | What goes in |
|---|---|---|
| `CHANGELOG.md` | Users, and the store "What's new" text | Changes a user would notice and care about |
| `dev-notes/CHANGELOG.md` | Developers | Everything else worth knowing: refactors, tokens, components, prefs keys, build flags, tooling, tests, small UI polish |

## 1. Decide where the line goes

Ask: would a user who opened the app notice this and care?

- **Yes, user changelog:** a new feature or screen, a change in what the app does (limits, schedules, what rings), a bug they could have hit (wrong copy that misleads, a broken flow, a crash).
- **No, dev notes:** spacing, colours, a moved or restyled button, a nicer empty state, wording tweaks, a refactor, new tests, a renamed token, a new prefs key, a build or tooling change.
- **Both:** a user-facing change that also changes something developers must know (a new prefs key behind a new feature). One user line, one dev line.
- **Neither:** a pure test fix, a typo in a comment, a change reverted in the same branch.

When unsure, put it in dev notes. Leaving small polish out of the user changelog is the point of the rule.

## 2. Pick the type

`added`, `changed`, `fixed`, `removed`, `deprecated`, `security`. These are the Keep a Changelog sections cider writes.

## 3. Write the line

- One line. No hard wrap: cider keeps one line per entry.
- User entries speak from the user's side: "History keeps 90 days on Pro.", not "HistoryWindow.shownDays returns 90 for paid."
- Dev entries name the thing: the file, class, token or key.
- Plain words, active voice, a full sentence with a period. No em or en dashes (the script refuses them). No filler adverbs.
- The repo is public: no prices, keys, task numbers (A38), or links to `planning/`.

## 4. Run it

From the repo root (or a worktree root):

```sh
make log TYPE=fixed MSG="Android onboarding no longer says your phone needs iOS 26."
make devlog TYPE=changed MSG="AppKeyValueRow stacks label and value when they do not fit."
```

`tool/changelog.sh` activates cider (`fvm dart pub global activate cider`) the first time. Commit the changelog change on the same branch as the code.

## 5. Merging

Two branches that each added lines conflict in the same section. Keep every line from both sides, one per line, under the right `###` heading.

## 6. Releasing

After the version bump in `pubspec.yaml`:

```sh
make changelog-release
```

It sets `dev-notes/pubspec.yaml` to the app version, then moves `## Unreleased` under `## <version> - <date>` in both files. For the store "What's new" text, take the lines under that version in `CHANGELOG.md` and shorten them; never use dev notes.

## Checks before you finish

- `git diff CHANGELOG.md dev-notes/CHANGELOG.md` shows only new single lines under `## Unreleased`.
- No small polish in `CHANGELOG.md`.
- `grep -n "—\|–" CHANGELOG.md dev-notes/CHANGELOG.md` prints nothing.

# worktrees/

Git worktrees live here, one folder per branch. This README is the only tracked
file in the folder; `/worktrees/*` is git-ignored.

A worktree is a second checkout of this repo on a different branch, sharing one
`.git`. Two agents can work at once without fighting over `HEAD`, and neither has
to stash.

## Make a worktree

```
make worktree-new NAME=search-overlay
```

That runs `git worktree add worktrees/search-overlay -b task/search-overlay main`
and then prepares it. Branch names get the `task/` prefix automatically.

To work on a branch that already exists:

```
make worktree-new NAME=search-overlay BRANCH=task/search-overlay
```

## Why a fresh worktree does not compile

`git worktree add` copies tracked files only. This repo git-ignores everything
codegen produces, so a new worktree is missing:

- `.dart_tool/` and the resolved package list (`fvm flutter pub get`)
- every `*.g.dart` and `*.freezed.dart` (`make gen`)
- `lib/gen/locale_keys.g.dart` (`make l10n`, a separate generator)

`.claude/hooks/worktree-prep.sh` runs all three for you. It fires on
`WorktreeCreate`, on `SessionStart`, and after any Bash call, so a worktree made
by hand gets picked up too. The work runs detached because codegen takes minutes
and a hook gets seconds.

The hooks only look at worktrees inside this folder. A worktree parked somewhere
else is never prepped, reported on, or removed by this tooling.

Watch it:

```
tail -f worktrees/<name>/.worktree-prep.log
```

`.worktree-ready` appears in the worktree when it can compile. That marker is
also what stops the hook re-running. Delete it to force a re-prep.

The hook also copies the git-ignored machine-local files across, when the main
checkout has them:

| File | Why a worktree needs it |
|---|---|
| `.env`, `.env.local` | app config |
| `.claude/settings.local.json` | local agent settings |
| `android/app/google-services.json` | without it a release build fails at `:app:processReleaseGoogleServices` |
| `android/key.properties` | release signing |
| `ios/Runner/GoogleService-Info.plist` | the iOS half of the same Firebase config |

None of those are in the repo, and they must stay out of it: this is a public
repo and they are secrets.

## Finish a worktree

```
make worktree-list     # every worktree, its branch, and whether it is clean
make worktree-clean    # remove the ones merged into main with nothing uncommitted
```

`make worktree-clean` refuses to touch a worktree with uncommitted changes or a
branch that is not yet an ancestor of `main`. The `SessionEnd` hook prints the
same verdict at the end of a session so nothing is forgotten.

## Rules

- Branch names are `task/<slug>`. Never `claude/<slug>`.
- One task, one branch, one worktree, one PR.
- Never run two agents in the same worktree.

# Local store and the held topic list

Moved out of AGENTS.md on 2026-10-17, text unchanged. Read before changing this area.

**Local store and the held topic list.** `LocalStore` (`lib/core/store/local_store.dart`,
`critalarm.db`, schema version 3) holds three tables. `incidents` and `messages` are the
archive: the user's own copy, deleted only by the auto-delete setting. `topics` is the last list
the server gave, kept so the app opens with the topics it already knows. It is a copy the server
replaces on every answer, not an archive.

- A table change bumps `LocalStore.schemaVersion` and adds a step in `_upgrade`. A test builds
  the previous version's file by hand and checks the old rows survive (`test/core/store/`).
- What a `topics` row holds: name, Critical delivery, the three timers, the relay content
  setting, when the topic was made (milliseconds, because the Topic screen matches what it
  remembered about a topic by that exact time) and the order the server gave. A topic token, its
  id and its name are never written. The server shows a token once, on creation. An empty list
  is stored as no rows, so an empty copy is never shown as "no topics yet".
- Every row carries a scope: a hash of the saved server address and the account id
  (`heldScopeFor`, `lib/core/store/held_scope.dart`). A read names its scope and gets nothing
  for any other, and deletes what it finds under another. `TopicsCubit` writes only when the
  scope is the same as when the request went out and no sign-in, sign-out or account switch
  happened since (`_generation`). `AccountData.forget()` (sign-out, account delete, dead
  credential, a moved phone, a connect to a different server) and `LocalStore.clearServerData`
  both clear it.
- `TopicsCubit.loadHeld()` starts the state from the copy. `main()` calls it before `runApp`,
  after the store is open and after `MovedPhoneReset`, with an 800 ms limit. The state is ready
  and `TopicsState.isKept`, so screens draw the topics as real data with no loading state.
  `ensureLoaded()` still asks the server once while `isKept`. The first answer replaces the
  list and clears `isKept`, and a topic deleted elsewhere is gone from both. A failed answer
  keeps the list and sets the usual failure.
- While `isKept`, `HomeCubit` and `TopicDetailCubit` do not run their full build, which polls
  every topic's messages, because the server's list is about to say which topics those are. The
  Topic screen's seed (`seedFor`) and the Home card guess (`heldTopicsFrom`) read the held list.
- Write-through: the refresh, `applyTopic` (the Critical switch, from the Topic screen and from
  setup's real ring step), a delete the server took, and `noteCreated`, which
  `CreateTopicUsecase.onCreated` calls for a new topic (stored without its token, memory left
  to the next refresh). Nothing is written before a list is loaded.
- Where the store is not open (the web build, or `local_store_open_failed` at launch) the list
  stays in memory and the app behaves as it did before the copy existed. Push, alarms and
  incident handling never read the `topics` table.


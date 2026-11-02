# Local store and the held topic list

Moved out of AGENTS.md on 2026-10-17. Updated 2026-11-02 with the account scope, held rows and schema 4 text that main added after the move. Read before changing this area.

**Local store and the held topic list.** `LocalStore` (`lib/core/store/local_store.dart`,
`critalarm.db`, schema version 4) holds three tables. `incidents` and `messages` are the
archive: the user's own copy, deleted by the auto-delete setting and by an account delete.
`topics` is the last list the server gave, kept so the app opens with the topics it already
knows. It is a copy the server replaces on every answer, not an archive.

- A table change bumps `LocalStore.schemaVersion` and adds a step in `_upgrade`. A test builds
  the previous version's file by hand and checks the old rows survive (`test/core/store/`).
- Archive rows are scoped by account, like topics. `incidents` and `messages` carry a `scope`
  column (the same `heldScopeFor` hash) and the primary key is `(scope, id)`. Every read in
  `IncidentStore` and `MessageStore` asks for the current scope inside the store, so no caller
  can forget to filter, and a read for no scope returns nothing. This includes the `since`
  cursor (`newestUpdatedAt`): an account that signs in on a phone another account used asks the
  server for its whole window.
- The scope comes from `HeldAccountScope` (`lib/app/held_account_scope.dart`), which the topic
  list uses too. The account is the one the person signed in to (`identity_account_id`) and, when
  nobody is, the device's own. The device's account id is saved only at a registration, so after a
  link, a switch or a merge it still names the old anonymous account until the next launch. Never
  build a scope from the device's account id alone.
- A merge ("keep both") moves the old account's archive rows to the new account
  (`LocalStore.mergeArchive`, called from `ApiAccountRepository.merge`). A row the new account
  already holds under the same id stays.
- A sign-out keeps the archive rows, so the same account finds its history again. They are never
  shown to another account. An account delete removes that account's rows
  (`AccountData.forgetDeleted`, called by `wipeAfterDelete` only; a dead credential and a sign-out
  call `forget`). A connect to a different server (`clearServerData`) and the auto-delete setting
  cover every scope.
- Every answer that carries incidents or messages is checked against the account that asked.
  `ScopedApiClient` (`lib/core/api/scoped_api_client.dart`, wraps `HttpApiClient` in `lib/app/di/register_core.dart`)
  reads the scope (`HeldAccountScope`, server and account) when `getIncidents`, `getIncident`,
  `ackIncident`, `closeIncident`, `publishMessage` or `pollMessages` starts and again when the
  answer or the error arrives. If the two differ it throws `StaleAccountException`. Only the
  scopes are compared, so a sign-in, a purchase or a connect that leaves the account as it was
  changes nothing, and an account that was left and came back keeps its answer. Every caller
  treats the exception as "nothing happened": the repository hands back what the phone holds
  for the account it is on (lists, polls) or a failure (single incidents), the ack queue counts
  the send as done, and the alarm controller, the first message watcher and the message sync
  skip the item. A new direct read of those routes belongs on this client, never on
  `HttpApiClient`.
- Archive writes use a ticket as a second guard (`beginWrite`, `ArchiveScope` in
  `lib/core/store/archive_scope.dart`) taken before the request or event the data came from.
  The write is stored under the scope it started with, and only when the phone is still on that
  scope. The check runs inside the write's transaction, and every delete or merge invalidates
  open tickets first, so a late write cannot bring deleted rows back. Otherwise the write is
  dropped and never stored under the next account. Alarms are received, sounded and
  acknowledged before and without this, so a dropped write costs a row and nothing else. The
  next sync fetches the incident again.
- `AccountCubit.deleteAccount` reads the account it is deleting at the start and passes it to
  `wipeAfterDelete(accountId:)`. The repository holds no state about it.
- The upgrade to version 4 stamps every existing incident and message with the scope the phone
  is on (`LocalStore.open(scope: ...)`, read once during the upgrade, so it must not touch the
  database). A file whose tables already have the column is left as it is. With no saved server
  the rows get the empty scope, which no read asks for. A `LocalStore` opened with no `scope`
  (unit tests, capture tools) keeps every row under one scope.
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
- **Held rows.** `HeldRows` (`lib/app/state/held_rows.dart`) reads the current scope's incidents and
  each held topic's messages once at launch, through `HeldArchive` (the incident repository reads the
  stores; no raw SQL), right after `loadHeld()` and inside the same 800 ms limit. The plan
  (`HeldPlan`) is read first and a snapshot is never taken without it, because the history window
  decides which rows show. It also notes each topic's rows in `TopicGlances`. Home (`_seedFromHeld`),
  History (`_seedFromHeld`) and the Topic screen (`seedFor`) draw their first frame from the
  snapshot and make no request; the full build, which polls each topic, still waits for the server's
  lists and runs once.
- The snapshot is never put in `IncidentsCubit`. Everything that rings, badges, hands over to the
  alarm screen or syncs widgets reads that list, so a stored open alarm there could act. Home
  keeps `ringingIncidentId` null while its rows are the phone's copy (`_fromPhone`, also on the
  timer's repaints) unless the shared list holds that incident, shows them as old when the server
  never answers, and the first answer replaces every row. The snapshot is dropped by any change
  of the shared incident list (an alarm the alarm screen applies before the first answer counts)
  and by any change of account (`AccountIdentityChanges`). While rows are still the copy, Home
  (`_reseedFromShared`) and the Topic screen (`_applySharedToCopy`) lay the shared list over it,
  before the answer and after it while the topic list is still the stored one, so a real alarm is
  never shown as calm. The Topic screen applies an update that came during its own change when
  that change ends. A new reader of stored alarms at launch goes through
  `HeldRows`, never through `IncidentsCubit`.
- Launch cost: `main` skips the `HeldRows` read when the first location is an alarm screen
  (`HeldRows.skipsLaunchAt`), `heldPlanFrom` answers from the plan already read and never waits
  for it (no plan, no snapshot), and a read that outlives the 800 ms limit is abandoned
  (`HeldRows.abandon`) so it builds nothing under the first frames.
- Where the store is not open (the web build, or `local_store_open_failed` at launch) the list
  stays in memory and the app behaves as it did before the copy existed. Push, alarms and
  incident handling never read the `topics` table.

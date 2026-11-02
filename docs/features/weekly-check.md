# Weekly check

Moved out of AGENTS.md on 2026-10-17, text unchanged. Read before changing this area.

**Weekly check.** Once a week the relay sends an enrolled phone a push that
shows nothing, and the phone answers with a receipt (api.md §4.5 and §5.4).
It needs Cloud, because the relay runs it, and it does not exist on a
server of the user's own. The Pro pack does not unlock it. The code is in
`lib/features/weekly_check/`, plus the native handlers.

- `featureTable` holds the rule: `weeklyCheck` is unlocked by Cloud and is
  `OwnServerRule.notOffered`. `FeatureAccess.decide` answers
  `FeatureDecision.notOffered` there, which is its own answer: not open,
  and not a lock. A screen says in plain words that the feature is not
  available and opens no paywall. `weeklyCheckAccessFor` turns the decision
  into the four words this feature acts on (`WeeklyCheckAccess`).
- The weekly row inside the proof card on Will it wake me (`WeeklyCheckCardRow`) is one of three: the switch
  with Cloud held, a locked row that opens the Cloud paywall through
  `AccessLock`, or one line saying it is not available on a server of your
  own.
- A lapse takes nothing away. The relay keeps the device enrolled and
  answers `off` with the reason `tier`. The row locks from what is held,
  and when Cloud is back the check goes on with no new tap. A reason the
  app does not know, `pack` from before 1.19.0 included, is no reason.
- A lapse is never a miss. `WeeklyCheckNoticeRule` answers no while the
  plan is away, and sets aside what the phone learned before it last saw
  the plan away (`weekly_check.plan_away_at`), so a clock that ran on
  through a lapse raises nothing when Cloud is back.
- On a server of the user's own the app never sends `"enabled":true`. A
  phone that was enrolled before sends `"enabled":false` once
  (`WeeklyCheckMonitor.accessChanged`). A send that fails is tried again on
  the next read, and nothing waits on it.

- Native code answers the push, with no Dart running. Android:
  `CheckPush.fromData` is the first thing `PushRouter.route` asks, and a check
  goes to `WeeklyCheckResponder`, which schedules `CheckReceiptJobService`.
  iPhone: `CheckPush(payload:)` is the first thing the background handler in
  `AppDelegate.swift` asks, and a check goes to `WeeklyCheckResponder`.
  Everything after that line is the incident path, and a check never reaches
  it.
- The check shows nothing: no notification, no sound, no Live Activity, no
  alarm. It writes one preference, `weekly_check.native`, which the incident
  path never reads. A receipt gets three tries and is then dropped.
- The push callback only parses and hands off. Android does the rest on
  `WeeklyCheckResponder`'s own single thread and in the job. iPhone does it
  on `WeeklyCheckResponder.queue`, a serial queue. Every change to the
  record goes through that thread or queue. Nothing the incident path uses
  is held. On iPhone the fetch completion handler is called once, when the
  receipt work ends or after `bound`.
- On Android a stop belongs to one run of one job (`CheckReceiptJobs`),
  never to the service object, which the system reuses.
- The receipt carries `dv_`, so it goes to an https relay only. A debug
  build may also reach `127.0.0.1`, `localhost` and `10.0.2.2` over http
  (`PlainHttpRelays` in `src/debug`, `plainHttpHosts` under `#if DEBUG`).
  With any other http relay the arrival is recorded and nothing is sent.
- `check_id` is in the push and nowhere else. It is never logged and never
  written to disk.
- The receipt goes to the relay in the saved session with the device's own
  `dv_`. Android reads `flutter.api_session`, `flutter.device_id` and
  `flutter.device_token` from the app's preferences. iPhone reads
  `flutter.api_session` from the app's preferences and the unsynced Keychain
  item `app.critalarm.device_identity`.
- `WeeklyCheckMonitor` reads `GET .../check` on launch and resume, once a
  minute at most, and keeps the answer on the phone. The switch calls
  `PUT .../check`. A `403` tier error has the tier read again through a
  device registration, and what is held then locks the row.
- A received check is never shown as proof that alarms work.
- One missed round changes the row and nothing else. Two misses in a row,
  or the phone's own clock passing `notice_after` with no check received
  since, make the weekly check a check that needs a look
  (`WeeklyCheckNoticeRule`, read through `WeeklyCheckSource`), so Home's
  status card counts it and the Reliability screen lists it. A
  check that arrived with no receipt answer ends only its own window: the
  phone then counts two windows of 11 days from that arrival. Home has no
  card or notice of its own for it.
- The list of rounds is its own page (`AppRoute.weeklyCheckRounds`) and
  needs no plan.
- `MockServer.seedWeeklyCheck(state)` puts the mock relay in one state, and
  `openWeeklyCheckRound()` returns the id a push would carry. The mock
  gates the check on `MockServer.accountTier`, which the developer switch
  for Cloud sets in a mock build.


# Setup funnel and real use

Moved out of AGENTS.md on 2026-10-17, text unchanged. Read before changing this area.

**Setup funnel events.** Each setup step sends two analytics events,
`onboarding_step_viewed` and `onboarding_step_completed`. Each has three
parameters and no others: `step` (a step id from the registry), `flow_id`
(the flow the user is in) and `ms_since_previous` (whole milliseconds since
the previous step event in this app run, 0 for the first one). No content,
topic name, URL, token or device id ever goes in them. `OnboardingFunnel`
(`lib/core/telemetry/onboarding_funnel.dart`) sends them, fed by
`OnboardingFlowEngine.onStepEvent`, so screens make no calls of their own.
The names live in `AnalyticsEvents` and the wrapper is `OnboardingAnalytics`.

The `use` step adds one event, `onboarding_use_picked`, with `use` and
`flow_id`. `use` is one of `servers`, `homelab`, `jobs`, `home`, `other` or
`skipped`, and the funnel drops any other word. The three offer events carry
the same `use` parameter (the answer's wire id, `other` when there is none),
so conversion can be read by answer. An offer event buffered before the
parameter existed is sent as `other`. Both go through the same buffer and the
same consent rule, and a replay records neither. The hook-up switch says so:
step names, timings and the answer to the question, never messages. The
answer is never sent to the server.

The consent question comes on the last step, so events wait on the phone
until the user answers:

- No answer yet: each event is added to the prefs list
  `pending_onboarding_events`. Nothing is sent and no analytics call is made.
- Opt in (the setup switch, Settings > Privacy or the Home consent sheet,
  whichever comes first): the waiting events go through
  `TelemetryGate.logEvent` once, in order, and the list is deleted. Later
  events go straight to the gate.
- Opt out, or analytics switched off again: the list is deleted and nothing
  is sent. On the Home consent sheet, Not now counts as opting out.
- No answer for 7 days after the first event: the list is deleted and no more
  events are held for this install. The age is checked at app launch and
  whenever an event is added.
- The list holds at most 100 events. When it is full a new event is dropped
  and the old ones stay as they are. A list that does not read back exactly as
  written is deleted, never sent.
- A replay (`?demo=true`, developer "Redo onboarding" and "Open a step") records
  nothing. Neither does a setup screen opened after setup is complete.
- `flow_id` must match `[A-Za-z0-9._-]{1,40}` and `step` must be a registry id,
  or the event is dropped.

Every answer is saved through `ObservedPrivacyRepository`, which tells the
funnel. A new way to answer needs no code of its own as long as it saves
through `PrivacyRepository`. The funnel keeps who answered what under
`onboarding_funnel_state` (`in`, `out` or `expired`), because
`privacy_analytics_enabled` reads false both for "never asked" and for "said
no".

**Real use.** Setup rings the phone on purpose, so those alarms are not
the user's own use of the app. `countsAsRealUse`
(`lib/features/incidents/domain/real_use.dart`) is the one decision: false
for a test setup asked the server for, for the alarm the first hook-up
message set off, and for the phone-only test. `SetupTestRing.setupIncidentIds`
(`onboarding_setup_incidents`) keeps those ids after setup completes,
because the acknowledgement often comes later. Three places read it:

- The alarm screen: an acknowledgement that is not real use stamps no
  last-acknowledged time and opens no sheet.
- `HomeAskRules`' newest acknowledgement (`newestRealAckedAt`), which the
  rating ask and the Local reminders sheet on Home wait for.
- `LocalReminderInputsReader`, where such an incident counts as a test for
  the fire drill and morning-after rules.

`EndSetupTestUsecase.closeLeftovers` does not close a leftover test
incident that now holds a message of the user's own. It drops it from the
list and leaves it for them to answer.


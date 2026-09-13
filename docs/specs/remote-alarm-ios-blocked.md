# Blocked: contract gaps in the iOS remote-alarm work

The iOS alarm and Live Activity work builds against three things `docs/api.md`
does not carry. AGENTS.md says not to invent API surface, so they are written
down here instead of being decided inside the task. The orchestrator changes
the contract; nothing in this repo edits `docs/api.md`.

Everything else in the task is built and tested. These three are the parts that
cannot be called correct until the contract catches up.

## 1. There is no §5.3

The task points at "§5.3 payloads" for the Live Activity push shapes. `api.md`
stops at §5.2 (FCM). Neither §5.1 nor §5.2 describes an
`apns-push-type: liveactivity` payload, so the app has no contract for:

- `event: start` with `attributes-type`, `attributes` and `content-state`.
- `event: update` and `event: end`.
- Which field carries the incident id, the topic and the server on a start.

**What the app assumes today.** The attributes are
`CritAlarmIncidentAttributes { incident_id, topic, server }` and the content
state is `{ state, title, opened_at }`, all snake_case, matching every other
payload in `api.md`. `attributes-type` is `CritAlarmIncidentAttributes`. See
`ios/Shared/Alarm/IncidentAlarmAttributes.swift` and the four fixtures in
`scripts/push/`.

## 2. §4.2 has no token route

The task names `POST /relay/v1/devices/{id}/tokens` with `kind: la_start` and
`kind: la_update`. §4.2 lists registration, re-registration and subscriptions,
and nothing else. There is no route for a Live Activity token and no list of
token kinds.

**What the app assumes today.**

```
POST /relay/v1/devices/{device_id}/tokens
  Authorization: Bearer dv_...
  { "kind": "la_start" | "la_update",
    "token": "<hex>",
    "incident_id": "inc_..." }    // la_update only
→ 2xx
```

`la_start` is one per install; `la_update` is one per card. The app treats a
non-2xx as "try again next launch". Implemented in
`lib/core/api/http_api_client.dart` and
`lib/core/alarm/live_activity_token_registry.dart`.

## 3. A topic has no sound

The task asks for "the topic's selected sound from the sound library". §3.1
topics carry `name`, `critical`, `repeat_interval_s`, `max_ring_s`,
`desk_timer_s`, `relay_content` and `created_at`. There is no `sound` field,
the app has no sound library screen, and the repo had no bundled sound files.

**What the app does today.** Every alarm uses one bundled sound,
`ios/Runner/Sounds/alarm.caf`, which is the file `api.md` §5.1 already names in
the APNs payload (`"sound": { "name": "alarm.caf" }`). The scheduler takes a
sound name as an argument (`IncidentAlarmScheduler.schedule(sound:)`), so a
per-topic sound is one field away once the contract has one.

AlarmKit resolves `.named()` against the app bundle. A user-picked sound from
`Library/Sounds` was not tried, because there is nothing in the app that can
pick one yet.

## 4. No push kind says an incident is over

Related, and the reason cancel-on-close works the way it does. §4.1 and §5.1
allow `kind` values `open`, `repeat`, `reopen` and `p4`. None of them means
"closed" or "expired", so no push tells the device to stop ringing.

**What the app does today.** It reconciles on launch and on resume:
`IncidentAlarmController.reconcile()` reads every incident that still has a card
up, calls `GET /v1/incidents/{id}` (§3.2), and cancels the alarm and ends the
card for anything the server no longer has open or acked. An unreachable server
leaves the card up, because a stale card beats a missed incident.

A `kind: "closed"` on the alert push, or a documented
`apns-push-type: liveactivity` end, would make this immediate instead of
launch-time.

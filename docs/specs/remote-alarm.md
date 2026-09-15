# Feature spec: Remote-triggered alarm and persistent status card (iOS + Android)

Status: draft for agents to flesh out
Platforms:
- iOS 26+ for AlarmKit; iOS 17.2+ for push-to-start Live Activity
- Android 8+ baseline; Android 14+ permission rules apply; Android 16+ for Live Updates

## Problem

A backend must wake a person on their phone when an event happens. The app is not open. The phone may be in silent mode, Do Not Disturb, or a Focus. A normal push notification is not loud enough and does not persist. The person must be able to acknowledge from the lock screen without opening the app.

## Goals

1. A remote event can start a loud, persistent alarm on the device while the app is in the background or not running.
2. A remote event can place a persistent card on the lock screen that shows the event and offers acknowledge and snooze actions.
3. iOS works without the Critical Alerts entitlement. Android works without a Play Store special-access review where possible.
4. The backend can update or end the card without the app opening.

## Non-goals

- Guaranteed delivery. Push delivery is best-effort on both platforms; this spec accepts that.
- Sound or vibration from the status card itself. It is a visual surface only.
- Rotations, escalation, or multi-user routing.
- Custom OEM integrations (Samsung Now Bar, Xiaomi, Huawei). Document them; do not build for them.

## Part A — Remote-triggered alarm

### Shared behaviour

- Backend sends a push for the event.
- The device schedules or starts an alarm within seconds.
- The alarm overrides silent mode and Do Not Disturb.
- The alarm shows Stop and Snooze. Stop reports an acknowledge to the backend. Snooze re-fires after a fixed interval.
- The alarm keeps re-firing until acknowledged, up to a cap.

### iOS

Trigger paths, in order. Keep the first that works.

1. Alert push with `mutable-content: 1`. The Notification Service Extension schedules an AlarmKit alarm a few seconds out. **Unverified: not confirmed that AlarmKit can be called from an extension. Spike this first on a real device.**
2. Background push with `content-available: 1`, priority 5. The app is woken and schedules the alarm from the main process. iOS may delay or drop these.

Requirements
- P0: `NSAlarmKitUsageDescription` set. Authorization requested during onboarding.
- P0: If authorization is denied, fall back to a normal notification and log the reason.
- P0: Widget extension provides the alarm Live Activity.
- P0: Custom alarm sound (mp3; aiff reported not to work).
- P1: Re-fire after the system auto-mutes, until acknowledged.
- P1: Observe `AlarmManager.alarmUpdates` to keep local state in sync.
- P2: Cancel pending alarms when the backend reports the event resolved.

### Android

Trigger path

1. FCM data message with `priority: high`. Do not use a notification message; the app must run code.
2. `onMessageReceived` starts a foreground service.
3. The service plays the alarm sound on the alarm audio stream (`USAGE_ALARM`) in a loop and posts a full-screen-intent notification on a high-importance channel with `CATEGORY_ALARM`.
4. The full-screen intent shows a lock-screen alarm activity with Stop and Snooze. When the screen is on, the same notification shows as a heads-up with the two actions.

Why this path: Android has no AlarmKit. The alarm stream bypasses ring-mode silence, and Do Not Disturb allows alarms by default. A foreground service keeps the sound alive.

Requirements
- P0: `POST_NOTIFICATIONS` runtime permission requested during onboarding (Android 13+).
- P0: Full-screen intent. On Android 14+, `USE_FULL_SCREEN_INTENT` is granted at install only for apps Play classifies as calling or alarm apps. Check `canUseFullScreenIntent()`; if false, deep-link the user to `ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT` during onboarding. Without it the alarm still sounds but no lock-screen takeover appears.
- P0: Foreground service type declared in the manifest (Android 14+). Use `specialUse` with a Play Console declaration, or `mediaPlayback`. Decide before submission.
- P0: Alarm channel created once with `IMPORTANCE_HIGH`, alarm sound, vibration, lock-screen visibility public. Channel settings cannot be changed after creation; version the channel ID.
- P0: Wake lock held while sounding. Released on Stop.
- P1: Do Not Disturb bypass on the notification itself. Request `ACCESS_NOTIFICATION_POLICY` via `ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS` and set `setBypassDnd(true)` on the channel. Optional because the alarm stream already sounds under default DND; this covers users who turned alarms off in DND.
- P1: Battery-optimization exemption prompt (`ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) during onboarding, with a plain explanation. Improves FCM delivery under Doze. Play policy allows this only when core function needs it; document the justification.
- P1: OEM battery-killer guidance screen (link to dontkillmyapp.com content) for Xiaomi, Huawei, Oppo, Samsung.
- P1: Snooze uses `AlarmManager.setAlarmClock()`. Declare `USE_EXACT_ALARM` if the app is an alarm app by Play's definition; otherwise `SCHEDULE_EXACT_ALARM` is denied by default on Android 14 and needs a settings deep link. Check `canScheduleExactAlarms()` and fall back to an inexact alarm.
- P2: Local re-fire timer if the FCM message arrives but the service is killed.

FCM constraints to design around
- High-priority messages that do not show a notification quickly can lose high-priority quota. Always post the notification inside `onMessageReceived` before doing anything else.
- Force-stopped apps do not receive FCM until the user opens the app again. Show this in the diagnostics screen.

### Acceptance (both platforms)

- Given the app is not running and the phone is in silent mode with Do Not Disturb on, when the backend sends the trigger, then an alarm sounds and shows on the lock screen within 30 s, or the push is logged as dropped.
- Given the alarm is ringing, when the user taps Stop, then the backend receives an acknowledge within 10 s.
- Given the alarm permission is denied, when the trigger arrives, then a normal notification appears and no crash occurs.
- Android only: given full-screen intent permission is not granted, when the trigger arrives, then the alarm still sounds and a heads-up notification with Stop and Snooze appears.

## Part B — Persistent status card

### Shared behaviour

- Backend starts a card for an event without the app running.
- Card shows: event title, time, state, Acknowledge and Snooze actions.
- Backend updates state to acknowledged, snoozed, or resolved, and ends the card.
- Actions run without opening the app and report to the backend.

### iOS — push-to-start Live Activity

- On every launch the app reads the push-to-start token and streams updates. Uploads to backend. One token covers all activity types.
- Backend sends `apns-push-type: liveactivity`, priority 10, `event: start`, with `attributes-type`, `attributes`, `content-state`.
- System starts the activity, wakes the app briefly. App captures the per-activity update token and uploads it.
- Actions are App Intents.

Requirements
- P0: Onboarding starts one local Live Activity so the user answers Allow/Don't Allow before any remote start. Update tokens are not issued until Allow is tapped.
- P0: Token upload is idempotent and retried. Handle a push-to-start token that stays nil (seen in the field on iOS 26.5): show "not ready" in diagnostics, retry on each launch.
- P0: One start per event. The system throttles repeated starts.
- P1: On launch, end any activity whose event is already resolved on the backend.
- P1: Content-free mode: attributes carry only an event ID; the card fetches details after start.
- P2: Deep link from the card to event detail.

### Android — Live Update (16+) with ongoing-notification fallback

- Backend sends an FCM data message with `priority: high` and the event state.
- `onMessageReceived` posts or updates one ongoing notification keyed by event ID.
- On Android 16+, the notification is built as `ProgressStyle` (or `BigTextStyle`), marked ongoing, given a short status-chip text, and promoted with `requestPromotedOngoing()`. It then appears expanded on the lock screen and always-on display and as a status-bar chip.
- On Android 8–15, the same ongoing notification shows normally with action buttons. Samsung One UI 7+ may surface it in the Now Bar; do not depend on it.
- Actions are notification action buttons backed by a `BroadcastReceiver`. They call the backend and update the notification without opening the app.
- Resolved: backend sends a final update; the app cancels the notification.

Requirements
- P0: Declare `POST_PROMOTED_NOTIFICATIONS` (Android 16 QPR1+). Check `canPostPromotedNotifications()`; if false, deep-link to the settings page during onboarding. Fall back to a plain ongoing notification if not granted.
- P0: No custom RemoteViews; Live Updates reject them.
- P0: Separate channel from the alarm channel, `IMPORTANCE_DEFAULT`, no sound.
- P0: Idempotent updates: same notification ID per event; stale updates (older state timestamp) are ignored.
- P1: On launch, reconcile notifications against backend state and cancel resolved ones.
- P2: Deep link from the notification to event detail.

Policy note: Google's guidance says Live Updates are for user-initiated, time-sensitive activities and not for alarms or reminders. An open incident awaiting acknowledge is defensible as an ongoing activity. Keep the alarm (Part A) on its own channel and never promote it.

### Acceptance (both platforms)

- Given the app is not running, when the backend sends a start, then the card appears on the lock screen within 10 s.
- Given the card is showing, when the user taps Acknowledge, then the card state changes without opening the app and the backend is notified.
- Given the backend marks the event resolved, when it sends an end, then the card disappears.
- iOS only: given the user has never tapped Allow, when a start arrives, then the card appears with the prompt and no update token is expected.
- Android only: given promoted-notification permission is not granted, when a start arrives, then a plain ongoing notification with the two actions appears.

## How the two parts combine

- The alarm (Part A) is the wake-up. The card (Part B) is the acknowledge surface.
- iOS: when Part A is active, AlarmKit provides its own Live Activity. Do not start a second one for the same event.
- Android: Part A and Part B are two notifications on two channels for the same event. Stop on the alarm and Acknowledge on the card must share one acknowledge handler.
- When Part A is unavailable (permission denied, unsupported OS, or push dropped), Part B still gives a persistent visual.

## Onboarding permission list (for the permissions screen)

iOS: notifications, AlarmKit, Live Activity (via one local activity).
Android: notifications, full-screen intent, exact alarms (or USE_EXACT_ALARM), battery-optimization exemption, promoted notifications (16+), Do Not Disturb access (optional).

## Open questions

- iOS: can the Notification Service Extension call `AlarmManager.schedule`? (Blocking. Engineering spike.)
- iOS: default alerting duration before auto-mute, and whether overnight power management defers fires. (Non-blocking. Measure on device.)
- Android: which foreground service type passes Play review for this use? (Blocking before store submission. Engineering + policy check.)
- Android: does Play classify the app as an alarm app for `USE_FULL_SCREEN_INTENT` and `USE_EXACT_ALARM`? (Blocking before store submission. Policy check.)
- Both: should a snoozed alarm also update the card state, or are they independent? (Design.)
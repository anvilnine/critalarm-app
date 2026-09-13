# Spike: which iOS path can schedule an AlarmKit alarm from a push

Verdict: app-background-push

Run on 2026-09-14 against a real handset. iPhone 15 Pro, iOS 26.6.1, Xcode 26.4.1,
iOS 26.4 SDK. App `app.critalarm` built debug over USB, AlarmKit authorization
granted, push sent through APNs sandbox with `scripts/push/send-apns.sh alarm`.

## The question

The spec (Part A, iOS) lists two trigger paths and says to keep the first that
works.

1. Alert push with `mutable-content: 1`. The Notification Service Extension
   schedules the alarm. Marked in the spec as unverified: it was not known
   whether AlarmKit can be called from an extension at all.
2. Background push with `content-available: 1`. The app is woken and schedules
   the alarm from the main process.

## How it was run

One push carries both flags, so a single delivery exercises both paths at once
(`scripts/push/alarm.apns`). The two sides schedule under different ids so the
result is unambiguous:

- The app schedules under `inc_alarmed_proddb`.
- The extension schedules under `inc_alarmed_proddb-nse-spike`.

Alarm ids are derived from the incident id
(`IncidentAlarmScheduler.alarmId(for:)`), so two successful schedules would show
as two alarms in `AlarmManager.alarmUpdates`.

## What happened

```
CritAlarm: background_push kind=open priority=5 incident_id=inc_alarmed_proddb
CritAlarmAlarm: alarm_scheduled incident_id=inc_alarmed_proddb alarm_id=2831603E-52FD-4DDC-AC7F-3BAC45DE115E in=3s
CritAlarmAlarm: alarm_updates count=1 live=1 alarms=2831603E-52FD-4DDC-AC7F-3BAC45DE115E:countdown
CritAlarmAlarm: alarm_updates count=1 live=1 alarms=2831603E-52FD-4DDC-AC7F-3BAC45DE115E:alerting
```

The system then built AlarmKit's own Live Activity from the widget extension:

```
WidgetRenderer_Activities: Content load successful for key:
  [app.critalarm::app.critalarm.CritAlarmActivity:Attributes type:
   AlarmAttributes<IncidentAlarmMetadata>:D9408F3B-CC4D-4D00-8C30-917C5EB7061D]
```

Path 2 works end to end. The alarm went `countdown` then `alerting`, which is
AlarmKit ringing.

## Why path 1 is not the choice

`count=1`. Only the app's alarm exists. The id the extension would have used is
absent, and no `CritAlarmSPIKE nse_*` line was logged for this push.

Be precise about what that does and does not prove. It shows the extension did
not schedule an alarm on this delivery. It does not prove the AlarmKit API is
refused inside an extension, because the extension produced no log line at all,
so it may not have been run for this push rather than having been run and
failed. Either way path 1 did not deliver an alarm and path 2 did, so path 2 is
what the app is built on.

Anyone revisiting this should keep the `-nse-spike` id trick: two ids, one push,
and the alarm count answers the question with no ambiguity.

## What this decides in code

`AlarmTriggerPath.chosen` is `appBackgroundPush` in both copies, which must stay
in step:

- `lib/core/alarm/alarm_trigger_path.dart`
- `ios/Shared/Alarm/AlarmTriggerPath.swift`

`test/core/alarm/alarm_trigger_path_test.dart` reads this file, parses the
`Verdict:` line above, and fails if either copy drifts away from it. That is why
this document is committed rather than kept as a scratch note: a test depends on
it at runtime.

`AppDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`
is the live trigger. It returns early when the chosen path is not
`appBackgroundPush`, so flipping the verdict flips the behaviour.

## Loose ends found while running this

- The alarm fired with the default sound. `alarm_scheduled` logged `sound=` with
  nothing after it, which points at the `NSLog` format in
  `IncidentAlarmScheduler.schedule` mixing `%.0f` and `%@` rather than at the
  sound being wrong. Worth confirming `alarm.caf` is what actually plays.
- A profile or release build cannot run on a device at all: RevenueCat traps on
  launch with "Test Store API key used in Release build". That is why this was
  run as a debug build with the tooling attached, and it means the "app fully
  killed" case is still untested.

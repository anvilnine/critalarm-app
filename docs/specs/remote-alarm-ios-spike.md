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

---

# Spike 2: where AlarmKit will read a sound from

Answer: bundle only, not yet confirmed on the handset.

(Deliberately not a second `Verdict:` line. `AlarmTriggerPath.fromSpike` reads
the first one in this file and would trip over another.)

Run on 2026-09-14, same handset and toolchain as the spike above. This one was
prompted by the sound library: eight bundled sounds plus anything the user
imports, and none of them can ring unless AlarmKit can find the file.

## The question

`AlarmManager.AlarmConfiguration.timer(...)` takes
`sound: ActivityKit.AlertConfiguration.AlertSound`, and the only way to name a
file is `.named(_ name: String)`. From the iOS 26.4 SDK:

```
// ActivityKit.framework/.../arm64e-apple-ios.swiftinterface:439
public struct AlertSound : Swift.Equatable, Swift.Sendable {
  public static var `default`: ActivityKit.AlertConfiguration.AlertSound { get }
  public static func named(_ name: Swift.String) -> ActivityKit.AlertConfiguration.AlertSound
}
```

A bare name, no URL and no bundle argument. So the system resolves it, and the
question is where it looks. Two candidates, the same two `UNNotificationSound`
uses: the app bundle, and `Library/Sounds` inside the app container.

This matters because Flutter assets are in **neither**. They live inside
`App.framework/flutter_assets/`, which is a nested bundle. `Library/Sounds` is
the only place this app can put a file at runtime, so if AlarmKit will not read
from there, no sound in the picker can ever ring an AlarmKit alarm, bundled or
imported.

## What was measured

The SDK signature above is read straight off the installed iOS 26.4 SDK, so
that part is certain. What is not certain is the resolution order, because
AlarmKit logs nothing about which file it picked, and `AlarmManager.schedule`
does not throw on a name that resolves to nothing: it accepts the string and
the alarm rings with the system default. That means the on-device run cannot
tell "read my file from Library/Sounds" apart from "fell back to the default"
from logs alone. Confirming it needs an ear on the handset, or a recording.

Be precise about what that leaves. It is not known that `Library/Sounds` fails.
It is known that nothing observed so far shows it working, and that the one
sound confirmed to ring on this device (`alarm.caf`) is a compiled-in bundle
resource added to the Runner target.

## What the code does about it

`AlarmSoundPolicy.librarySoundsRingAlarm` in `ios/Runner/AppDelegate.swift` is
the single switch, and it is `false`. While it is false:

- The picker shows "Notifications only" under every sound on iOS and prints one
  line of explanation at the top of the screen.
- AlarmKit keeps ringing the bundled `alarm.caf`.
- `UNNotificationSound(named:)` still uses the picked sound, which does work
  from `Library/Sounds`, so the choice is not cosmetic: it changes what a
  time-sensitive push sounds like.

Flip that one constant to `true` when somebody confirms it by ear, and the
picker, the alarm and the explanation line all change together.

## How to settle it

Put a distinctive sound (the submarine dive horn, not a beep) in
`Library/Sounds` only, schedule an alarm with `.named("submarine_dive_horn.caf")`,
and listen. Horn means `Library/Sounds` works. The stock iOS alarm tone means it
does not. One run, one ear, no ambiguity.

## Why the bundled sounds are converted to caf

`UNNotificationSound` reads Linear PCM, MA4, µLaw and aLaw inside aiff, wav or
caf. It does not read mp3. The eight bundled sounds ship as mp3 (the format
`docs/specs/remote-alarm.md` calls for on iOS), so `SoundLibrary.prepare` in
`AppDelegate.swift` decodes each one to 16-bit PCM in a caf and writes it to
`Library/Sounds` on launch. The same conversion runs on an imported file.

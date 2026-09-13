# Push fixtures

Four APNs payloads, one per delivery class in api.md §1.7, plus a wrapper
around `xcrun simctl push` and an HTTP front door for the mock server.

| File | What it is | What the app does |
|---|---|---|
| `p3.apns` | Priority 1-3. Never comes from the relay, so this is the local shape a poll produces. | Quiet banner, interruption level `active`, tap opens the topic. |
| `p4.apns` | Priority 4, and priority 5 on a topic that is not critical. No incident id (api.md §4.1). | Banner at `time-sensitive`, no ACK action. |
| `p5.apns` | Priority 5 on a critical topic, `relay_content: full`. Real text inline, no `mutable-content`. | `critical` level, category `INCIDENT` with the ACK action. |
| `content-none.apns` | The same push with `relay_content: none`: placeholder text plus `mutable-content: 1`. | The extension fetches `GET /v1/incidents/{id}` and swaps in the real title and body. |

All four point at `inc_alarmed_proddb` or `prod-db`, which is what
`mock_server.dart` serves.

## Sending one

```sh
scripts/push/send.sh p5                 # one payload to the booted simulator
scripts/push/send.sh all                # all four, two seconds apart
scripts/push/send.sh --device <UDID> content-none
```

## The mock server

The extension needs something to fetch. `MockServer` in the app only answers an
`http.Client` in-process, so this binds it to a port:

```sh
fvm dart run scripts/push/mock_server.dart      # http://127.0.0.1:8787
```

It seeds the alarmed fixture and publishes one more priority-5 message with the
`rotating_light` tag and a click URL, so a delivered notification shows the
emoji prefix and carries the link.

## What simctl cannot do

`xcrun simctl push` hands the payload straight to the notification system. It
never starts a Notification Service Extension, whatever `mutable-content` says.
So `content-none.apns` delivered this way shows the placeholder, and that is the
simulator, not a bug.

The extension is covered instead by `ios/RunnerTests/NotificationServiceTests.swift`,
which calls `didReceive` over these same four files:

```sh
fvm flutter build ios --simulator --debug
cd ios && xcodebuild test -workspace Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:RunnerTests -disableAutomaticPackageResolution
```

Both extra steps are there for the same reason. Only `flutter build` raises the
generated Swift package to the project's iOS 16 target; a plain `xcodebuild`
regenerates it at Flutter's own 13.0 floor, which Firebase rejects. Build
first, then keep xcodebuild from re-resolving it.

With the mock server running, the content-none test asserts the fetched title
and body. With it stopped, the same test asserts the placeholder survives.

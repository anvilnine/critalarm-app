# critalarm-app

The Crit Alarm mobile app. It subscribes to your Crit Alarm server, and when a
critical incident opens it rings your phone through silent and Do Not Disturb
until you acknowledge it. Two stages: "I'm up" stops the noise, "At my desk"
closes the incident. Miss the second one and it starts ringing again.

Status: early. The shell builds. The alarm is not built yet.

## Run it

Flutter is pinned in `.fvmrc`. Use `fvm` so you get the same version CI does.

```bash
fvm flutter pub get
make gen        # freezed, json_serializable, flutter_gen
make l10n       # locale keys, a separate generator
fvm flutter run
```

Generated files are not committed. Skip `make gen` or `make l10n` and nothing
compiles.

```bash
make test           # unit tests
make analyze        # flutter analyze
make check-layers   # clean-architecture direction
make sync-contract  # refresh docs/api.md from critalarm-server
```

Generated files also go stale after a merge, so run `make gen` and `make l10n`
again if a pull leaves the analyzer complaining about `LocaleKeys`.

### Testing an alarm without waking the neighbours

A critical page rings at full volume, overrides whatever the volume was set to,
and keeps going until it is acknowledged. That is the product, and it is
unpleasant to test at a desk.

```bash
make run-quiet DEVICE=R5CXB30NDRV   # attached run
make build-quiet-apk                # installable artifact
```

Both pass `--dart-define=QUIET_ALARM=true`, which skips the volume override and
stops the ring after five seconds. The flag defaults to false, so a build that
does not ask for it behaves exactly like a store build.

## Docs

- `docs/api.md` is a generated copy of the server's contract. Do not edit it
  here. The source is `critalarm-server/docs/api.md`.
- `docs/ARCHITECTURE.md` is a generated copy too.
- `docs/design-system/` is the look the app has to implement. `lib/design_system/`
  does not implement it yet.

## Firebase Setup & Privacy Architecture

The app uses official Firebase plugins for Analytics, Crashlytics, and Remote Config (`firebase_core`, `firebase_analytics`, `firebase_crashlytics`, and `firebase_remote_config`).

### Configuration Files

Firebase configuration files are intentionally gitignored and must never be committed to the repository:

- **Android**: Place `google-services.json` in `android/app/google-services.json`
- **iOS**: Place `GoogleService-Info.plist` in `ios/Runner/GoogleService-Info.plist`

If these configuration files are absent (e.g. during local tests or CI builds), the telemetry subsystem initializes gracefully into a safe, disabled state without crashing.

### Strict Opt-In Privacy & Telemetry Policy

Telemetry collection is strictly opt-in:

- **Disabled by default**: Analytics and Crashlytics collection are explicitly disabled at startup before any events or metrics can be transmitted (`setAnalyticsCollectionEnabled(false)` and `setCrashlyticsCollectionEnabled(false)`).
- **Explicit user consent**: Telemetry collection is only enabled when the user explicitly toggles Analytics or Crash Reporting ON in **Settings > Privacy**.
- **Instant disable & purge**: Toggling Analytics OFF immediately halts collection and invokes `resetAnalyticsData()` to purge cached client-side analytics identifiers.
- **Remote Config defaults**: Remote Config runs with a 1-hour fetch interval (`minimumFetchInterval: const Duration(hours: 1)`) and safe typed defaults (`paywall_enabled: false`).

## Security

No push credential, keystore or store key belongs in this repo. Report anything
you find to security@critalarm.app.

A note for anyone forking this: Crit Alarm does not use Apple's Critical Alerts
entitlement. Apple turned the request down for `app.critalarm`. On iOS a
priority-5 page arrives as a Time-Sensitive push, which obeys the silent switch
and Do Not Disturb. On Android it takes the whole screen and rings. If Apple
ever approves the request, wiring it back up is its own piece of work.

## Licence

[GPL-3.0](LICENSE). You can run it, read it, change it and share it. If you
share a changed version, share the source under the same licence.

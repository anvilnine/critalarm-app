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

## Docs

- `docs/api.md` is a generated copy of the server's contract. Do not edit it
  here. The source is `critalarm-server/docs/api.md`.
- `docs/ARCHITECTURE.md` is a generated copy too.
- `docs/design-system/` is the look the app has to implement. `lib/design_system/`
  does not implement it yet.

## Security

No push credential, keystore or store key belongs in this repo. Report anything
you find to security@critalarm.app.

A note for anyone forking this: the iOS Critical Alerts entitlement is tied to
an Apple signing identity, not to the source. A fork built with your own
identity will not ring through silent on iOS unless Apple grants you the
entitlement too.

## Licence

[GPL-3.0](LICENSE). You can run it, read it, change it and share it. If you
share a changed version, share the source under the same licence.

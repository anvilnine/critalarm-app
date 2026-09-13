# Screenshots

Fourteen screens, captured on a Galaxy A25 (SM-A256E, 1080x2340) from a profile
build. Profile rather than debug, so there is no DEBUG banner in the corner.

Every string on these screens comes from `assets/translations/en.json`. If you
change copy there, these go stale. Recapture rather than edit.

## How they were taken

The app reads its start route from the Android intent, so each screen can be
launched straight from the shell:

```
adb -s <device> shell am start -n app.critalarm/.MainActivity --es route /settings
adb -s <device> exec-out screencap -p > screenshots/10_settings.png
```

`initialLocationFor` in `lib/app/initial_route_resolver.dart` only honours a
handed-in route for `/incidents/*` and `/topics/*`, so everything else needs that
guard relaxed for the duration of the capture. That change is temporary and is
never committed.

Build and install first:

```
fvm flutter build apk --profile
adb -s <device> install -r -g build/app/outputs/flutter-apk/app-profile.apk
```

## What is here

| File | Route |
|---|---|
| `01_gallery.png` | `/gallery` |
| `02_onboarding_permissions.png` | `/onboarding` |
| `03_onboarding_connect.png` | `/onboarding/connect` |
| `04_home_face.png` | `/home` |
| `05_topics_list.png` | `/topics` |
| `06_topic_detail.png` | `/topics/prod-db` |
| `07_create_topic.png` | `/topics/new` |
| `08_critical_alarm.png` | `/alarm` |
| `09_lock_screen.png` | `/lockscreen` |
| `10_settings.png` | `/settings` |
| `11_paywall.png` | `/paywall` |
| `12_device_permissions.png` | `/settings/permissions` |
| `13_permission_denial.png` | `/onboarding/denied` |
| `14_server_disconnected.png` | `/settings/disconnected` |

## One route to be aware of

`/onboarding/permissions` builds `OnboardingConnectScreen`, not the permissions
screen (`lib/app/router.dart`). It is a duplicate of `/onboarding/connect`. The
permissions screen lives at `/onboarding` and, in its denied state, at
`/onboarding/denied`. Worth fixing, but it is not a copy problem so this pass
left it alone.

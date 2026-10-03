# Sound packs

Extra alarm sounds ship outside the app binary, as packs the stores host. The
app downloads a pack only when the user taps Download in the sound picker. No
pack file comes from our own server.

- **Android:** Play Asset Delivery, one on-demand asset pack per sound pack.
- **iOS:** Apple-hosted Managed Background Assets, iOS 26 and later. Below
  iOS 26 the picker shows the pack as "Needs iOS 26 or later."

The first pack is `sound_pack_library`: 23 CC0 and public domain recordings.
The id is the same in both stores and never changes.

## How a pack sound rings

Each platform keeps a copy of a pack sound in the folder imported sounds live
in, under its id:

| Platform | Copy | Made | Read by |
|---|---|---|---|
| Android | `files/sounds/<id>.ogg` | for all 23 when the pack arrives (2.2 MB) | `AlarmSoundStore.resolveForTopic`, the alarm player |
| iOS | app group `Library/Sounds/<id>.caf` | only while a topic or the default uses the sound | the notification extension, by name |

On iOS a caf is 16-bit PCM, about 96 KB a second, so converting all 23 would
take some 30 MB for a 2.9 MB pack. `SoundLibrary.publishToExtension`, which
runs after every change to a choice, calls `SoundPackBridge.syncCopies`: it
makes the caf for each pack sound in use and deletes the caf of any pack sound
no choice uses. The picker previews the other pack sounds straight from the
pack's m4a.

A pack sound then behaves like an imported one, including "Notifications only"
on iOS, where AlarmKit reads compiled-in sounds only.

Pack sound ids start with `pack_`. When a topic's sound file is gone, the topic
rings the user's default sound, and only when that is gone too does
`classic_siren` ring. The picker and both platforms follow the same order:

- Dart: opening the picker drops the topic's choice so it follows the default,
  and moves a default whose pack sound is gone to `classic_siren`
  (`AlarmSoundRepository.fallBackFrom`), the way deleting a user sound does.
  It does this only when the platform answered; a failed question moves
  nothing.
- Android: `AlarmSoundStore.resolveForTopic` tries the topic's sound, then the
  default, then `classic_siren`, skipping an imported or pack file that is
  missing or empty. A file that is there but will not decode goes through the
  existing `AlarmFallback` chain to `classic_siren`.
- iOS: `SharedSounds.fileName` tries the topic's file, then the default's.
  When those include a missing pack file, the notification plays
  `classic_siren.caf`.

## Where the files are

| What | Path |
|---|---|
| Preparation script | `tools/sounds/library_pack.mjs` |
| Android pack module | `android/sound_pack_library/` (Gradle `com.android.asset-pack`, on-demand) |
| Android bridge | `android/app/src/main/kotlin/app/critalarm/sound/SoundPackChannel.kt`, `SoundPackRules.kt` |
| iOS pack source | `ios/SoundPacks/sound_pack_library/` (`Manifest.json`, `sounds/`, `LICENSES.md`) |
| iOS downloader extension | `ios/CritAlarmDownloader/` (target `CritAlarmDownloader`) |
| iOS bridge | `ios/Runner/SoundPackBridge.swift`, wired in `AppDelegate.attachSoundPackChannel` |
| Dart | `lib/core/sound/sound_pack.dart`, `sound_pack_host.dart`, `sound_pack_repository.dart`, `library_pack_sounds.dart` |
| Credits | `LICENSES.md` inside each pack, and Settings > Acknowledgements |

Both bridges answer the same calls on `app.critalarm/sound_packs`:
`packState`, `download`, `packPath`, `installPack`, `installedPackSounds`, plus
`packStateChanged` sent to Dart with progress.

## Rebuilding the library sounds

The original downloads are not in the repo. Fetch them from the source URLs in
the script's table (or in either `LICENSES.md`), keeping the file names the
table lists, then:

```
node tools/sounds/library_pack.mjs /path/to/originals
```

It rewrites both packs' sound folders, both `LICENSES.md` files and
`lib/core/sound/library_pack_sounds.dart`, and prints loudness, true peak and
length per sound.

## Android

Nothing extra to build. `assetPacks += listOf(":sound_pack_library")` in
`android/app/build.gradle.kts` puts the pack in every app bundle:

```
fvm flutter build appbundle --release
```

The bundle grows by about 2.3 MB. The base download does not: Play serves the
pack only when the app asks for it.

### Testing on a phone

A sideloaded or `flutter run` build cannot fetch Play packs. The picker shows
"Install Crit Alarm from the App Store or Google Play to download sound packs."

Local testing with bundletool fakes the Play download from the device's own
storage:

```
fvm flutter build appbundle --release
bundletool build-apks --bundle build/app/outputs/bundle/release/app-release.aab \
  --output build/app-local.apks --local-testing
bundletool install-apks --apks build/app-local.apks
```

If Play holds the download for Wi-Fi or for a confirmation, the row says so and
Download stays on it; tapping it shows Play's own dialog.

Then open Settings > Alarm sound, tap Download on "Library sounds", pick one of
the 23 sounds and fire a test alarm. `adb logcat -s CritAlarmSound
CritAlarmAlarm` shows `pack_state`, `pack_installed ... sounds=23 of=23` and
`alarm_sound sound_id=pack_library_... source=Imported(...)`.

To check the fallback, build the bundle with `--debug` instead (so `run-as`
works), install it the same way, pick a pack sound, then delete its copy and
ring again:
`adb shell run-as app.critalarm rm files/sounds/pack_library_boxing_bell.ogg`.
The alarm logs `sound_missing ... falling_back_to=classic_siren` and rings the
classic siren.

The internal test track is the real thing: upload the bundle, install from the
Play Store on a tester's phone, and the download comes from Play.

## iOS

The app and the `CritAlarmDownloader` extension both carry:

| Key | Value |
|---|---|
| `BAAppGroupID` | `group.app.critalarm` |
| `BAHasManagedAssetPacks` | `true` |
| `BAUsesAppleHosting` | `true` |

The extension is Apple's default `StoreDownloaderExtension`, shares the app
group and targets iOS 26.

### Building the pack

From the pack folder, with Xcode 26 or later:

```
cd ios/SoundPacks/sound_pack_library
xcrun ba-package package Manifest.json -o ../../../build/sound_packs/sound_pack_library.aar
```

`Manifest.json` packages `sounds/` and `LICENSES.md` with an on-demand download
policy for iOS. The archive is about 2.9 MB.

Before release, listen to every sound in the pack and confirm none of them is an
EAS, WEA, NFPA Temporal-3 or Temporal-4, or civil-defence signal. The source
list asked for that check and it has not been done by ear.

### Uploading it

Upload `sound_pack_library.aar` to App Store Connect as an asset pack for Crit
Alarm, with Transporter or the App Store Connect API, then attach it to the app
version for review. Use this review note:

> a sound pack of alarm sounds the user can choose for alarms

The exact App Store Connect screens for asset packs were not checked from this
repo. Follow what App Store Connect shows for the app, and note any step that
differs here.

### Testing on an iPhone

Only a TestFlight or App Store build can fetch an Apple-hosted pack. A build run
from Xcode reports the pack as unavailable.

1. Upload a build that includes `CritAlarmDownloader`, and the pack, to App
   Store Connect.
2. Install the build from TestFlight on an iPhone with iOS 26 or later.
3. Settings > Alarm sound, Download on "Library sounds". The row shows
   progress, then lists the 23 sounds.
4. Pick one for a topic and send a push to it. The notification plays the pack
   sound. Console.app shows `CritAlarmSound: pack_downloaded` and
   `CritAlarmNSE sound_applied name=pack_library_...`.

Before iOS 26 the row says "Needs iOS 26 or later." and offers nothing.

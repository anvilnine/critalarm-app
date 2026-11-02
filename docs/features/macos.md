# macOS

The Mac app is the same Dart code as the iPhone app, built from `macos/`. Bundle id
`app.critalarm`, sandboxed, deployment target macOS 13. It runs every screen that needs no push
and no ringer. Push is A332, the ringer A333, purchases A334, widgets and the Dock menu A335.
Mac sign-in waits for contract 1.23.0 (`platform: "macos"`) and A332.

## How the Dart side stays off channels the Mac does not have

- `PlatformCapabilities.isMacos` answers the question. Feature code never reads
  `defaultTargetPlatform`. `canRunAlarm`, `canRegisterPush`, `hasLocalNotifications`,
  `hasHaptics`, `hasQuickActions`, `hasAlternateAppIcons`, `hasSystemAlarmHost` and
  `hasCustomerCenter` are all false on a Mac. `isApple` (iPhone or Mac) picks the App Store key,
  the sound formats and the 30 second notification sound limit.
- `OffPlatformChannel` (`lib/core/platform/off_platform_channel.dart`) is a `MethodChannel` that
  throws `MissingPluginException` itself, so a call never leaves Dart. `registerAppHosts` in
  `lib/app/di/register_core.dart` hands one to each host whose native half only the phones have.
  Every host already treats that exception as "not on this platform" and returns its safe default.
- The Mac registers two native channels of its own, in `macos/Runner/MainFlutterWindow.swift`:
  `app.critalarm/sound` and `app.critalarm/settings`.

## Plugins

| Plugin | macOS status |
|---|---|
| `device_info_plus` | Works. |
| `easy_localization`, `intl`, `go_router`, `flutter_bloc`, `get_it`, `http`, `crypto`, `uuid`, `timezone`, `path`, `confetti`, `flutter_slidable` | Pure Dart. Works. |
| `file_selector` | Works (`file_selector_macos`). Opens the sandbox open panel for sound import. The Mac hands over the person's own file, so `SoundFilePicker.discard` deletes nothing. |
| `firebase_core` | Works. `firebase_options.dart` has a `macos` entry that shares the iPhone's Apple app in the Firebase project. |
| `firebase_analytics`, `firebase_crashlytics`, `firebase_remote_config` | Plugin present. Run through `TelemetryGate`, behind the user's consent switches. |
| `firebase_messaging` | Plugin present, not used. Apple builds take `ApnsPushTokenProvider` and the Mac's `PushHost` answers nothing. Needs A332. |
| `flutter_local_notifications` | Plugin present, not used. `hasLocalNotifications` is false, so the Mac gets `NoopLocalReminderScheduler`. Revisit with A332. |
| `google_sign_in` | Works (`google_sign_in_ios` has a macOS side). `NativeGoogleSignInSheet` passes the iOS client id. Sign-in itself waits for A332. |
| `sign_in_with_apple` | Works. Entitlement present. Sign-in itself waits for A332. |
| `in_app_review` | Works. |
| `package_info_plus` | Works. |
| `path_provider` | Works (`path_provider_foundation`). |
| `purchases_flutter` | Configures with the iPhone's App Store key (same app record). The paywall shows prices. Buying is A334. |
| `purchases_ui_flutter` | Off platform. No macOS side. `hasCustomerCenter` is false, so Settings hides the Manage button. |
| `quick_actions` | Off platform. `hasQuickActions` is false, so `QuickActionBindings` never calls it. Dock menu is A335. |
| `record` | Works (`record_macos`). Sound recording uses the microphone entitlement. |
| `share_plus` | Works. |
| `shared_preferences` | Works (`shared_preferences_foundation`). |
| `sqflite` | Works (`sqflite_darwin`). |
| `url_launcher` | Works (`url_launcher_macos`). |

## Native channels

| Channel | macOS status |
|---|---|
| `app.critalarm/sound` | Works. `macos/Runner/SoundChannel.swift` handles `capabilities`, `prepareBundledSounds`, `startPreview`, `stopPreview`, `probeDuration`, `importSound`, `readPeaks`, `cancelPeaks`, `deleteSound`. `publishSoundAssignments` answers true and does nothing. `takeIncomingAudio` answers nil (no "Share to Crit Alarm" yet). |
| `app.critalarm/settings` | Works. `macos/Runner/SettingsChannel.swift` reads notification permission, time sensitive and scheduled summary, and opens System Settings. The Android-only checks answer true. The "open app settings" calls open Privacy & Security, since a Mac has no per-app page. |
| `app.critalarm/push` | Off platform (`OffPlatformChannel`). No token, no device registration. Needs A332. |
| `app.critalarm/alarm` | Off platform (`OffPlatformChannel`). `hasSystemAlarmHost` is false. The ringer is A333. |
| `app.critalarm/nse_credentials` | Off platform. There is no Notification Service Extension on the Mac. |
| `app.critalarm/widgets` | Off platform. Widgets are A335. |
| `app.critalarm/app_icon` | Off platform. macOS has no alternate app icons. |
| `app.critalarm/motion` and `app.critalarm/motion/readings` | Off platform. A Mac has no accelerometer, so the shake challenge offers taps. |
| `app.critalarm/sound_packs` | Off platform (`OffPlatformChannel` in `PlayAppleStoreServices.soundPacks`). Store-hosted packs are phone only. The Mac lists bundled sounds and its own imports. |
| `app.critalarm/locale` | Stubbed. The Mac gets `NoopNativeLocaleBridge`, because it has no native strings yet. |
| `app.critalarm/local_reminders` | Stubbed. `NoopLocalReminderScheduler` replaces it. |
| `app.critalarm/backup` | Stubbed. `NoBackupHost` (only an iPhone restores anything). |
| `app.critalarm/device_identity` | Stubbed. Only the iPhone uses the Keychain stores (`KeychainDeviceIdentityStore`, `KeychainIdentityTokenStore`). The Mac keeps the identity in preferences. The Keychain move for the Mac is open. |
| `app.critalarm/ui_sound` | Not registered. `UiSoundHost` catches `MissingPluginException`, so the paywall sounds are silent. |
| `app.critalarm/maker_settings` | Not registered. Caught as `MissingPluginException` (Android only screen). |
| `app.critalarm/display` and `app.critalarm/display/fold` | Not registered. `NativeFoldChannel` drops `MissingPluginException`, so there is no fold. |

"Not registered" channels are caught in the host. "Off platform" ones never leave Dart.

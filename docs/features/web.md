# Building for web

Moved out of AGENTS.md on 2026-10-17. Updated 2026-11-02 with the two capability getters main added after the move. Read before changing this area.

**This app also builds for web.** The dashboard is this codebase run through
`flutter build web` (ARCHITECTURE §2). Four rules keep that cheap:

- Ask the capabilities service, never `kIsWeb` or `Platform.isIOS` inline. It is `PlatformCapabilities` in `lib/core/platform/platform_capabilities.dart`, registered in `get_it` by `registerPlatformSingletons` (`lib/app/di/register_core.dart`). Its getters are `canRegisterPush`, `canRunAlarm`, `canComposeMessages`, `hasLocalNotifications`, `hasHaptics`, `hasStrongAlarmVibration` (Android only) and `flashNeedsAlarmScreen` (iPhone only), plus the two values it is built from, `isWeb` and `platform`, and `isIos` (the native iOS app, never a browser). Web gets no push, no alarm, no Local Reminders and no haptics, and it gets compose. `canImportSounds` is not on it: that is a question for the native side, so it lives on `SoundHost` (`SoundCapabilities`). `lib/app/di.dart` and the files in `lib/app/di/` are the only places that read `kIsWeb` for feature code. Data and domain classes get the class or a plain value through their constructor, and screens read it from `getIt`. `tool/check_layers.sh` fails on any `kIsWeb` under `lib/features/`, comments included.
- A screen that exists on one platform only is its own route gated by a capability, never a widget hidden behind a boolean: the message composer is web only, the permissions screen is mobile only.
- Shared widgets take no platform-specific dependencies.
- Layout breakpoints come from the design system, never from the platform.


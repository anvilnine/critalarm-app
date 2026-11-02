import 'package:flutter/foundation.dart' show TargetPlatform, immutable;

/// What this build can do on the platform it runs on.
///
/// Feature code asks this class and never reads `kIsWeb` itself. It is built
/// once in `lib/app/di.dart`, the one place that reads `kIsWeb` and
/// `defaultTargetPlatform` for feature code, and `tool/check_layers.sh` fails
/// on a `kIsWeb` under `lib/features/`.
///
/// It holds two values and reads no global, so a test builds the platform it
/// wants: `const PlatformCapabilities(isWeb: true, platform: ...)`.
///
/// Whether sounds can be imported is not answered here. That is a question
/// for the native side, so it lives on `SoundHost` (`SoundCapabilities`).
@immutable
class PlatformCapabilities {
  const PlatformCapabilities({required this.isWeb, required this.platform});

  /// True in the web build (the dashboard), whatever device opens it.
  final bool isWeb;

  /// The platform Flutter reports. In the web build this is the platform of
  /// the browser's device, so check [isWeb] first, or use [isIos].
  final TargetPlatform platform;

  /// The native iOS app. False in a browser on an iPhone.
  bool get isIos => !isWeb && platform == TargetPlatform.iOS;

  /// The native macOS app. False in a browser on a Mac.
  ///
  /// The Mac build runs every screen that needs no push and no ringer. It
  /// registers no push token, rings nothing, and has none of the iPhone's
  /// system extras (AlarmKit, Live Activities, quick actions, alternate app
  /// icons) or RevenueCat's Customer Center. Each of those is a getter here
  /// that answers false on a Mac.
  bool get isMacos => !isWeb && platform == TargetPlatform.macOS;

  /// The native apps that sell through Apple and decode audio with
  /// AVFoundation: the iPhone and the Mac. They share the App Store key, the
  /// bundled sound files and the 30 second notification sound limit.
  bool get isApple => isIos || isMacos;

  /// The two phone apps, where every native channel has a handler.
  bool get _isPhone =>
      !isWeb &&
      (platform == TargetPlatform.iOS || platform == TargetPlatform.android);

  /// Whether the build registers a push token with the server. Web has none,
  /// and the Mac has none yet.
  bool get canRegisterPush => _isPhone;

  /// Whether the build can ring an alarm on this device. Web cannot, and the
  /// Mac cannot yet.
  bool get canRunAlarm => _isPhone;

  /// Whether the build has the message composer. It is a web only screen.
  bool get canComposeMessages => isWeb;

  /// Whether the build can schedule notifications on the device, which
  /// Local Reminders need. Web cannot, and the Mac does not schedule them
  /// yet.
  bool get hasLocalNotifications => _isPhone;

  /// Whether the build can play haptics. Web and the Mac cannot.
  bool get hasHaptics => _isPhone;

  /// Whether the app icon has quick actions (a long press on the home screen
  /// icon). The phones only. The Mac gets Dock items instead, later.
  bool get hasQuickActions => _isPhone;

  /// Whether the home screen icon can be swapped for an alternate one. The
  /// phones only. macOS has no alternate app icons.
  bool get hasAlternateAppIcons => _isPhone;

  /// Whether the system alarm and the acknowledge card exist: AlarmKit and
  /// Live Activities on the iPhone. The Android side answers the same
  /// channel with its own alarm. Never on the Mac.
  bool get hasSystemAlarmHost => _isPhone;

  /// Whether RevenueCat's Customer Center can open. `purchases_ui_flutter`
  /// has no macOS side, so the Mac has no Manage button for now.
  bool get hasCustomerCenter => _isPhone;

  /// Whether the app itself runs a vibration pattern while an alarm rings.
  /// Android only: its alarm is the app's own service. An iPhone alarm is
  /// rung by the system, and the app cannot add a vibration to it.
  bool get hasStrongAlarmVibration =>
      !isWeb && platform == TargetPlatform.android;

  /// True where the camera flash can only blink while the app's own alarm
  /// screen is open, which is the iPhone. On Android the alarm service
  /// blinks it with the app closed.
  bool get flashNeedsAlarmScreen => isIos;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlatformCapabilities &&
          isWeb == other.isWeb &&
          platform == other.platform;

  @override
  int get hashCode => Object.hash(isWeb, platform);

  @override
  String toString() =>
      'PlatformCapabilities(isWeb: $isWeb, platform: ${platform.name})';
}

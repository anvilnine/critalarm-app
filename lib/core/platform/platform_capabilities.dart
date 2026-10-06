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

  /// Whether the build registers a push token with the server. Web has none.
  bool get canRegisterPush => !isWeb;

  /// Whether the build can ring an alarm on this device. Web cannot.
  bool get canRunAlarm => !isWeb;

  /// Whether the build has the message composer. It is a web only screen.
  bool get canComposeMessages => isWeb;

  /// Whether the build can schedule notifications on the device, which
  /// Local Reminders need. Web cannot.
  bool get hasLocalNotifications => !isWeb;

  /// Whether the build can play haptics. Web cannot.
  bool get hasHaptics => !isWeb;

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

import 'package:critalarm/core/alarm/alarm_host.dart';
import 'package:flutter/foundation.dart';

/// The loudest thing this phone can do for a critical page.
///
/// Every screen that promises a ring picks its words from this, so an iPhone
/// older than iOS 26 is never told it rings through silent mode.
enum RingClaim {
  /// AlarmKit on iOS 26 or later, or the Android full-screen alarm. Rings
  /// through silent mode and Do Not Disturb.
  alarm,

  /// iOS 16 to 25. There is no AlarmKit, so a page arrives as a Time-Sensitive
  /// notification with sound, and the silent switch mutes it.
  timeSensitive;

  /// Android answers [AlarmAuthorization.unsupported] on the alarm channel
  /// too, so the platform is needed to tell an old iPhone from an Android
  /// phone. [platform] and [isWeb] are injected by tests only.
  static RingClaim forPhone(
    AlarmAuthorization alarm, {
    TargetPlatform? platform,
    bool isWeb = kIsWeb,
  }) {
    final onIos =
        !isWeb && (platform ?? defaultTargetPlatform) == TargetPlatform.iOS;
    return onIos && alarm == AlarmAuthorization.unsupported
        ? RingClaim.timeSensitive
        : RingClaim.alarm;
  }
}

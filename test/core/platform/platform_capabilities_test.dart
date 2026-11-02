import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlatformCapabilities', () {
    test('web: no push, no alarm, no reminders, no haptics, yes compose', () {
      // A browser reports the platform of its device, so every platform a
      // browser can run on must give the same answers.
      for (final platform in TargetPlatform.values) {
        final on = PlatformCapabilities(isWeb: true, platform: platform);

        expect(on.isWeb, isTrue, reason: platform.name);
        expect(on.platform, platform);
        expect(on.isIos, isFalse, reason: platform.name);
        expect(on.canRegisterPush, isFalse, reason: platform.name);
        expect(on.canRunAlarm, isFalse, reason: platform.name);
        expect(on.canComposeMessages, isTrue, reason: platform.name);
        expect(on.hasLocalNotifications, isFalse, reason: platform.name);
        expect(on.hasHaptics, isFalse, reason: platform.name);
      }
    });

    test('iOS: push, alarm, reminders and haptics, no compose', () {
      const on = PlatformCapabilities(
        isWeb: false,
        platform: TargetPlatform.iOS,
      );

      expect(on.isWeb, isFalse);
      expect(on.platform, TargetPlatform.iOS);
      expect(on.isIos, isTrue);
      expect(on.canRegisterPush, isTrue);
      expect(on.canRunAlarm, isTrue);
      expect(on.canComposeMessages, isFalse);
      expect(on.hasLocalNotifications, isTrue);
      expect(on.hasHaptics, isTrue);
    });

    test('Android: push, alarm, reminders and haptics, no compose', () {
      const on = PlatformCapabilities(
        isWeb: false,
        platform: TargetPlatform.android,
      );

      expect(on.isWeb, isFalse);
      expect(on.platform, TargetPlatform.android);
      expect(on.isIos, isFalse);
      expect(on.canRegisterPush, isTrue);
      expect(on.canRunAlarm, isTrue);
      expect(on.canComposeMessages, isFalse);
      expect(on.hasLocalNotifications, isTrue);
      expect(on.hasHaptics, isTrue);
    });

    test('strong alarm vibration is Android only', () {
      for (final platform in TargetPlatform.values) {
        final native = PlatformCapabilities(isWeb: false, platform: platform);
        final web = PlatformCapabilities(isWeb: true, platform: platform);

        expect(
          native.hasStrongAlarmVibration,
          platform == TargetPlatform.android,
          reason: platform.name,
        );
        expect(web.hasStrongAlarmVibration, isFalse, reason: platform.name);
      }
    });

    test('the flash follows the alarm screen on the native iOS app only', () {
      for (final platform in TargetPlatform.values) {
        final native = PlatformCapabilities(isWeb: false, platform: platform);
        final web = PlatformCapabilities(isWeb: true, platform: platform);

        expect(
          native.flashNeedsAlarmScreen,
          platform == TargetPlatform.iOS,
          reason: platform.name,
        );
        expect(web.flashNeedsAlarmScreen, isFalse, reason: platform.name);
      }
    });

    test('two with the same values are equal', () {
      const a = PlatformCapabilities(
        isWeb: false,
        platform: TargetPlatform.iOS,
      );
      // Not const, so the two are different objects.
      final b = PlatformCapabilities(
        isWeb: [false].first,
        platform: TargetPlatform.iOS,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          const PlatformCapabilities(
            isWeb: true,
            platform: TargetPlatform.iOS,
          ),
        ),
      );
      expect(
        a,
        isNot(
          const PlatformCapabilities(
            isWeb: false,
            platform: TargetPlatform.android,
          ),
        ),
      );
    });
  });
}

import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('devicePermissionTypesFor', () {
    test('Android lists its own three and nothing from iOS', () {
      expect(
        devicePermissionTypesFor(TargetPlatform.android, isWeb: false),
        [
          DevicePermissionType.notifications,
          DevicePermissionType.fullScreenIntent,
          DevicePermissionType.batteryOptimization,
        ],
      );
    });

    test('iOS lists its own three and nothing from Android', () {
      expect(
        devicePermissionTypesFor(TargetPlatform.iOS, isWeb: false),
        [
          DevicePermissionType.notifications,
          DevicePermissionType.timeSensitive,
          DevicePermissionType.alarms,
        ],
      );
    });

    test('web lists notifications alone, whatever the browser runs on', () {
      for (final platform in TargetPlatform.values) {
        expect(
          devicePermissionTypesFor(platform, isWeb: true),
          [DevicePermissionType.notifications],
        );
      }
    });
  });
}

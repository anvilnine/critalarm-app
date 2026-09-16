import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DevicePermissionType', () {
    test('contains every type the app can report on', () {
      expect(DevicePermissionType.values, [
        DevicePermissionType.notifications,
        DevicePermissionType.fullScreenIntent,
        DevicePermissionType.batteryOptimization,
        DevicePermissionType.timeSensitive,
        DevicePermissionType.alarms,
      ]);
    });
  });

  group('DevicePermissionStatus', () {
    test('contains all 4 status values', () {
      expect(DevicePermissionStatus.values, [
        DevicePermissionStatus.granted,
        DevicePermissionStatus.denied,
        DevicePermissionStatus.restricted,
        DevicePermissionStatus.notDetermined,
      ]);
    });

    test('getters return correct boolean for each status', () {
      expect(DevicePermissionStatus.granted.isGranted, isTrue);
      expect(DevicePermissionStatus.granted.isDenied, isFalse);

      expect(DevicePermissionStatus.denied.isDenied, isTrue);
      expect(DevicePermissionStatus.denied.isGranted, isFalse);

      expect(DevicePermissionStatus.restricted.isRestricted, isTrue);
      expect(DevicePermissionStatus.restricted.isGranted, isFalse);

      expect(DevicePermissionStatus.notDetermined.isNotDetermined, isTrue);
      expect(DevicePermissionStatus.notDetermined.isGranted, isFalse);
    });
  });

  group('DevicePermissionItem', () {
    const item1 = DevicePermissionItem(
      type: DevicePermissionType.notifications,
      title: 'Notifications',
      description: 'Allows alert banners and sound.',
      status: DevicePermissionStatus.granted,
      canFix: false,
    );

    const item2 = DevicePermissionItem(
      type: DevicePermissionType.notifications,
      title: 'Notifications',
      description: 'Allows alert banners and sound.',
      status: DevicePermissionStatus.granted,
      canFix: false,
    );

    const itemDifferent = DevicePermissionItem(
      type: DevicePermissionType.fullScreenIntent,
      title: 'Full-screen intent',
      description: 'Allows critical alerts on lock screen.',
      status: DevicePermissionStatus.denied,
      canFix: true,
    );

    test('equality and hashCode work as expected', () {
      expect(item1, equals(item2));
      expect(item1.hashCode, equals(item2.hashCode));
      expect(item1, isNot(equals(itemDifferent)));
    });

    test('copyWith updates properties correctly', () {
      final updated = item1.copyWith(
        status: DevicePermissionStatus.denied,
        canFix: true,
      );
      expect(updated.status, DevicePermissionStatus.denied);
      expect(updated.canFix, isTrue);
      expect(updated.type, item1.type);
      expect(updated.title, item1.title);
      expect(updated.description, item1.description);
    });
  });
}

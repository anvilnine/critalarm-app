import 'package:critalarm/features/permissions/data/repositories/platform_device_permissions_repository.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PlatformDevicePermissionsRepository repository;
  const channel = MethodChannel('app.critalarm/settings');
  final methodCalls = <MethodCall>[];

  setUp(() {
    methodCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methodCalls.add(call);
          switch (call.method) {
            case 'checkNotificationPermission':
              return true;
            case 'checkFullScreenIntent':
              return false;
            case 'checkBatteryOptimization':
              return true;
            case 'openNotificationSettings':
            case 'openFullScreenIntentSettings':
            case 'openBatteryOptimizationSettings':
              return true;
            default:
              return null;
          }
        });

    repository = PlatformDevicePermissionsRepository(
      channel: channel,
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('PlatformDevicePermissionsRepository', () {
    test('getPermissions returns items for all 3 permissions', () async {
      final result = await repository.getPermissions();

      expect(result.isSuccess(), isTrue);
      final items = result.getOrNull()!;
      expect(items.length, 3);

      final types = items.map((e) => e.type).toList();
      expect(types, [
        DevicePermissionType.notifications,
        DevicePermissionType.fullScreenIntent,
        DevicePermissionType.batteryOptimization,
      ]);

      final fsi = items.firstWhere(
        (e) => e.type == DevicePermissionType.fullScreenIntent,
      );
      expect(fsi.status, DevicePermissionStatus.denied);
      expect(fsi.canFix, isTrue);

      final battery = items.firstWhere(
        (e) => e.type == DevicePermissionType.batteryOptimization,
      );
      expect(battery.status, DevicePermissionStatus.granted);
      expect(battery.canFix, isFalse);
    });

    test('openPermissionSettings invokes openNotificationSettings', () async {
      final result = await repository.openPermissionSettings(
        DevicePermissionType.notifications,
      );

      expect(result.isSuccess(), isTrue);
      expect(
        methodCalls.any((c) => c.method == 'openNotificationSettings'),
        isTrue,
      );
    });

    test(
      'openPermissionSettings invokes openFullScreenIntentSettings',
      () async {
        final result = await repository.openPermissionSettings(
          DevicePermissionType.fullScreenIntent,
        );

        expect(result.isSuccess(), isTrue);
        expect(
          methodCalls.any((c) => c.method == 'openFullScreenIntentSettings'),
          isTrue,
        );
      },
    );

    test(
      'openPermissionSettings invokes openBatteryOptimizationSettings',
      () async {
        final result = await repository.openPermissionSettings(
          DevicePermissionType.batteryOptimization,
        );

        expect(result.isSuccess(), isTrue);
        expect(
          methodCalls.any((c) => c.method == 'openBatteryOptimizationSettings'),
          isTrue,
        );
      },
    );
  });

  group('rows per platform', () {
    Future<List<DevicePermissionType>> typesOn(TargetPlatform platform) async {
      final repo = PlatformDevicePermissionsRepository(
        channel: channel,
        platform: platform,
      );
      final result = await repo.getPermissions();
      return result.getOrNull()!.map((item) => item.type).toList();
    }

    test('iOS asks about notifications, Time Sensitive and alarms', () async {
      expect(await typesOn(TargetPlatform.iOS), [
        DevicePermissionType.notifications,
        DevicePermissionType.timeSensitive,
        DevicePermissionType.alarms,
      ]);
    });

    test('Android keeps full-screen intent and battery instead', () async {
      expect(await typesOn(TargetPlatform.android), [
        DevicePermissionType.notifications,
        DevicePermissionType.fullScreenIntent,
        DevicePermissionType.batteryOptimization,
      ]);
    });

    test('neither platform gets a row it cannot fix', () async {
      final ios = await typesOn(TargetPlatform.iOS);
      final android = await typesOn(TargetPlatform.android);

      expect(ios, isNot(contains(DevicePermissionType.batteryOptimization)));
      expect(ios, isNot(contains(DevicePermissionType.fullScreenIntent)));
      expect(android, isNot(contains(DevicePermissionType.timeSensitive)));
      expect(android, isNot(contains(DevicePermissionType.alarms)));
    });

    test('Time Sensitive off is a denied row on iOS', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'checkTimeSensitive') return false;
            return true;
          });

      final repo = PlatformDevicePermissionsRepository(
        channel: channel,
        platform: TargetPlatform.iOS,
      );
      final items = (await repo.getPermissions()).getOrNull()!;
      final row = items.firstWhere(
        (item) => item.type == DevicePermissionType.timeSensitive,
      );

      expect(row.status, DevicePermissionStatus.denied);
      expect(row.canFix, isTrue);
    });
  });
}

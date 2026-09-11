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
}

import 'package:critalarm/core/device/os_version_reader.dart';
import 'package:critalarm/core/failures/failure.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/sources/permissions_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _Permissions implements DevicePermissionsRepository {
  _Permissions(this.statuses, {this.failing = const {}});

  final Map<DevicePermissionType, DevicePermissionStatus> statuses;
  final Set<DevicePermissionType> failing;
  final asked = <DevicePermissionType>[];

  @override
  Future<AppResult<DevicePermissionStatus>> checkPermission(
    DevicePermissionType type,
  ) async {
    asked.add(type);
    if (failing.contains(type)) {
      return const Failure.unexpected(message: 'boom').toFailure();
    }
    return (statuses[type] ?? DevicePermissionStatus.granted).toSuccess();
  }

  @override
  Future<AppResult<List<DevicePermissionItem>>> getPermissions() =>
      throw UnimplementedError();

  @override
  Future<AppResult<bool>> openPermissionSettings(DevicePermissionType type) =>
      throw UnimplementedError();
}

Map<ReliabilityCheckId, ReliabilityCheck> _byId(List<ReliabilityCheck> list) =>
    {for (final check in list) check.id: check};

void main() {
  group('state rule', () {
    test('granted is fine with no fix', () {
      final check = PermissionsSource.permissionCheckFor(
        DevicePermissionType.notifications,
        DevicePermissionStatus.granted,
      );
      expect(check.state, ReliabilityState.fine);
      expect(check.fix, isNull);
    });

    test('a missing hard blocker is broken and opens its settings page', () {
      for (final type in [
        DevicePermissionType.notifications,
        DevicePermissionType.fullScreenIntent,
        DevicePermissionType.alarms,
      ]) {
        final check = PermissionsSource.permissionCheckFor(
          type,
          DevicePermissionStatus.denied,
        );
        expect(check.state, ReliabilityState.broken, reason: type.name);
        expect(check.fix, OpenSystemSettingsFix(type));
        expect(check.reason, 'denied');
      }
    });

    test('a missing battery exemption only needs a look', () {
      final check = PermissionsSource.permissionCheckFor(
        DevicePermissionType.batteryOptimization,
        DevicePermissionStatus.denied,
      );
      expect(check.state, ReliabilityState.needsLook);
    });

    test('not determined and restricted count as missing', () {
      expect(
        PermissionsSource.permissionCheckFor(
          DevicePermissionType.alarms,
          DevicePermissionStatus.notDetermined,
        ).state,
        ReliabilityState.broken,
      );
      expect(
        PermissionsSource.permissionCheckFor(
          DevicePermissionType.notifications,
          DevicePermissionStatus.restricted,
        ).reason,
        'restricted',
      );
    });
  });

  group('source', () {
    PermissionsSource build({
      required TargetPlatform platform,
      bool isWeb = false,
      int? major,
      _Permissions? permissions,
    }) => PermissionsSource(
      permissions: permissions ?? _Permissions({}),
      capabilities: PlatformCapabilities(isWeb: isWeb, platform: platform),
      os: FixedOsVersionReader(major),
    );

    test(
      'Android reports notifications, full-screen alarm and battery',
      () async {
        final checks = await build(
          platform: TargetPlatform.android,
          major: 15,
          permissions: _Permissions({
            DevicePermissionType.batteryOptimization:
                DevicePermissionStatus.denied,
          }),
        ).read();
        final byId = _byId(checks);
        expect(byId.keys, {
          ReliabilityCheckIds.notifications,
          ReliabilityCheckIds.fullScreenAlarm,
          ReliabilityCheckIds.batteryOptimization,
        });
        expect(
          byId[ReliabilityCheckIds.batteryOptimization]!.state,
          ReliabilityState.needsLook,
        );
        expect(
          byId[ReliabilityCheckIds.notifications]!.state,
          ReliabilityState.fine,
        );
      },
    );

    test('iPhone leaves Time Sensitive to its own source', () async {
      final permissions = _Permissions({});
      final checks = await build(
        platform: TargetPlatform.iOS,
        major: 26,
        permissions: permissions,
      ).read();
      expect(_byId(checks).keys, {
        ReliabilityCheckIds.notifications,
        ReliabilityCheckIds.alarms,
      });
      expect(
        permissions.asked,
        isNot(contains(DevicePermissionType.timeSensitive)),
      );
    });

    test('alarms is not on an iPhone below iOS 26 and is not read', () async {
      final permissions = _Permissions({});
      final checks = await build(
        platform: TargetPlatform.iOS,
        major: 18,
        permissions: permissions,
      ).read();
      expect(
        _byId(checks)[ReliabilityCheckIds.alarms]!.state,
        ReliabilityState.notOnThisPhone,
      );
      expect(permissions.asked, [DevicePermissionType.notifications]);
    });

    test(
      'a read that fails counts as denied, like the permissions list',
      () async {
        final checks = await build(
          platform: TargetPlatform.android,
          major: 15,
          permissions: _Permissions(
            {},
            failing: {DevicePermissionType.notifications},
          ),
        ).read();
        expect(
          _byId(checks)[ReliabilityCheckIds.notifications]!.state,
          ReliabilityState.broken,
        );
      },
    );

    test('the web reports notifications alone', () async {
      final checks = await build(
        platform: TargetPlatform.android,
        isWeb: true,
      ).read();
      expect(_byId(checks).keys, {ReliabilityCheckIds.notifications});
    });
  });
}

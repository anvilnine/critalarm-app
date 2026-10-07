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

    test('a permission never asked for is asked in the app', () {
      for (final type in [
        DevicePermissionType.notifications,
        DevicePermissionType.alarms,
      ]) {
        final check = PermissionsSource.permissionCheckFor(
          type,
          DevicePermissionStatus.notDetermined,
        );
        expect(check.fix, AskPermissionFix(type), reason: type.name);
        expect(check.reason, 'notDetermined');
        expect(check.state, ReliabilityState.broken);
      }
    });

    test('once asked, only system settings can change it', () {
      for (final status in [
        DevicePermissionStatus.denied,
        DevicePermissionStatus.restricted,
      ]) {
        expect(
          PermissionsSource.permissionCheckFor(
            DevicePermissionType.notifications,
            status,
          ).fix,
          const OpenSystemSettingsFix(DevicePermissionType.notifications),
          reason: status.name,
        );
      }
    });

    test('a permission with no system prompt always opens settings', () {
      for (final type in [
        DevicePermissionType.fullScreenIntent,
        DevicePermissionType.batteryOptimization,
        DevicePermissionType.timeSensitive,
      ]) {
        expect(
          PermissionsSource.permissionCheckFor(
            type,
            DevicePermissionStatus.notDetermined,
          ).fix,
          OpenSystemSettingsFix(type),
          reason: type.name,
        );
      }
    });
  });

  group('source', () {
    PermissionsSource build({
      required TargetPlatform platform,
      bool isWeb = false,
      int? major,
      _Permissions? permissions,
      Future<bool> Function()? notificationsNeverAsked,
    }) => PermissionsSource(
      permissions: permissions ?? _Permissions({}),
      capabilities: PlatformCapabilities(isWeb: isWeb, platform: platform),
      os: FixedOsVersionReader(major),
      notificationsNeverAsked: notificationsNeverAsked,
    );

    group('notifications the phone reports as off', () {
      Future<ReliabilityCheck> notifications({
        Future<bool> Function()? neverAsked,
        DevicePermissionStatus status = DevicePermissionStatus.denied,
      }) async => _byId(
        await build(
          platform: TargetPlatform.android,
          major: 15,
          permissions: _Permissions({
            DevicePermissionType.notifications: status,
            DevicePermissionType.fullScreenIntent:
                DevicePermissionStatus.denied,
          }),
          notificationsNeverAsked: neverAsked,
        ).read(),
      )[ReliabilityCheckIds.notifications]!;

      test('and the app never asked for are asked in the app', () async {
        final check = await notifications(neverAsked: () async => true);
        expect(check.reason, 'notDetermined');
        expect(
          check.fix,
          const AskPermissionFix(DevicePermissionType.notifications),
        );
      });

      test('and the app did ask for open settings', () async {
        final check = await notifications(neverAsked: () async => false);
        expect(check.reason, 'denied');
        expect(
          check.fix,
          const OpenSystemSettingsFix(DevicePermissionType.notifications),
        );
      });

      test('stay as reported when nothing says whether it asked', () async {
        final check = await notifications();
        expect(check.reason, 'denied');
      });

      test('a granted one is not asked about', () async {
        var asked = 0;
        final check = await notifications(
          status: DevicePermissionStatus.granted,
          neverAsked: () async {
            asked++;
            return true;
          },
        );
        expect(check.state, ReliabilityState.fine);
        expect(asked, 0);
      });

      test('the answer is for notifications only', () async {
        final checks = _byId(
          await build(
            platform: TargetPlatform.android,
            major: 15,
            permissions: _Permissions({
              DevicePermissionType.fullScreenIntent:
                  DevicePermissionStatus.denied,
            }),
            notificationsNeverAsked: () async => true,
          ).read(),
        );
        expect(checks[ReliabilityCheckIds.fullScreenAlarm]!.reason, 'denied');
      });
    });

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

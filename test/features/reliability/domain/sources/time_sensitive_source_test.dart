import 'package:critalarm/core/device/os_version_reader.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/core/result/result.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_item.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/scheduled_summary_reader.dart';
import 'package:critalarm/features/reliability/domain/sources/time_sensitive_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _Permissions implements DevicePermissionsRepository {
  _Permissions(this.statuses);

  final Map<DevicePermissionType, DevicePermissionStatus> statuses;
  final asked = <DevicePermissionType>[];

  @override
  Future<AppResult<DevicePermissionStatus>> checkPermission(
    DevicePermissionType type,
  ) async {
    asked.add(type);
    return (statuses[type] ?? DevicePermissionStatus.granted).toSuccess();
  }

  @override
  Future<AppResult<List<DevicePermissionItem>>> getPermissions() =>
      throw UnimplementedError();

  @override
  Future<AppResult<bool>> openPermissionSettings(DevicePermissionType type) =>
      throw UnimplementedError();

  @override
  Future<AppResult<bool>> openAppSettings() => throw UnimplementedError();
}

class _Summary implements ScheduledSummaryReader {
  _Summary({required this.on});

  final bool on;
  int asked = 0;

  @override
  Future<bool> isInScheduledSummary() async {
    asked++;
    return on;
  }
}

void main() {
  group('state rule', () {
    ReliabilityState state({
      required int major,
      required bool timeSensitiveOn,
      bool summary = false,
    }) => TimeSensitiveSource.timeSensitiveCheckFor(
      osMajor: major,
      timeSensitiveOn: timeSensitiveOn,
      inScheduledSummary: summary,
    ).state;

    test('Time Sensitive off is broken on iOS 16 to 25', () {
      for (final major in [16, 17, 25]) {
        expect(
          state(major: major, timeSensitiveOn: false),
          ReliabilityState.broken,
          reason: 'iOS $major',
        );
      }
    });

    test('Time Sensitive off is not broken from iOS 26', () {
      expect(
        state(major: 26, timeSensitiveOn: false),
        ReliabilityState.fine,
      );
    });

    test('in the Scheduled Summary needs a look', () {
      final check = TimeSensitiveSource.timeSensitiveCheckFor(
        osMajor: 18,
        timeSensitiveOn: true,
        inScheduledSummary: true,
      );
      expect(check.state, ReliabilityState.needsLook);
      expect(check.reason, 'scheduled_summary');
      expect(
        check.fix,
        const OpenSystemSettingsFix(DevicePermissionType.timeSensitive),
      );
    });

    test('off and in the summary is broken, the worse of the two', () {
      expect(
        state(major: 17, timeSensitiveOn: false, summary: true),
        ReliabilityState.broken,
      );
    });

    test('on and not in the summary is fine', () {
      expect(state(major: 17, timeSensitiveOn: true), ReliabilityState.fine);
    });
  });

  group('source', () {
    TimeSensitiveSource build({
      required TargetPlatform platform,
      bool isWeb = false,
      int? major = 18,
      Map<DevicePermissionType, DevicePermissionStatus> statuses = const {},
      bool summary = false,
      _Permissions? permissions,
      _Summary? summaryReader,
    }) => TimeSensitiveSource(
      capabilities: PlatformCapabilities(isWeb: isWeb, platform: platform),
      os: FixedOsVersionReader(major),
      permissions: permissions ?? _Permissions(statuses),
      summary: summaryReader ?? _Summary(on: summary),
    );

    test('Android is not on this phone and asks nothing', () async {
      final permissions = _Permissions({});
      final summary = _Summary(on: true);
      final checks = await build(
        platform: TargetPlatform.android,
        permissions: permissions,
        summaryReader: summary,
      ).read();
      expect(checks.single.state, ReliabilityState.notOnThisPhone);
      expect(permissions.asked, isEmpty);
      expect(summary.asked, 0);
    });

    test('the web is not on this phone', () async {
      final checks = await build(
        platform: TargetPlatform.iOS,
        isWeb: true,
      ).read();
      expect(checks.single.state, ReliabilityState.notOnThisPhone);
    });

    test('an unreadable version is not on this phone', () async {
      final checks = await build(
        platform: TargetPlatform.iOS,
        major: null,
      ).read();
      expect(checks.single.state, ReliabilityState.notOnThisPhone);
    });

    test('iPhone with Time Sensitive denied on iOS 17 is broken', () async {
      final checks = await build(
        platform: TargetPlatform.iOS,
        major: 17,
        statuses: {
          DevicePermissionType.timeSensitive: DevicePermissionStatus.denied,
        },
      ).read();
      expect(checks.single.state, ReliabilityState.broken);
    });

    test('iPhone in the Scheduled Summary needs a look', () async {
      final checks = await build(
        platform: TargetPlatform.iOS,
        summary: true,
      ).read();
      expect(checks.single.state, ReliabilityState.needsLook);
    });

    test('iPhone with both fine is fine', () async {
      final checks = await build(platform: TargetPlatform.iOS).read();
      expect(checks.single.state, ReliabilityState.fine);
    });
  });
}

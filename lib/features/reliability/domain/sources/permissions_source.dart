import 'package:critalarm/core/device/os_version_reader.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/reliability_check_source.dart';

/// The system permissions: notifications, full-screen alarm and battery on
/// Android, notifications and alarms on iPhone.
///
/// It reads them through [DevicePermissionsRepository], the same reads the
/// Settings health row makes, and applies the same split: a missing battery
/// exemption is a warning, any other missing permission is a failure. Time
/// Sensitive is not here. `TimeSensitiveSource` owns it, so the native call
/// is made once.
///
/// Reasons: the status name (`denied`, `restricted`, `notDetermined`).
///
/// A permission that was never asked for is fixed in the app
/// ([AskPermissionFix]), any other one in system settings. The phone does
/// not tell "never asked" from "said no" for notifications, so the app's own
/// memory of having asked decides it, through [notificationsNeverAsked].
final class PermissionsSource implements ReliabilityCheckSource {
  PermissionsSource({
    required this.permissions,
    required this.capabilities,
    required this.os,
    this.notificationsNeverAsked,
  });

  /// AlarmKit, and so the alarms permission, starts at this iOS version.
  static const alarmKitFirstMajor = 26;

  final DevicePermissionsRepository permissions;
  final PlatformCapabilities capabilities;
  final OsVersionReader os;

  /// Whether the app has never shown the system prompt for notifications:
  /// the answer `DevicePermissionsCubit.neverAsked` gives the permissions
  /// screen. Null leaves a missing notifications permission as the phone
  /// reports it.
  final Future<bool> Function()? notificationsNeverAsked;

  @override
  Future<List<ReliabilityCheck>> read() async {
    final types = devicePermissionTypesFor(
      capabilities.platform,
      isWeb: capabilities.isWeb,
    );
    final checks = <ReliabilityCheck>[];
    for (final type in types) {
      if (type == DevicePermissionType.timeSensitive) continue;
      final id = checkIdFor(type);
      if (type == DevicePermissionType.alarms && !await _hasAlarmKit()) {
        checks.add(ReliabilityCheck.notOnThisPhone(id));
        continue;
      }
      final status = (await permissions.checkPermission(type)).fold(
        (status) => status,
        // The permissions list does the same: a read that fails is a denial.
        (_) => DevicePermissionStatus.denied,
      );
      checks.add(permissionCheckFor(type, await _asked(type, status)));
    }
    return checks;
  }

  /// [status], or not determined for a notifications permission the app
  /// never asked for.
  Future<DevicePermissionStatus> _asked(
    DevicePermissionType type,
    DevicePermissionStatus status,
  ) async {
    final neverAsked = notificationsNeverAsked;
    if (type != DevicePermissionType.notifications ||
        !status.isDenied ||
        neverAsked == null) {
      return status;
    }
    return await neverAsked() ? DevicePermissionStatus.notDetermined : status;
  }

  Future<bool> _hasAlarmKit() async {
    final major = await os.major();
    return major != null && major >= alarmKitFirstMajor;
  }

  static ReliabilityCheckId checkIdFor(DevicePermissionType type) =>
      switch (type) {
        DevicePermissionType.notifications => ReliabilityCheckIds.notifications,
        DevicePermissionType.fullScreenIntent =>
          ReliabilityCheckIds.fullScreenAlarm,
        DevicePermissionType.batteryOptimization =>
          ReliabilityCheckIds.batteryOptimization,
        DevicePermissionType.timeSensitive => ReliabilityCheckIds.timeSensitive,
        DevicePermissionType.alarms => ReliabilityCheckIds.alarms,
      };

  /// The state rule for one permission.
  static ReliabilityCheck permissionCheckFor(
    DevicePermissionType type,
    DevicePermissionStatus status,
  ) {
    final id = checkIdFor(type);
    if (status.isGranted) {
      return ReliabilityCheck(id: id, state: ReliabilityState.fine);
    }
    return ReliabilityCheck(
      id: id,
      state: type == DevicePermissionType.batteryOptimization
          ? ReliabilityState.needsLook
          : ReliabilityState.broken,
      reason: status.name,
      fix: canAskInApp(type, status)
          ? AskPermissionFix(type)
          : OpenSystemSettingsFix(type),
    );
  }

  /// Whether the app can still show the system prompt for [type]. Only
  /// notifications and alarms have one, and only until it was used: the
  /// same rule as `DevicePermissionsCubit.neverAsked`.
  static bool canAskInApp(
    DevicePermissionType type,
    DevicePermissionStatus status,
  ) =>
      status.isNotDetermined &&
      (type == DevicePermissionType.notifications ||
          type == DevicePermissionType.alarms);
}

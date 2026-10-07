import 'package:critalarm/core/device/os_version_reader.dart';
import 'package:critalarm/core/platform/platform_capabilities.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_status.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/permissions/domain/repositories/device_permissions_repository.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_check.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_state.dart';
import 'package:critalarm/features/reliability/domain/reliability_check_source.dart';
import 'package:critalarm/features/reliability/domain/scheduled_summary_reader.dart';

/// Time Sensitive and the Scheduled Summary, on iPhone.
///
/// - Broken: Time Sensitive is off on iOS 16 to 25. iOS then holds the page
///   for the next summary. From iOS 26 an alarm rings through AlarmKit, so a
///   Time Sensitive switch that is off does not break it.
/// - Needs a look: the app is in the Scheduled Summary, on any iOS this app
///   supports.
/// - Fine: neither.
///
/// Not on this phone: Android, the web, or an iOS below 16.
///
/// The Time Sensitive status comes from [DevicePermissionsRepository], the
/// same read the Settings health row makes. The summary comes from
/// [ScheduledSummaryReader].
///
/// Reasons: `time_sensitive_off`, `scheduled_summary`. Both send the user to
/// the app's notification page in Settings.
final class TimeSensitiveSource implements ReliabilityCheckSource {
  TimeSensitiveSource({
    required this.capabilities,
    required this.os,
    required this.permissions,
    required this.summary,
  });

  /// The oldest iOS this app runs on, and the first with Time Sensitive.
  static const firstMajor = 16;

  /// The newest iOS where Time Sensitive is what carries the alarm.
  static const lastTimeSensitiveMajor = 25;

  final PlatformCapabilities capabilities;
  final OsVersionReader os;
  final DevicePermissionsRepository permissions;
  final ScheduledSummaryReader summary;

  @override
  Future<List<ReliabilityCheck>> read() async {
    const gone = ReliabilityCheck.notOnThisPhone(
      ReliabilityCheckIds.timeSensitive,
    );
    if (!capabilities.isIos) return [gone];
    final major = await os.major();
    if (major == null || major < firstMajor) return [gone];

    final status =
        (await permissions.checkPermission(
          DevicePermissionType.timeSensitive,
        )).fold(
          (status) => status,
          (_) => DevicePermissionStatus.denied,
        );
    return [
      timeSensitiveCheckFor(
        osMajor: major,
        timeSensitiveOn: status.isGranted,
        inScheduledSummary: await summary.isInScheduledSummary(),
      ),
    ];
  }

  /// The state rule. Pure.
  static ReliabilityCheck timeSensitiveCheckFor({
    required int osMajor,
    required bool timeSensitiveOn,
    required bool inScheduledSummary,
  }) {
    const id = ReliabilityCheckIds.timeSensitive;
    const fix = OpenSystemSettingsFix(DevicePermissionType.timeSensitive);
    if (!timeSensitiveOn && osMajor <= lastTimeSensitiveMajor) {
      return const ReliabilityCheck(
        id: id,
        state: ReliabilityState.broken,
        reason: 'time_sensitive_off',
        fix: fix,
      );
    }
    if (inScheduledSummary) {
      return const ReliabilityCheck(
        id: id,
        state: ReliabilityState.needsLook,
        reason: 'scheduled_summary',
        fix: fix,
      );
    }
    return const ReliabilityCheck(id: id, state: ReliabilityState.fine);
  }
}

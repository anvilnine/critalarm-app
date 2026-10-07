import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';

/// Runs the fixes that are not a navigation.
///
/// The screen owns the fixes that open a screen of the app ([OpenRouteFix],
/// [AskPermissionFix], [MissedAlarmFix]), because it has the navigator. For
/// one of those it gets `false` here and goes there itself. After any fix
/// the screen reads the checks again.
final class ReliabilityFixRunner {
  ReliabilityFixRunner({
    required this.openSystemSettings,
    required this.reRegisterPushToken,
  });

  /// `OpenPermissionSettingsUsecase`, as a function.
  final Future<void> Function(DevicePermissionType permission)
  openSystemSettings;

  /// `DeviceTokenRegistry.confirmNow`.
  final Future<bool> Function() reRegisterPushToken;

  /// True when [fix] was run. False for a fix that opens a screen of the
  /// app, which is not run here.
  Future<bool> run(ReliabilityFix fix) async {
    switch (fix) {
      case OpenRouteFix():
      case AskPermissionFix():
      case MissedAlarmFix():
        return false;
      case OpenSystemSettingsFix(:final permission):
        await openSystemSettings(permission);
        return true;
      case RunFix(:final action):
        switch (action) {
          case ReliabilityFixAction.reRegisterPushToken:
            await reRegisterPushToken();
        }
        return true;
    }
  }
}

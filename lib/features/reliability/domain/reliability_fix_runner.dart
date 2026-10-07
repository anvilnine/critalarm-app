import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/features/reliability/domain/entities/reliability_fix.dart';

/// Runs the fixes that are not a navigation.
///
/// The screen owns [OpenRouteFix], because it has the navigator. For one it
/// gets `false` here and goes to the route itself. After any fix the screen
/// reads the checks again.
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

  /// True when [fix] was run. False for [OpenRouteFix], which is not run
  /// here.
  Future<bool> run(ReliabilityFix fix) async {
    switch (fix) {
      case OpenRouteFix():
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

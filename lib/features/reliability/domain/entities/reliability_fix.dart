import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:flutter/foundation.dart';

/// What a check offers to do about itself. Data only: the screen decides how
/// to draw it and `ReliabilityFixRunner` runs the ones that are not a
/// navigation.
@immutable
sealed class ReliabilityFix {
  const ReliabilityFix();
}

/// Go to a screen of the app. [routeName] is an `AppRoute` name, which the
/// source is handed by `lib/app/di.dart`, since a feature cannot import the
/// router.
final class OpenRouteFix extends ReliabilityFix {
  const OpenRouteFix(this.routeName);

  final String routeName;

  @override
  bool operator ==(Object other) =>
      other is OpenRouteFix && other.routeName == routeName;

  @override
  int get hashCode => Object.hash(OpenRouteFix, routeName);

  @override
  String toString() => 'OpenRouteFix($routeName)';
}

/// Open the system settings page for [permission], through
/// `OpenPermissionSettingsUsecase`. Time Sensitive and alarms both live on
/// the app's notification page, and the usecase already knows that.
final class OpenSystemSettingsFix extends ReliabilityFix {
  const OpenSystemSettingsFix(this.permission);

  final DevicePermissionType permission;

  @override
  bool operator ==(Object other) =>
      other is OpenSystemSettingsFix && other.permission == permission;

  @override
  int get hashCode => Object.hash(OpenSystemSettingsFix, permission);

  @override
  String toString() => 'OpenSystemSettingsFix(${permission.name})';
}

/// Run something in the app.
final class RunFix extends ReliabilityFix {
  const RunFix(this.action);

  final ReliabilityFixAction action;

  @override
  bool operator ==(Object other) => other is RunFix && other.action == action;

  @override
  int get hashCode => Object.hash(RunFix, action);

  @override
  String toString() => 'RunFix(${action.name})';
}

/// The things [RunFix] can run. A later source adds a value here and a case
/// in `ReliabilityFixRunner`.
enum ReliabilityFixAction {
  /// Send the push token to the relay again, now.
  reRegisterPushToken,
}

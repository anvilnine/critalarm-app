import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:flutter/foundation.dart';

/// What a check offers to do about itself. Data only: the screen decides how
/// to draw it and `ReliabilityFixRunner` runs the ones that are not a
/// navigation. [OpenRouteFix], [AskPermissionFix] and [MissedAlarmFix] are
/// the screen's.
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

/// Ask for [permission] in the app, on the prompt screen the permissions
/// screen opens for a permission that was never asked. The system prompt is
/// still unused there, so system settings would be the long way round.
///
/// The screen owns this one, like [OpenRouteFix]: it has the navigator.
final class AskPermissionFix extends ReliabilityFix {
  const AskPermissionFix(this.permission);

  final DevicePermissionType permission;

  @override
  bool operator ==(Object other) =>
      other is AskPermissionFix && other.permission == permission;

  @override
  int get hashCode => Object.hash(AskPermissionFix, permission);

  @override
  String toString() => 'AskPermissionFix(${permission.name})';
}

/// What the missed alarm row offers: a test alarm, and a way to close the
/// entry.
///
/// It names the alarm the row is about, the newest one this phone may have
/// let down, so the row can say which alarm it means. Closing is the same
/// act as closing the notice on Home: [incidentIds] go to the one record of
/// closed entries, through `MissedAlarmReader.dismiss`.
final class MissedAlarmFix extends ReliabilityFix {
  const MissedAlarmFix({
    required this.testRouteName,
    required this.topic,
    required this.at,
    required this.incidentIds,
  });

  /// The `AppRoute` name of the test alarm screen.
  final String testRouteName;

  /// The topic of the alarm the row is about.
  final String topic;

  /// When that alarm ran out.
  final DateTime at;

  /// Every entry closing clears: all the missed alarms Home's notice
  /// counts, newest first, the ones that rang included.
  final List<String> incidentIds;

  @override
  bool operator ==(Object other) =>
      other is MissedAlarmFix &&
      other.testRouteName == testRouteName &&
      other.topic == topic &&
      other.at == at &&
      listEquals(other.incidentIds, incidentIds);

  @override
  int get hashCode => Object.hash(
    MissedAlarmFix,
    testRouteName,
    topic,
    at,
    Object.hashAll(incidentIds),
  );

  @override
  String toString() => 'MissedAlarmFix($topic, ${incidentIds.length})';
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

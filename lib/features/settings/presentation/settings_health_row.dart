import 'package:critalarm/app/shell/shell_cubit.dart';
import 'package:critalarm/design/faces/face_state.dart';
import 'package:critalarm/features/permissions/domain/entities/device_permission_type.dart';
import 'package:critalarm/gen/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

/// What the Health row on Settings says about the device permissions.
///
/// It lives apart from the widget so it can be unit tested. The screen used to
/// hardcode a worried face and "1 issue" whatever the real state was, so
/// granting everything still read as broken.
@immutable
class SettingsHealthRow {
  const SettingsHealthRow._({
    required this.isHealthy,
    required this.faceState,
    required this.issueCount,
    required this.subtitle,
  });

  factory SettingsHealthRow.from(ShellHealth health) {
    if (health.isHealthy) {
      return SettingsHealthRow._(
        isHealthy: true,
        faceState: FaceState.calm,
        issueCount: 0,
        subtitle: LocaleKeys.settings_health_row_subtitle_ok.tr(),
      );
    }

    final missing = health.missing;
    return SettingsHealthRow._(
      isHealthy: false,
      faceState: health.hasWarningsOnly
          ? FaceState.watching
          : FaceState.worried,
      issueCount: missing.length,
      // One missing permission says what goes wrong, not that a name "is
      // off": "Battery is off." read as though the battery were. The count
      // for several matches the notice on Home.
      subtitle: missing.length == 1
          ? _consequence(missing.first.type)
          : LocaleKeys.notices_setup_health_many.tr(
              namedArgs: {'count': '${missing.length}'},
            ),
    );
  }

  static String _consequence(DevicePermissionType type) => switch (type) {
    DevicePermissionType.notifications =>
      LocaleKeys.settings_health_issue_notifications.tr(),
    DevicePermissionType.fullScreenIntent =>
      LocaleKeys.settings_health_issue_full_screen_intent.tr(),
    DevicePermissionType.batteryOptimization =>
      LocaleKeys.settings_health_issue_battery_optimization.tr(),
    DevicePermissionType.timeSensitive =>
      LocaleKeys.settings_health_issue_time_sensitive.tr(),
    DevicePermissionType.alarms => LocaleKeys.settings_health_issue_alarms.tr(),
  };

  final bool isHealthy;
  final FaceState faceState;
  final int issueCount;
  final String subtitle;
}
